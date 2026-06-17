# Script para guardar el modelo RF puro (sin wrapper de caret)
# y verificar que predice correctamente con randomForest directamente.

library(caret)
library(randomForest)

message("Cargando modelo caret...")
modelo_caret <- readRDS("shiny_app/models/modelo_rf.rds")

# Extraer el modelo randomForest puro del objeto caret
modelo_rf_puro <- modelo_caret$finalModel
print(modelo_rf_puro)
print(class(modelo_rf_puro))

# Guardar modelo puro
saveRDS(modelo_rf_puro, "shiny_app/models/modelo_rf_puro.rds")
message("Guardado modelo_rf_puro.rds")

# Test rápido de prediccion
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

row <- as.data.frame(matrix(0, nrow = 1, ncol = length(MODEL_COLS)))
colnames(row) <- MODEL_COLS
row[["FLOORCLEAN"]] <- 3
row[["CONSTRUCTEDAREA"]] <- 80
row[["ROOMNUMBER"]] <- 3
row[["BATHNUMBER"]] <- 1
row[["DISTRITOL.Eixample"]] <- 1
row[["status.BuenEstado"]] <- 1
row[["DISTANCE_TO_CITY_CENTER"]] <- 0.9
row[["DISTANCE_TO_METRO"]] <- 0.5
row[["HASLIFT"]] <- 1

message("Predicción con randomForest::predict directo:")
pred <- predict(modelo_rf_puro, newdata = row)
message("Resultado: ", pred * 1.9, " €")
