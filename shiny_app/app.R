# ============================================================
# Data Meets Home — Interactive Housing Price Explorer
# Valencia, Spain · Idealista 2018 → 2025
# ============================================================
# Proyecto II · Grado en Ciencia de Datos · UPV
# Authors: Robert Torres, Jorge Acín, Mihai Mihalache, Rubén Tormo
# ============================================================

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(leaflet)
  library(plotly)
  library(dplyr)
  library(randomForest)
})

options(OutDec = ",")

# ═══════════════════════════════════════════════════════════════════
# DATA LOADING & CONFIGURATION (runs once at startup)
# ═══════════════════════════════════════════════════════════════════
# IPV_FACTOR and IPV_LABEL are loaded dynamically from models/factor_ipv.rds (see below)

# Load data and models
datos_raw <- readRDS("models/datos_limpios.rds")
modelo_rf <- readRDS("models/modelo_rf_puro.rds") # pure randomForest (no caret wrapper)

# Load IPV factor calculated in notebook 06 from INE data
ipv_info   <- readRDS("models/factor_ipv.rds")
IPV_FACTOR <- ipv_info$factor  # e.g. 1.4318 (IPV 2024T4 / IPV 2018T1)
IPV_LABEL  <- sprintf("×%.4f (IPV INE: %s / %s)",
                      IPV_FACTOR, ipv_info$trimestre_base, ipv_info$trimestre_ref)

DISTRITOS <- c(
  "Algirós", "Benicalap", "Benimaclet", "Camins al Grau", "Campanar",
  "Ciutat Vella", "El Pla del Real", "Extramurs", "Jesús", "L'Eixample",
  "L'Olivereta", "La Saïdia", "Patraix", "Poblats Marítims",
  "Quatre Carreres", "Rascanya"
)

# Calculate exact average distances per district from the dataset
district_means <- datos_raw %>%
  filter(
    !is.na(district),
    !district %in% c("Alboraya Centro", "La Patacona")
  ) %>%
  group_by(district) %>%
  summarise(
    mean_dist_center = round(mean(distance, na.rm = TRUE)),
    mean_dist_metro  = round(mean(distancia_min_estacion_m, na.rm = TRUE)),
    .groups = "drop"
  )

DIST_CENTRO <- setNames(district_means$mean_dist_center, district_means$district)
DIST_METRO  <- setNames(district_means$mean_dist_metro, district_means$district)

# Exact column names the RF model expects (from modelo_rf$coefnames)
MODEL_COLS <- c(
  "FLOORCLEAN", "CONSTRUCTEDAREA", "ROOMNUMBER", "BATHNUMBER",
  "DISTRITOAlgirós", "DISTRITOBenicalap", "DISTRITOBenimaclet",
  "DISTRITOCamins.al.Grau", "DISTRITOCampanar", "DISTRITOCiutat.Vella",
  "DISTRITOEl.Pla.del.Real", "DISTRITOExtramurs", "DISTRITOJesús",
  "DISTRITOL.Eixample", "DISTRITOL.Olivereta", "DISTRITOLa.Saidia",
  "DISTRITOPatraix", "DISTRITOPoblats.Marítims", "DISTRITOQuatre.Carreres",
  "DISTRITORascanya", "DISTANCE_TO_CITY_CENTER", "HASLIFT",
  "DISTANCE_TO_METRO", "status.BuenEstado", "status.Nueva", "status.Restaurar"
)

# ── District summary stats ──────────────────────────────────────────
datos_ref <- datos_raw %>%
  filter(
    !is.na(district),
    !district %in% c("Alboraya Centro", "La Patacona"),
    !is.na(price), !is.na(size), size > 0
  ) %>%
  transmute(
    DISTRITO        = factor(district, levels = DISTRITOS),
    PRICE           = as.numeric(price),
    CONSTRUCTEDAREA = as.numeric(size),
    ROOMNUMBER      = as.numeric(rooms),
    BATHNUMBER      = as.numeric(bathrooms),
    status_raw      = ifelse(status == "newdevelopment", "Nueva",
                             ifelse(status == "renew", "Restaurar", "BuenEstado"))
  ) %>%
  filter(!is.na(PRICE), !is.na(CONSTRUCTEDAREA))

district_stats <- datos_ref %>%
  group_by(DISTRITO) %>%
  summarise(
    median_price = median(PRICE, na.rm = TRUE),
    mean_price   = mean(PRICE,   na.rm = TRUE),
    median_m2    = median(PRICE / CONSTRUCTEDAREA, na.rm = TRUE),
    n            = n(),
    .groups      = "drop"
  )

# ── Map dataset ─────────────────────────────────────────────────────
map_data <- datos_raw %>%
  filter(
    !is.na(district),
    !district %in% c("Alboraya Centro", "La Patacona"),
    !is.na(price)
  ) %>%
  mutate(
    status_label = case_when(
      status == "newdevelopment" ~ "Nueva construcción",
      status == "renew"          ~ "A reformar",
      TRUE                       ~ "Buen estado"
    ),
    url_link = if ("url" %in% names(.)) {
      as.character(url)
    } else if ("propertyCode" %in% names(.)) {
      paste0("https://www.idealista.com/inmueble/", propertyCode, "/")
    } else {
      NA_character_
    },
    price    = as.numeric(price),
    rango_precio = cut(
      price,
      breaks = c(-Inf, 100000, 300000, Inf),
      labels = c("Barato (< 100.000 €)", "Medio (100.000 € - 300.000 €)", "Caro (> 300.000 €)"),
      right = TRUE
    ),
    size     = as.numeric(size),
    rooms    = as.numeric(rooms),
    bathrooms = as.numeric(bathrooms)
  )

has_coords <- all(c("latitude", "longitude") %in% names(map_data))

