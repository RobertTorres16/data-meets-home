# Encontrar el factor IPV óptimo minimizando el MAE sobre datos 2025
library(randomForest)
library(dplyr)

message("Cargando modelo y datos...")
modelo_rf <- readRDS("shiny_app/models/modelo_rf_puro.rds")
datos_raw <- readRDS("shiny_app/models/datos_limpios.rds")

# Preparar datos 2025 (igual que en el notebook 06)
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

# One-hot encoding manual
dist_levels <- c(
  "Algirós", "Benicalap", "Benimaclet", "Camins al Grau", "Campanar",
  "Ciutat Vella", "El Pla del Real", "Extramurs", "Jesús",
  "L'Eixample", "L'Olivereta", "La Saïdia", "Patraix",
  "Poblats Marítims", "Quatre Carreres", "Rascanya"
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

# Construir matriz de features
mat <- as.data.frame(matrix(0, nrow = nrow(datos_2025), ncol = length(MODEL_COLS)))
colnames(mat) <- MODEL_COLS

mat$FLOORCLEAN              <- datos_2025$FLOORCLEAN
mat$CONSTRUCTEDAREA         <- datos_2025$CONSTRUCTEDAREA
mat$ROOMNUMBER              <- datos_2025$ROOMNUMBER
mat$BATHNUMBER              <- datos_2025$BATHNUMBER
mat$DISTANCE_TO_CITY_CENTER <- datos_2025$DISTANCE_TO_CITY_CENTER
mat$DISTANCE_TO_METRO       <- datos_2025$DISTANCE_TO_METRO
mat$HASLIFT                 <- datos_2025$HASLIFT

# Distritos
for (d in dist_levels) {
  col <- dist_col_map[d]
  mat[[col]][datos_2025$DISTRITO == d] <- 1
}

# Status
mat$status.BuenEstado[datos_2025$status_raw == "BuenEstado"] <- 1
mat$status.Nueva     [datos_2025$status_raw == "Nueva"]      <- 1
mat$status.Restaurar [datos_2025$status_raw == "Restaurar"]  <- 1

message("Prediciendo sobre ", nrow(mat), " viviendas de 2025...")
# Eliminar filas con NA en cualquier columna del modelo
completos <- complete.cases(mat)
mat2       <- mat[completos, ]
precio_real <- datos_2025$PRICE[completos]
message(nrow(mat2), " filas completas (sin NA)")

pred_base <- as.numeric(predict(modelo_rf, newdata = mat2))

# Buscar el factor óptimo
message("Buscando factor óptimo...")
factores <- seq(1.0, 3.0, by = 0.01)
resultados <- sapply(factores, function(f) {
  pred_ajustado <- pred_base * f
  mae  <- mean(abs(pred_ajustado - precio_real))
  rmse <- sqrt(mean((pred_ajustado - precio_real)^2))
  c(mae = mae, rmse = rmse)
})

mae_vec  <- resultados["mae",]
rmse_vec <- resultados["rmse",]

factor_optimo_mae  <- factores[which.min(mae_vec)]
factor_optimo_rmse <- factores[which.min(rmse_vec)]

cat("\n═══════════════════════════════════════════════════════\n")
cat(sprintf("N viviendas evaluadas:     %d\n", nrow(mat)))
cat(sprintf("Precio medio real:         %.0f €\n", mean(precio_real)))
cat(sprintf("Predicción media (base):   %.0f €\n", mean(pred_base)))
cat("\n")
cat(sprintf("Factor óptimo (min MAE):   %.2f  → MAE = %.0f €\n",
            factor_optimo_mae, min(mae_vec)))
cat(sprintf("Factor óptimo (min RMSE):  %.2f  → RMSE = %.0f €\n",
            factor_optimo_rmse, min(rmse_vec)))
cat("\n")
cat(sprintf("Factor 1.43 → MAE = %.0f €, RMSE = %.0f €\n",
            mae_vec[factores == 1.43], rmse_vec[factores == 1.43]))
cat(sprintf("Factor 1.90 → MAE = %.0f €, RMSE = %.0f €\n",
            mae_vec[factores == 1.90], rmse_vec[factores == 1.90]))
cat("═══════════════════════════════════════════════════════\n")
