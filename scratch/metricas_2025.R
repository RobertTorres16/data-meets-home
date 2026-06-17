# Métricas finales del modelo RF sobre datos reales 2025, con factor IPV 1.54
library(randomForest)
library(dplyr)

IPV_FACTOR <- 1.54

message("Cargando modelo y datos...")
modelo_rf <- readRDS("shiny_app/models/modelo_rf_puro.rds")
datos_raw <- readRDS("shiny_app/models/datos_limpios.rds")

# Preparar datos 2025
datos_2025 <- datos_raw %>%
  filter(
    !district %in% c("Alboraya Centro", "La Patacona"),
    !is.na(price), !is.na(size), size > 0,
    !is.na(district)
  ) %>%
  transmute(
    PRICE            = as.numeric(price),
    FLOORCLEAN       = as.numeric(floor),
    CONSTRUCTEDAREA  = as.numeric(size),
    ROOMNUMBER       = as.numeric(rooms),
    BATHNUMBER       = as.numeric(bathrooms),
    DISTRITO         = district,
    DISTANCE_TO_CITY_CENTER = as.numeric(distance) / 1000,
    DISTANCE_TO_METRO       = as.numeric(distancia_min_estacion_m) / 1000,
    HASLIFT          = as.numeric(hasLift),
    status_raw       = ifelse(status == "newdevelopment", "Nueva",
                       ifelse(status == "renew", "Restaurar", "BuenEstado"))
  )

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

mat <- as.data.frame(matrix(0, nrow = nrow(datos_2025), ncol = length(MODEL_COLS)))
colnames(mat) <- MODEL_COLS

mat$FLOORCLEAN              <- datos_2025$FLOORCLEAN
mat$CONSTRUCTEDAREA         <- datos_2025$CONSTRUCTEDAREA
mat$ROOMNUMBER              <- datos_2025$ROOMNUMBER
mat$BATHNUMBER              <- datos_2025$BATHNUMBER
mat$DISTANCE_TO_CITY_CENTER <- datos_2025$DISTANCE_TO_CITY_CENTER
mat$DISTANCE_TO_METRO       <- datos_2025$DISTANCE_TO_METRO
mat$HASLIFT                 <- datos_2025$HASLIFT

for (d in names(dist_col_map)) {
  mat[[dist_col_map[d]]][datos_2025$DISTRITO == d] <- 1
}
mat$status.BuenEstado[datos_2025$status_raw == "BuenEstado"] <- 1
mat$status.Nueva     [datos_2025$status_raw == "Nueva"]      <- 1
mat$status.Restaurar [datos_2025$status_raw == "Restaurar"]  <- 1

# Filtrar filas completas
completos    <- complete.cases(mat)
mat2         <- mat[completos, ]
precio_real  <- datos_2025$PRICE[completos]

message("Prediciendo sobre ", nrow(mat2), " viviendas...")
pred_base <- as.numeric(predict(modelo_rf, newdata = mat2))
pred_ipv  <- pred_base * IPV_FACTOR

# Métricas
mae  <- mean(abs(pred_ipv - precio_real))
rmse <- sqrt(mean((pred_ipv - precio_real)^2))
r2   <- 1 - sum((precio_real - pred_ipv)^2) / sum((precio_real - mean(precio_real))^2)

# Error relativo
mape <- mean(abs(pred_ipv - precio_real) / precio_real) * 100

# Métricas sin factor (modelo bruto)
mae_bruto  <- mean(abs(pred_base - precio_real))
rmse_bruto <- sqrt(mean((pred_base - precio_real)^2))

cat("\n")
cat("╔══════════════════════════════════════════════════════════════╗\n")
cat("║     EVALUACIÓN RANDOM FOREST · DATOS 2025 REALES (IDEALISTA) ║\n")
cat("╠══════════════════════════════════════════════════════════════╣\n")
cat(sprintf("║  N viviendas evaluadas       : %6d                        ║\n", nrow(mat2)))
cat(sprintf("║  Precio medio real           : %6.0f €                     ║\n", mean(precio_real)))
cat(sprintf("║  Predicción media (con ×%.2f): %6.0f €                     ║\n", IPV_FACTOR, mean(pred_ipv)))
cat("╠══════════════════════════════════════════════════════════════╣\n")
cat("║  Métricas con factor IPV ×1.54                               ║\n")
cat("╠══════════════════════════════════════════════════════════════╣\n")
cat(sprintf("║  MAE   (Error Absoluto Medio) : %8.0f €                   ║\n", mae))
cat(sprintf("║  RMSE  (Raíz Error Cuadrático): %8.0f €                   ║\n", rmse))
cat(sprintf("║  R²    (Coef. determinación)  : %8.4f                      ║\n", r2))
cat(sprintf("║  MAPE  (Error relativo medio) : %8.1f %%                    ║\n", mape))
cat("╠══════════════════════════════════════════════════════════════╣\n")
cat("║  Métricas SIN factor (predicción bruta 2018)                 ║\n")
cat("╠══════════════════════════════════════════════════════════════╣\n")
cat(sprintf("║  MAE  bruto                   : %8.0f €                   ║\n", mae_bruto))
cat(sprintf("║  RMSE bruto                   : %8.0f €                   ║\n", rmse_bruto))
cat("╚══════════════════════════════════════════════════════════════╝\n")

# Por distrito
cat("\nMAE por distrito (con factor ×1.54):\n")
df_res <- data.frame(precio_real, pred_ipv, distrito = datos_2025$DISTRITO[completos])
por_distrito <- df_res %>%
  group_by(distrito) %>%
  summarise(
    n    = n(),
    MAE  = round(mean(abs(pred_ipv - precio_real))),
    RMSE = round(sqrt(mean((pred_ipv - precio_real)^2))),
    media_real = round(mean(precio_real)),
    .groups = "drop"
  ) %>%
  arrange(MAE)

for (i in 1:nrow(por_distrito)) {
  cat(sprintf("  %-20s  n=%4d  MAE=%8.0f €  RMSE=%8.0f €  (media real=%6.0f €)\n",
              por_distrito$distrito[i], por_distrito$n[i],
              por_distrito$MAE[i], por_distrito$RMSE[i], por_distrito$media_real[i]))
}