# ═══════════════════════════════════════════════════════════════════
# PREDICTION FUNCTION
# Builds the exact data frame the RF model expects using MODEL_COLS.
# ═══════════════════════════════════════════════════════════════════
predict_price <- function(floor_n, area, rooms, bathrooms, district,
                          status_val, hasLift, dist_center, dist_metro) {
  tryCatch({

    # 1. Create empty row with all model columns set to 0
    row <- as.data.frame(matrix(0, nrow = 1, ncol = length(MODEL_COLS)))
    colnames(row) <- MODEL_COLS

    # 2. Fill continuous variables
    row[["FLOORCLEAN"]]              <- as.numeric(floor_n)
    row[["CONSTRUCTEDAREA"]]         <- as.numeric(area)
    row[["ROOMNUMBER"]]              <- as.numeric(rooms)
    row[["BATHNUMBER"]]              <- as.numeric(bathrooms)
    row[["DISTANCE_TO_CITY_CENTER"]] <- as.numeric(dist_center) / 1000
    row[["DISTANCE_TO_METRO"]]       <- as.numeric(dist_metro) / 1000
    row[["HASLIFT"]]                 <- as.numeric(isTRUE(hasLift))

    # 3. One-hot district (find matching column name)
    # Map district display names to model column names
    dist_col_map <- c(
      "Algirós"          = "DISTRITOAlgirós",
      "Benicalap"        = "DISTRITOBenicalap",
      "Benimaclet"       = "DISTRITOBenimaclet",
      "Camins al Grau"   = "DISTRITOCamins.al.Grau",
      "Campanar"         = "DISTRITOCampanar",
      "Ciutat Vella"     = "DISTRITOCiutat.Vella",
      "El Pla del Real"  = "DISTRITOEl.Pla.del.Real",
      "Extramurs"        = "DISTRITOExtramurs",
      "Jesús"            = "DISTRITOJesús",
      "L'Eixample"       = "DISTRITOL.Eixample",
      "L'Olivereta"      = "DISTRITOL.Olivereta",
      "La Saïdia"        = "DISTRITOLa.Saidia",
      "Patraix"          = "DISTRITOPatraix",
      "Poblats Marítims" = "DISTRITOPoblats.Marítims",
      "Quatre Carreres"  = "DISTRITOQuatre.Carreres",
      "Rascanya"         = "DISTRITORascanya"
    )
    dist_col <- dist_col_map[district]
    if (!is.na(dist_col) && dist_col %in% MODEL_COLS)
      row[[dist_col]] <- 1

    # 4. One-hot status
    status_col_map <- c(
      "BuenEstado" = "status.BuenEstado",
      "Nueva"      = "status.Nueva",
      "Restaurar"  = "status.Restaurar"
    )
    status_col <- status_col_map[status_val]
    if (!is.na(status_col) && status_col %in% MODEL_COLS)
      row[[status_col]] <- 1

    # 5. Predict and apply IPV correction
    raw_pred <- predict(modelo_rf, newdata = row)
    val <- round(as.numeric(raw_pred) * IPV_FACTOR)
    list(price = val, error = NULL)

  }, error = function(e) {
    err_msg <- conditionMessage(e)
    message("Prediction error: ", err_msg)
    list(price = NA_real_, error = err_msg)
  })
}

# ═══════════════════════════════════════════════════════════════════
# THEME & STYLES
# ═══════════════════════════════════════════════════════════════════
app_theme <- bs_theme(
  version      = 5,
  bg           = "#F8FAFC",
  fg           = "#0F172A",
  primary      = "#4F46E5",
  secondary    = "#10B981",
  base_font    = font_google("Inter"),
  heading_font = font_google("Inter"),
  "navbar-bg"  = "#FFFFFF"
)

