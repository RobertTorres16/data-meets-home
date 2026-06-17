library(dplyr)
library(caret)
library(randomForest)

datos_2025 <- readRDS("../models/datos_limpios.rds")
modelo_rf <- readRDS("../models/modelo_rf.rds")

datos_2025 <- datos_2025 %>% 
  filter(!district %in% c("Alboraya Centro", "La Patacona"))

datos_predecir <- datos_2025 %>%
  transmute(
    FLOORCLEAN = floor,
    PRICE = price,
    CONSTRUCTEDAREA = as.numeric(size),
    ROOMNUMBER = rooms,
    BATHNUMBER = bathrooms,
    DISTRITO = district,
    DISTANCE_TO_CITY_CENTER = distance / 1000,
    status = status,
    HASLIFT = as.numeric(isTRUE(hasLift)),
    DISTANCE_TO_METRO = distancia_min_estacion_m / 1000,
  )

mediana_floor <- 3
datos_predecir$FLOORCLEAN[is.na(datos_predecir$FLOORCLEAN)] <- mediana_floor
datos_predecir$status <- ifelse(datos_predecir$status == "newdevelopment", "Nueva", 
                                ifelse(datos_predecir$status == "renew", "Restaurar", "BuenEstado"))

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

model_input <- as.data.frame(matrix(0, nrow = nrow(datos_predecir), ncol = length(MODEL_COLS)))
colnames(model_input) <- MODEL_COLS

model_input$FLOORCLEAN <- datos_predecir$FLOORCLEAN
model_input$CONSTRUCTEDAREA <- datos_predecir$CONSTRUCTEDAREA
model_input$ROOMNUMBER <- datos_predecir$ROOMNUMBER
model_input$BATHNUMBER <- datos_predecir$BATHNUMBER
model_input$DISTANCE_TO_CITY_CENTER <- datos_predecir$DISTANCE_TO_CITY_CENTER
model_input$DISTANCE_TO_METRO <- datos_predecir$DISTANCE_TO_METRO
model_input$HASLIFT <- datos_predecir$HASLIFT

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

for (i in 1:nrow(datos_predecir)) {
  d <- datos_predecir$DISTRITO[i]
  if (!is.na(d)) {
    col_d <- dist_col_map[d]
    if (!is.na(col_d)) {
      model_input[i, col_d] <- 1
    }
  }
  st <- datos_predecir$status[i]
  if (!is.na(st)) {
    if (st == "BuenEstado") model_input[i, "status.BuenEstado"] <- 1
    if (st == "Nueva") model_input[i, "status.Nueva"] <- 1
    if (st == "Restaurar") model_input[i, "status.Restaurar"] <- 1
  }
}

preds_raw <- predict(modelo_rf, newdata = model_input)

ratios <- datos_predecir$PRICE / preds_raw
cat("Median ratio (Actual / Raw Pred):", median(ratios, na.rm = TRUE), "\n")
cat("Mean ratio (Actual / Raw Pred):", mean(ratios, na.rm = TRUE), "\n")

# Find the best factor that minimizes MAE
maes <- sapply(seq(1.0, 2.5, 0.05), function(f) {
  mean(abs(preds_raw * f - datos_predecir$PRICE), na.rm = TRUE)
})
best_f <- seq(1.0, 2.5, 0.05)[which.min(maes)]
cat("Best factor for minimizing MAE:", best_f, "with MAE:", min(maes), "\n")

# Find the best factor that minimizes MAPE (Mean Absolute Percentage Error)
mapes <- sapply(seq(1.0, 2.5, 0.05), function(f) {
  mean(abs((preds_raw * f - datos_predecir$PRICE) / datos_predecir$PRICE), na.rm = TRUE)
})
best_f_mape <- seq(1.0, 2.5, 0.05)[which.min(mapes)]
cat("Best factor for minimizing MAPE:", best_f_mape, "with MAPE:", min(mapes), "\n")