css <- "
body { background: #F8FAFC; }
.navbar { background: #FFFFFF !important; border-bottom: 1px solid #E2E8F0; }
.navbar-brand { font-weight: 800; letter-spacing: -0.02em; font-size: 1.2rem; color: #0F172A !important; }
.nav-link { color: #64748B !important; font-weight: 500; transition: color .15s; }
.nav-link.active, .nav-link:hover { color: #4F46E5 !important; }
.container-fluid { padding-top: 0; }

.card { background: #FFFFFF; border: 1px solid #E2E8F0; border-radius: 12px; overflow: hidden; box-shadow: 0 1px 3px 0 rgba(0,0,0,0.05); }
.card-header { background: #F8FAFC; border-bottom: 1px solid #E2E8F0; font-weight: 600; padding: .85rem 1.2rem; font-size: .9rem; color: #1E293B; }
.card-body { padding: 1.2rem; }

.hero {
  background: linear-gradient(135deg, #EEF2F6 0%, #FFFFFF 60%, #ECFDF5 100%);
  padding: 2rem 2.2rem; border-radius: 14px; border: 1px solid #E2E8F0; margin-bottom: 1.5rem;
}
.hero h2 { font-weight: 800; font-size: 1.75rem; margin-bottom: .4rem; color: #0F172A; }
.hero p { color: #475569; margin: 0; font-size: .95rem; }

.price-hero {
  font-size: 3rem; font-weight: 900; line-height: 1.1;
  background: linear-gradient(135deg, #4F46E5, #10B981);
  -webkit-background-clip: text; -webkit-text-fill-color: transparent;
  background-clip: text;
}
.price-label { font-size: .72rem; text-transform: uppercase; letter-spacing: .08em; color: #64748B; margin-bottom: .3rem; }

.metric-card {
  background: linear-gradient(135deg, #F8FAFC, #FFFFFF);
  border: 1px solid #E2E8F0; border-radius: 10px; padding: 1rem 1.1rem;
  text-align: center; height: 100%;
}
.metric-value { font-size: 1.5rem; font-weight: 700; }
.metric-sub { font-size: .75rem; color: #64748B; margin-top: .25rem; }

.badge-ipv {
  display: inline-block; background: rgba(16,185,129,.1); color: #059669;
  padding: .28rem .75rem; border-radius: 999px; font-size: .75rem;
  font-weight: 600; border: 1px solid rgba(16,185,129,.2); margin-top: .6rem;
}

.sidebar-form { background: #FFFFFF; border: 1px solid #E2E8F0; border-radius: 12px; padding: 1.4rem; box-shadow: 0 1px 3px 0 rgba(0,0,0,0.05); }
.section-label { font-size: .68rem; text-transform: uppercase; letter-spacing: .12em; color: #4F46E5; font-weight: 700; margin-bottom: .7rem; }
.form-control, .form-select {
  background: #FFFFFF !important; border-color: #CBD5E1 !important;
  color: #0F172A !important; border-radius: 8px !important;
}
.form-control:focus, .form-select:focus {
  border-color: #4F46E5 !important; box-shadow: 0 0 0 .2rem rgba(79,70,229,.15) !important;
}
label { color: #475569; font-size: .85rem; font-weight: 500; }
.irs--shiny .irs-bar { background: #4F46E5; border-top-color: #4F46E5; border-bottom-color: #4F46E5; }
.irs--shiny .irs-handle { border-color: #4F46E5; }
.irs--shiny .irs-from, .irs--shiny .irs-to, .irs--shiny .irs-single { background: #4F46E5; }
hr { border-color: #E2E8F0; margin: 1rem 0; opacity: 1; }
.checkbox label { color: #475569; }

.btn-calc {
  background: linear-gradient(135deg, #4F46E5, #3730A3); border: none;
  font-weight: 700; font-size: 1.05rem; padding: .8rem;
  border-radius: 10px; width: 100%; transition: all .2s; letter-spacing: .01em; color: #fff;
}
.btn-calc:hover { transform: translateY(-1px); box-shadow: 0 8px 24px rgba(79,70,229,.2); color: #fff; }
.btn-calc:active { transform: translateY(0); }

.empty-state { display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 420px; color: #64748B; text-align: center; }
.empty-icon { font-size: 4rem; margin-bottom: 1rem; opacity: .8; }

.map-sidebar { position: absolute; top: 12px; left: 12px; z-index: 500; width: 268px; }
.map-sidebar .card { box-shadow: 0 4px 20px rgba(0,0,0,.08); }

.leaflet-popup-content-wrapper {
  background: #FFFFFF !important; color: #0F172A !important;
  border: 1px solid #E2E8F0 !important; border-radius: 12px !important;
  box-shadow: 0 8px 32px rgba(0,0,0,.08) !important;
}
.leaflet-popup-tip { background: #FFFFFF !important; }
.leaflet-popup-content { margin: 14px 16px !important; min-width: 200px; }
.popup-price { font-size: 1.25rem; font-weight: 800; color: #059669; margin-bottom: 10px; }
.popup-row { display: flex; justify-content: space-between; font-size: .82rem; padding: 4px 0; border-bottom: 1px solid #F1F5F9; }
.popup-row:last-of-type { border-bottom: none; }
.popup-link { color: #4F46E5 !important; font-weight: 600; text-decoration: none; font-size: .85rem; margin-top: 10px; display: inline-block; }
.popup-link:hover { color: #6366F1 !important; }

/* Legend style override */
.leaflet-control .legend { background: #FFFFFF; color: #0F172A; border: 1px solid #E2E8F0; border-radius: 8px; padding: 8px 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
.info.legend i { display: inline-block; width: 14px; height: 14px; border-radius: 50%; margin-right: 6px; vertical-align: middle; }

/* Radio buttons for chart switcher */
.chart-switcher .shiny-input-radiogroup { display: flex; gap: .5rem; flex-wrap: wrap; }
.chart-switcher .radio { margin: 0; }
.chart-switcher .radio label {
  background: #F1F5F9; border: 1px solid #E2E8F0; border-radius: 8px;
  padding: .35rem .8rem; cursor: pointer; font-size: .82rem; color: #475569;
  transition: all .15s;
}
.chart-switcher .radio input[type=radio]:checked + span + label,
.chart-switcher input[type=radio]:checked ~ label,
.chart-switcher .radio label:has(input:checked) { background: #4F46E5; border-color: #4F46E5; color: #fff; }
"

# ═══════════════════════════════════════════════════════════════════
# UI
# ═══════════════════════════════════════════════════════════════════
ui <- navbarPage(
  title = "🏠 Data Meets Home",
  theme = app_theme,

  tags$head(
    tags$style(HTML(css)),
    tags$meta(charset = "UTF-8"),
    tags$meta(name = "description",
              content = "Predicción interactiva del precio de viviendas en Valencia")
  ),

  # ═══════════════════════════════════════════════════════════
  # TAB 1 — CALCULADORA
  # ═══════════════════════════════════════════════════════════
  tabPanel("🧮 Calculadora",
    fluidPage(
      br(),
      div(class = "hero",
        tags$h2("Calcula el precio estimado de tu vivienda"),
        tags$p(HTML(paste0(
          "Modelo <strong>Random Forest</strong> &middot; Datos Idealista 2018 &middot;",
          " Ajuste IPV INE (", ipv_info$trimestre_base, "&rarr;", ipv_info$trimestre_ref,
          ") &middot; MAE &asymp; 115.000 &euro; &middot; R&sup2; = 0.73"
        )))
      ),

      fluidRow(
        # ── Input Panel ───────────────────────────────────────
        column(4,
          div(class = "sidebar-form",
            div(class = "section-label", "📍 Ubicación"),
            selectInput("s_distrito", "Distrito",
              choices = setNames(DISTRITOS, DISTRITOS), selected = "L'Eixample"),

            hr(),
            div(class = "section-label", "🏠 Características"),

            fluidRow(
              column(6, numericInput("s_area",  "Superficie (m²)", 80, 20, 500, 5)),
              column(6, numericInput("s_floor", "Planta",           3,  0,  30, 1))
            ),
            fluidRow(
              column(6, sliderInput("s_rooms", "Habitaciones", 0, 8, 3, 1, ticks = FALSE)),
              column(6, sliderInput("s_baths", "Baños",        1, 6, 1, 1, ticks = FALSE))
            ),

            selectInput("s_status", "Estado",
              choices  = c("Buen estado"        = "BuenEstado",
                           "Nueva construcción" = "Nueva",
                           "A reformar"         = "Restaurar"),
              selected = "BuenEstado"),

            checkboxInput("s_lift", "Tiene ascensor", TRUE),

            hr(),
            div(class = "section-label", "🗺️ Localización (autorellenado)"),
            numericInput("s_dcenter", "Distancia al centro (m)", DIST_CENTRO[["L'Eixample"]], 50, 10000, 50),
            numericInput("s_dmetro",  "Distancia al metro (m)",   DIST_METRO[["L'Eixample"]],  0,  3000, 50),

            br(),
            actionButton("btn_predict", "✨  Estimar precio",
              class = "btn-calc btn btn-primary")
          )
        ),

        # ── Results Panel ─────────────────────────────────────
        column(8, uiOutput("pred_ui"))
      )
    )
  ),

  # ═══════════════════════════════════════════════════════════
  # TAB 2 — MAPA
  # ═══════════════════════════════════════════════════════════
  tabPanel("🗺️ Mapa Valencia 2025",
    div(style = "position: relative;",

      div(class = "map-sidebar",
        div(class = "card",
          div(class = "card-header", "🔍 Filtros"),
          div(class = "card-body",
            tags$small(class = "price-label", "Rango de precio"),
            sliderInput("f_price", NULL,
              min = 0, max = 2000000, value = c(50000, 800000),
              step = 10000, pre = "€ ", sep = ".", width = "100%"),

            selectInput("f_district", "Distrito",
              choices  = c("Todos los distritos" = "all",
                           setNames(DISTRITOS, DISTRITOS)),
              selected = "all"),

            selectInput("f_status", "Estado",
              choices  = c("Todos"               = "all",
                           "Buen estado"         = "Buen estado",
                           "Nueva construcción"  = "Nueva construcción",
                           "A reformar"          = "A reformar"),
              selected = "all"),

            div(style = "font-size:.82rem; color:#8B949E; margin-top:.5rem;",
              textOutput("map_count"))
          )
        )
      ),

      leafletOutput("map_out", height = "calc(100vh - 80px)")
    )
  ),

  # ═══════════════════════════════════════════════════════════
  # TAB 3 — ANÁLISIS
  # ═══════════════════════════════════════════════════════════
  tabPanel("📊 Análisis",
    fluidPage(
      br(),
      div(class = "hero",
        tags$h2("Análisis del mercado inmobiliario en Valencia"),
        tags$p(HTML(paste0(
          "Dataset Idealista 2025 &nbsp;·&nbsp; ",
          nrow(datos_ref), " propiedades &nbsp;·&nbsp; ",
          length(DISTRITOS), " distritos"
        )))
      ),

      # ── Row 1: Bar charts with selector ──────────────────────
      fluidRow(
        column(12,
          div(class = "card",
            div(class = "card-header",
              span("💰 Precios por distrito — "),
              div(class = "chart-switcher d-inline-block",
                radioButtons("bar_mode", NULL,
                  choices  = c("Precio medio (€)" = "price",
                               "€ / m²"           = "m2"),
                  selected = "price", inline = TRUE)
              )
            ),
            div(class = "card-body", plotlyOutput("ch_bar", height = "380px"))
          )
        )
      ),

      br(),

      # ── Row 2: Scatter ───────────────────────────────────────
      fluidRow(
        column(12,
          div(class = "card",
            div(class = "card-header",
              "📈 Precio vs. Superficie — ",
              span(style = "color:#8B949E; font-weight:400; font-size:.85rem;",
                "Muestra aleatoria de 1.200 propiedades · color = distrito")
            ),
            div(class = "card-body", plotlyOutput("ch_scatter", height = "400px"))
          )
        )
      ),

      br(),

      # ── Row 3: Boxplot ──────────────────────────────────────
      fluidRow(
        column(12,
          div(class = "card",
            div(class = "card-header",
              "📦 Distribución de precios por distrito",
              span(style = "color:#8B949E; font-weight:400; font-size:.85rem;",
                " · Muestra la dispersión, la mediana (línea central) y los outliers")
            ),
            div(class = "card-body", plotlyOutput("ch_box", height = "420px"))
          )
        )
      ),
      br()
    )
  ),

  # ═══════════════════════════════════════════════════════════════
  # TAB 4 — ACERCA DE
  # ═══════════════════════════════════════════════════════════════
  tabPanel("ℹ️ Acerca de",
    fluidPage(
      br(),
      div(class = "hero",
        tags$h2("Data Meets Home"),
        tags$p(HTML(
          "Aplicación interactiva de predicci&#243;n y an&#225;lisis del mercado inmobiliario en Valencia &middot; ",
          "<strong>Proyecto II</strong> &middot; Grado en Ciencia de Datos &middot; UPV 2025"
        ))
      ),

      fluidRow(
        # ── Left column: Methodology ────────────────────────────
        column(7,
          div(class = "card mb-3",
            div(class = "card-header", "🔬 Metodología"),
            div(class = "card-body",
              tags$ol(
                tags$li(HTML("<strong>Datos</strong>: API oficial de Idealista (2018 y 2025, ~9.000 y ~8.000 propiedades respectivamente) + ubicaciones de metro/tranvía vía OpenStreetMap (Overpass API)")),
                tags$li(HTML("<strong>Feature engineering</strong>: distancia al centro histórico, distancia a la estación más cercana, codificación de planta y estado")),
                tags$li(HTML("<strong>Clustering</strong>: PCA + K-Means y Jerárquico para agrupar distritos por perfil de precios")),
                tags$li(HTML("<strong>Modelos comparados</strong>: Regresión Lineal, <em>Random Forest</em> ✓, XGBoost, LightGBM")),
                tags$li(HTML("<strong>Ajuste temporal IPV</strong>: las predicciones del modelo 2018 se escalan con el Índice de Precios de la Vivienda del INE (factor &times;", sprintf("%.4f", IPV_FACTOR), ") para reflejar el mercado de 2025"))
              ),

              tags$hr(),
              tags$h6("Comparativa de modelos", style = "font-weight:700; color:#1E293B;"),
              tags$table(
                class = "table table-sm",
                style = "font-size:.85rem;",
                tags$thead(tags$tr(
                  tags$th("Modelo"), tags$th("RMSE"), tags$th("MAE"), tags$th("R²")
                )),
                tags$tbody(
                  tags$tr(tags$td("Regresión Lineal"),      tags$td("~110.000 €"), tags$td("~65.000 €"), tags$td("0.60")),
                  tags$tr(style="background:rgba(79,70,229,.06);",
                    tags$td(HTML("<strong>Random Forest ✓</strong>")),
                    tags$td(HTML("<strong>~55.000 €</strong>")),
                    tags$td(HTML("<strong>~37.000 €</strong>")),
                    tags$td(HTML("<strong>0.79</strong>"))
                  ),
                  tags$tr(tags$td("XGBoost"),     tags$td("~58.000 €"), tags$td("~39.000 €"), tags$td("0.77")),
                  tags$tr(tags$td("LightGBM"),    tags$td("~57.000 €"), tags$td("~38.000 €"), tags$td("0.77"))
                )
              )
            )
          ),

          div(class = "card",
            div(class = "card-header", "🔗 Recursos del proyecto"),
            div(class = "card-body",
              tags$ul(style = "list-style:none; padding:0; margin:0;",
                tags$li(style = "padding:.4rem 0; border-bottom:1px solid #F1F5F9;",
                  HTML("&#127760; <strong>App online:</strong> <a href='https://datameetshome.shinyapps.io/data-meets-home/' target='_blank' style='color:#4F46E5;'>datameetshome.shinyapps.io/data-meets-home</a>")
                ),
                tags$li(style = "padding:.4rem 0; border-bottom:1px solid #F1F5F9;",
                  HTML("&#128193; <strong>Código fuente:</strong> <a href='https://github.com/RobertTorres16/data-meets-home' target='_blank' style='color:#4F46E5;'>github.com/RobertTorres16/data-meets-home</a>")
                ),
                tags$li(style = "padding:.4rem 0;",
                  HTML("&#128240; <strong>Memoria:</strong> Disponible en el repositorio (<code>docs/Memoria - Data Meets Home.pdf</code>)")
                )
              )
            )
          )
        ),

        # ── Right column: Team + Tech ────────────────────────────
        column(5,
          div(class = "card mb-3",
            div(class = "card-header", "👥 Equipo"),
            div(class = "card-body",
              div(style = "display:flex; flex-direction:column; gap:.75rem;",
                lapply(list(
                  list(name = "Robert Torres Mingarro",      role = "Limpieza de datos 2018 · Ajuste IPV",             icon = "🧹"),
                  list(name = "Jorge Acín Zurita",           role = "Entrenamiento y selección de modelos",             icon = "🤖"),
                  list(name = "Mihai Cristian Mihalache",    role = "Limpieza de datos 2025 · Análisis exploratorio",  icon = "📊"),
                  list(name = "Rubén Tormo Piles",           role = "Scraping · Distancias al metro · Geoespacial",    icon = "🗺️")
                ), function(m) {
                  div(style = "display:flex; align-items:flex-start; gap:.6rem;",
                    div(style = "font-size:1.3rem; margin-top:.1rem;", m$icon),
                    div(
                      div(style = "font-weight:600; color:#1E293B; font-size:.9rem;", m$name),
                      div(style = "font-size:.78rem; color:#64748B;", m$role)
                    )
                  )
                })
              )
            )
          ),

          div(class = "card",
            div(class = "card-header", "⚙️ Tecnologías"),
            div(class = "card-body",
              tags$p(style = "font-size:.82rem; color:#475569; margin-bottom:.5rem;", tags$strong("R:")),
              div(style = "display:flex; flex-wrap:wrap; gap:.35rem; margin-bottom:1rem;",
                lapply(c("shiny","bslib","leaflet","plotly","dplyr","randomForest","ggplot2","caret","xgboost","lightgbm","sf","FactoMineR","rsconnect"), function(pkg) {
                  tags$span(style = "background:#EEF2FF; color:#4F46E5; border:1px solid #C7D2FE; border-radius:6px; padding:.15rem .45rem; font-size:.75rem; font-weight:500;", pkg)
                })
              ),
              tags$p(style = "font-size:.82rem; color:#475569; margin-bottom:.5rem;", tags$strong("Python:")),
              div(style = "display:flex; flex-wrap:wrap; gap:.35rem;",
                lapply(c("requests","pandas","numpy","openpyxl"), function(pkg) {
                  tags$span(style = "background:#ECFDF5; color:#059669; border:1px solid #A7F3D0; border-radius:6px; padding:.15rem .45rem; font-size:.75rem; font-weight:500;", pkg)
                })
              )
            )
          )
        )
      ),
      br()
    )
  )
)

# ═══════════════════════════════════════════════════════════════════
# SERVER
# ═══════════════════════════════════════════════════════════════════
server <- function(input, output, session) {

  # ── Auto-fill distances when district changes ─────────────────
  observeEvent(input$s_distrito, {
    d <- input$s_distrito
    if (!is.null(d) && d %in% names(DIST_CENTRO)) {
      updateNumericInput(session, "s_dcenter", value = DIST_CENTRO[[d]])
      updateNumericInput(session, "s_dmetro",  value = DIST_METRO[[d]])
    }
  })

  # ── Prediction state ──────────────────────────────────────────
  pred_rv <- reactiveValues(price = NULL, area = NULL, district = NULL, error = NULL)

  observeEvent(input$btn_predict, {
    req(input$s_distrito, input$s_area)

    res <- predict_price(
      floor_n     = input$s_floor,
      area        = input$s_area,
      rooms       = input$s_rooms,
      bathrooms   = input$s_baths,
      district    = input$s_distrito,
      status_val  = input$s_status,
      hasLift     = input$s_lift,
      dist_center = input$s_dcenter,
      dist_metro  = input$s_dmetro
    )
    pred_rv$price    <- res$price
    pred_rv$error    <- res$error
    pred_rv$area     <- input$s_area
    pred_rv$district <- input$s_distrito
  })

  # ── Prediction UI ─────────────────────────────────────────────
  output$pred_ui <- renderUI({

    if (is.null(pred_rv$price)) {
      return(div(class = "empty-state",
        div(class = "empty-icon", "🏠"),
        tags$h5("Configura tu vivienda", style = "color:#0F172A; font-weight:700;"),
        tags$p("Introduce las características en el panel izquierdo",
               br(), "y pulsa «Estimar precio» para obtener la predicción.")
      ))
    }

    pred <- pred_rv$price
    area <- pred_rv$area
    dist <- pred_rv$district

    if (is.na(pred)) {
      return(div(class = "card p-4",
        tags$p(style = "color:#EF4444; font-size:1.1rem;", "⚠️ Error en la predicción"),
        tags$p(style = "color:#64748B;",
          "No se pudo obtener una estimación. Detalles del error:"),
        tags$pre(style = "background:#F1F5F9; padding: 10px; border-radius: 5px; color:#EF4444; overflow-x: auto;",
          pred_rv$error),
        tags$p(style = "color:#64748B;",
          "Verifica que todos los campos son válidos.")
      ))
    }

    pred_m2  <- round(pred / max(area, 1))
    d_stats  <- district_stats %>% filter(DISTRITO == dist)
    d_median <- if (nrow(d_stats) > 0) d_stats$median_price[1] else NA_real_

    pct_diff <- if (!is.na(d_median) && d_median > 0)
      round(100 * (pred - d_median) / d_median, 1)
    else NA_real_

    pct_tag <- if (!is.na(pct_diff)) {
      col  <- if (pct_diff > 0) "#EF4444" else "#10B981"
      sign <- if (pct_diff > 0) "+" else ""
      tags$span(
        style = paste0("color:", col, "; font-weight:700; font-size:.9rem;"),
        paste0(sign, pct_diff, "% vs. mediana del distrito")
      )
    } else NULL

    tagList(
      # Price hero card
      div(class = "card p-4 mb-3",
        div(class = "price-label", "Precio estimado · ajustado al IPV 2025"),
        div(class = "price-hero",
            formatC(pred, format = "f", digits = 0, big.mark = ".", decimal.mark = ","), " €"),
        div(style = "margin-top:.7rem;",
          div(class = "badge-ipv", paste0("✓ IPV INE ", ipv_info$trimestre_base, "→", ipv_info$trimestre_ref, " (", sprintf("×%.4f", IPV_FACTOR), ")")),
          if (!is.null(pct_tag)) div(style = "margin-top:.5rem;", pct_tag)
        )
      ),

      # Metric row
      fluidRow(style = "margin-bottom:1rem;",
        column(4, div(class = "metric-card",
          div(class = "metric-value", style = "color:#10B981;",
              formatC(pred_m2, format = "f", digits = 0, big.mark = ".", decimal.mark = ","), " €/m²"),
          div(class = "metric-sub", "Precio por m²")
        )),
        column(4, div(class = "metric-card",
          div(class = "metric-value", style = "color:#4F46E5;",
              if (!is.na(d_median))
                paste0(formatC(round(d_median), format = "f", digits = 0,
                               big.mark = ".", decimal.mark = ","), " €")
              else "N/D"),
          div(class = "metric-sub", paste("Mediana 2025 —", dist))
        )),
        column(4, div(class = "metric-card",
          div(class = "metric-value", style = "color:#F59E0B;", "±115.000 €"),
          div(class = "metric-sub", "Error típico sobre 2025")
        ))
      ),

      # Comparison chart
      div(class = "card mb-3",
        div(class = "card-header",
            paste("📊 Comparativa con el distrito:", dist)),
        div(class = "card-body", plotlyOutput("ch_compare", height = "230px"))
      ),

      # Model performance
      div(class = "card",
        div(class = "card-header", "🤖 Métricas del modelo (evaluación sobre datos reales 2025)"),
        div(class = "card-body",
          fluidRow(
            column(3, div(class = "metric-card",
              div(class = "metric-value", style = "color:#10B981; font-size:1.2rem;", "0.73"),
              div(class = "metric-sub", "R² (2025)")
            )),
            column(3, div(class = "metric-card",
              div(class = "metric-value", style = "color:#F59E0B; font-size:1.2rem;", "37k €"),
              div(class = "metric-sub", "MAE (2018)")
            )),
            column(3, div(class = "metric-card",
              div(class = "metric-value", style = "color:#4F46E5; font-size:1.2rem;", "~115k €"),
              div(class = "metric-sub", "MAE (2025 real)")
            )),
            column(3, div(class = "metric-card",
              div(class = "metric-value", style = "color:#EF4444; font-size:1.2rem;",
                  sprintf("×%.4f", IPV_FACTOR)),
              div(class = "metric-sub", paste0("IPV INE ", ipv_info$trimestre_ref))
            ))
          )
        )
      )
    )
  })

  # ── Comparison bar chart ──────────────────────────────────────
  output$ch_compare <- renderPlotly({
    req(!is.null(pred_rv$price), !is.na(pred_rv$price))

    dist    <- pred_rv$district
    pred    <- pred_rv$price
    d_stats <- district_stats %>% filter(DISTRITO == dist)
    if (nrow(d_stats) == 0) return(NULL)

    df_c <- data.frame(
      label = c("Tu vivienda", "Mediana dist.", "Media dist."),
      price = c(pred, d_stats$median_price[1], d_stats$mean_price[1]),
      color = c("#4F46E5", "#10B981", "#F59E0B"),
      stringsAsFactors = FALSE
    )

    plot_ly(df_c,
      x = ~label, y = ~price, type = "bar",
      marker = list(color = ~color, cornerradius = 4),
      text   = ~paste0(formatC(round(price), format = "f", digits = 0,
                               big.mark = ".", decimal.mark = ","), " €"),
      textposition = "outside",
      hovertemplate = "<b>%{x}</b><br>%{y:,.0f} €<extra></extra>"
    ) %>%
      layout(
        paper_bgcolor = "#FFFFFF", plot_bgcolor  = "#FFFFFF",
        font   = list(color = "#0F172A", family = "Inter"),
        xaxis  = list(title = "", gridcolor = "transparent", linecolor = "#E2E8F0", fixedrange = TRUE),
        yaxis  = list(title = "Precio (€)", gridcolor = "#F1F5F9", linecolor = "#E2E8F0",
                      tickformat = ",.0f", fixedrange = TRUE),
        margin = list(t = 40, b = 10, l = 70, r = 10),
        showlegend = FALSE
      ) %>%
      config(displayModeBar = FALSE)
  })

  # ═══════════════════════════════════════════════════════════════
  # MAP TAB
  # ═══════════════════════════════════════════════════════════════
  map_filtered_all <- reactive({
    p_min <- if (!is.null(input$f_price) && length(input$f_price) >= 2) input$f_price[1] else 50000
    p_max <- if (!is.null(input$f_price) && length(input$f_price) >= 2) input$f_price[2] else 800000
    
    df <- map_data %>%
      filter(price >= p_min, price <= p_max)
      
    f_dist <- if (!is.null(input$f_district)) input$f_district else "all"
    if (f_dist != "all")
      df <- df %>% filter(district == f_dist)
      
    f_status <- if (!is.null(input$f_status)) input$f_status else "all"
    if (f_status != "all")
      df <- df %>% filter(status_label == f_status)
      
    df
  })

  map_filtered <- reactive({
    df <- map_filtered_all()
    if (nrow(df) > 0) {
      set.seed(42) # For reproducibility
      df <- df %>%
        group_by(district) %>%
        filter(row_number() %in% sample(1:n(), max(1, round(n() * 0.40)))) %>%
        ungroup()
    }
    df
  })

  output$map_count <- renderText({
    total <- nrow(map_filtered_all())
    sampled <- nrow(map_filtered())
    if (total == sampled) {
      paste0(total, " propiedades")
    } else {
      paste0(sampled, " mostradas (de ", total, " en total)")
    }
  })

  # Base map (rendered once)
  output$map_out <- renderLeaflet({
    leaflet() %>%
      addProviderTiles("CartoDB.Positron") %>%
      setView(lng = -0.3763, lat = 39.4699, zoom = 12)
  })

  # Reactive layer update (markers + legend updated together)
  observe({
    df <- map_filtered()
    proxy <- leafletProxy("map_out")

    proxy %>%
      clearMarkerClusters() %>%
      clearMarkers() %>%
      clearControls()   # remove old legend before re-adding

    if (!has_coords || nrow(df) == 0) return()

    df_map <- df %>% filter(!is.na(latitude), !is.na(longitude))
    if (nrow(df_map) == 0) return()

    pal <- colorFactor(
      palette  = c("#10B981", "#F59E0B", "#EF4444"),
      levels   = c("Barato (< 100.000 €)", "Medio (100.000 € - 300.000 €)", "Caro (> 300.000 €)"),
      na.color = "#8B949E"
    )

    # Build popup as a column in the data frame (safer with clusters)
    df_map <- df_map %>%
      rowwise() %>%
      mutate(popup_html = {
        url_part <- if (!is.na(url_link) && nchar(url_link) > 5) {
          paste0('<a href="', url_link,
                 '" target="_blank" class="popup-link">🔗 Ver en Idealista</a>')
        } else ""

        paste0(
          '<div class="popup-price">',
          formatC(round(price), format = "f", digits = 0, big.mark = ".", decimal.mark = ","),
          " €</div>",
          '<div class="popup-row"><span>📐 Superficie</span><span><b>',
          ifelse(is.na(size), "—", paste0(size, " m²")), '</b></span></div>',
          '<div class="popup-row"><span>🛏️ Habitaciones</span><span><b>',
          ifelse(is.na(rooms), "—", rooms), '</b></span></div>',
          '<div class="popup-row"><span>🚿 Baños</span><span><b>',
          ifelse(is.na(bathrooms), "—", bathrooms), '</b></span></div>',
          '<div class="popup-row"><span>🏗️ Estado</span><span><b>',
          status_label, '</b></span></div>',
          '<div style="margin-top:10px;">', url_part, '</div>'
        )
      }) %>%
      ungroup()

    proxy %>%
      addCircleMarkers(
        data         = df_map,
        lng          = ~longitude,
        lat          = ~latitude,
        radius       = 7,
        color        = ~pal(rango_precio),
        fillColor    = ~pal(rango_precio),
        fillOpacity  = 0.85,
        stroke       = TRUE,
        weight       = 1.5,
        opacity      = 1,
        popup        = ~popup_html,
        clusterOptions = markerClusterOptions(
          iconCreateFunction = JS("
            function(cluster) {
              var n  = cluster.getChildCount();
              var sz = n < 50 ? 32 : n < 200 ? 40 : 48;
              var bg = n < 50
                ? 'rgba(16,185,129,.9)'
                : n < 200 ? 'rgba(245,158,11,.9)' : 'rgba(239,68,68,.9)';
              return L.divIcon({
                html: '<div style=\"background:' + bg + ';color:#fff;border-radius:50%;' +
                      'width:' + sz + 'px;height:' + sz + 'px;display:flex;align-items:center;' +
                      'justify-content:center;font-weight:700;font-size:.8rem;' +
                      'border:2px solid rgba(255,255,255,.3)\">' + n + '</div>',
                iconSize:   [sz, sz],
                iconAnchor: [sz/2, sz/2]
              });
            }
          ")
        )
      ) %>%
      addLegend(
        position  = "bottomright",
        pal       = pal,
        values    = c("Barato (< 100.000 €)", "Medio (100.000 € - 300.000 €)", "Caro (> 300.000 €)"),
        title     = "Rango de Precio",
        opacity   = 0.9
      )
  })

  # ═══════════════════════════════════════════════════════════════
  # ANALYSIS CHARTS
  # ═══════════════════════════════════════════════════════════════

  # Shared light layout helper
  light_layout <- function(p, xlab = "", ylab = "", angle = -40,
                           show_legend = FALSE, margin_b = 120) {
    p %>%
      layout(
        paper_bgcolor = "#FFFFFF",
        plot_bgcolor  = "#FFFFFF",
        font    = list(color = "#0F172A", family = "Inter"),
        xaxis   = list(title = xlab, tickangle = angle,
                       gridcolor = "#F1F5F9", linecolor = "#E2E8F0",
                       zeroline = FALSE),
        yaxis   = list(title = ylab, gridcolor = "#F1F5F9",
                       tickformat = ",.0f", linecolor = "#E2E8F0",
                       zeroline = FALSE),
        margin  = list(b = margin_b, t = 25, l = 70, r = 15),
        showlegend = show_legend,
        legend  = list(
          bgcolor = "#FFFFFF", bordercolor = "#E2E8F0",
          borderwidth = 1, font = list(size = 10, color = "#0F172A"),
          orientation = "v", x = 1.01, y = 1
        )
      ) %>%
      config(displayModeBar = FALSE)
  }

  # ── Bar chart (price OR m²) with radioButton switcher ───────────
  output$ch_bar <- renderPlotly({
    mode <- input$bar_mode

    if (mode == "price") {
      df <- datos_ref %>%
        group_by(DISTRITO) %>%
        summarise(val = mean(PRICE, na.rm = TRUE), .groups = "drop") %>%
        arrange(desc(val))
      ylab <- "Precio medio (€)"
      ht   <- "<b>%{x}</b><br>%{y:,.0f} €<extra></extra>"
    } else {
      df <- datos_ref %>%
        mutate(pm2 = PRICE / CONSTRUCTEDAREA) %>%
        group_by(DISTRITO) %>%
        summarise(val = mean(pm2, na.rm = TRUE), .groups = "drop") %>%
        arrange(desc(val))
      ylab <- "Precio medio (€/m²)"
      ht   <- "<b>%{x}</b><br>%{y:,.0f} €/m²<extra></extra>"
    }

    # Colour each bar by its value (gradient green→yellow→red)
    norm_val <- (df$val - min(df$val)) / (max(df$val) - min(df$val) + 1)
    bar_cols <- colorRampPalette(c("#10B981", "#F59E0B", "#EF4444"))(nrow(df))
    bar_cols <- bar_cols[rank(df$val)]

    plot_ly(df,
      x = ~reorder(DISTRITO, -val), y = ~val, type = "bar",
      marker = list(color = bar_cols),
      hovertemplate = ht
    ) %>%
      light_layout(ylab = ylab)
  })

  # ── Scatter ──────────────────────────────────────────────────────
  output$ch_scatter <- renderPlotly({
    set.seed(42)
    # Palette of 16 distinguishable colours for districts
    pal16 <- c(
      "#10B981","#7C3AED","#F59E0B","#EF4444","#3B82F6","#EC4899",
      "#14B8A6","#F97316","#8B5CF6","#22D3EE","#84CC16","#FB923C",
      "#A855F7","#34D399","#FBBF24","#60A5FA"
    )

    df_s <- datos_ref %>%
      filter(!is.na(PRICE), !is.na(CONSTRUCTEDAREA),
             CONSTRUCTEDAREA < 400, PRICE < 1500000) %>%
      sample_n(min(1200, nrow(.)))

    # Assign a fixed colour per district
    dist_levels <- levels(df_s$DISTRITO)
    col_map <- setNames(pal16[seq_along(dist_levels)], dist_levels)

    df_s <- df_s %>%
      mutate(color = col_map[as.character(DISTRITO)])

    plot_ly(df_s,
      x = ~CONSTRUCTEDAREA, y = ~PRICE, type = "scatter", mode = "markers",
      color  = ~DISTRITO,
      colors = pal16,
      marker = list(size = 5, opacity = .7, line = list(width = 0)),
      hovertemplate = paste0(
        "<b>%{x} m²</b><br>%{y:,.0f} €",
        "<br><i>%{fullData.name}</i><extra></extra>"
      )
    ) %>%
      light_layout(
        xlab        = "Superficie (m²)",
        ylab        = "Precio (€)",
        angle       = 0,
        show_legend = TRUE,
        margin_b    = 30
      )
  })



  # ── Boxplot ──────────────────────────────────────────────────────
  output$ch_box <- renderPlotly({
    # Show boxplot with district medians as reference markers
    df_b <- datos_ref %>%
      filter(!is.na(PRICE), PRICE < 1500000)

    # Order districts by median price for readability
    dist_order <- datos_ref %>%
      group_by(DISTRITO) %>%
      summarise(med = median(PRICE, na.rm = TRUE), .groups = "drop") %>%
      arrange(med) %>%
      pull(DISTRITO) %>%
      as.character()

    df_b <- df_b %>%
      mutate(DISTRITO = factor(as.character(DISTRITO), levels = dist_order))

    plot_ly(df_b,
      x = ~DISTRITO, y = ~PRICE, type = "box",
      fillcolor   = "rgba(79,70,229,.15)",
      line        = list(color = "#4F46E5", width = 1.5),
      marker      = list(color = "#4F46E5", size = 3, opacity = 0.5),
      boxmean     = TRUE,   # show mean as dashed line
      hovertemplate = paste0(
        "<b>%{x}</b><br>",
        "Mediana: %{median:,.0f} €<br>",
        "Q1: %{q1:,.0f} €<br>",
        "Q3: %{q3:,.0f} €<extra></extra>"
      ),
      showlegend = FALSE
    ) %>%
      light_layout(
        ylab     = "Precio (€)",
        angle    = -40,
        margin_b = 130
      ) %>%
      layout(
        # Annotation explaining the dashed line
        annotations = list(list(
          text      = "— Media  |  ■ Mediana  |  puntos = outliers",
          xref      = "paper", yref = "paper",
          x = 0.5, y = -0.22, showarrow = FALSE,
          font      = list(color = "#64748B", size = 10),
          xanchor   = "center"
        ))
      )
  })
}

# ═══════════════════════════════════════════════════════════════════
# RUN
# ═══════════════════════════════════════════════════════════════════
shinyApp(ui = ui, server = server)
