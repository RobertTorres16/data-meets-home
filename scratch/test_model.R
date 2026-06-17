# Test model prediction and see what error it throws

# 1. Load packages
library(caret)
library(randomForest)

# 2. Load model and data
message("Loading model...")
modelo_rf <- readRDS("shiny_app/models/modelo_rf.rds")
datos_raw <- readRDS("shiny_app/models/datos_limpios.rds")

# 3. Print model info
print(modelo_rf)

# 4. Set up sample inputs
floor_n <- 3
area <- 80
rooms <- 3
bathrooms <- 1
district <- "L'Eixample"
status_val <- "BuenEstado"
hasLift <- TRUE
dist_center <- 1000
dist_metro <- 500

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

# 5. Create prediction row
row <- as.data.frame(matrix(0, nrow = 1, ncol = length(MODEL_COLS)))
colnames(row) <- MODEL_COLS

row[["FLOORCLEAN"]]              <- as.numeric(floor_n)
row[["CONSTRUCTEDAREA"]]         <- as.numeric(area)
row[["ROOMNUMBER"]]              <- as.numeric(rooms)
row[["BATHNUMBER"]]              <- as.numeric(bathrooms)
row[["DISTANCE_TO_CITY_CENTER"]] <- as.numeric(dist_center) / 1000
row[["DISTANCE_TO_METRO"]]       <- as.numeric(dist_metro) / 1000
row[["HASLIFT"]]                 <- as.numeric(isTRUE(hasLift))

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
if (!is.na(dist_col) && dist_col %in% MODEL_COLS) {
  row[[dist_col]] <- 1
}

status_col_map <- c(
  "BuenEstado" = "status.BuenEstado",
  "Nueva"      = "status.Nueva",
  "Restaurar"  = "status.Restaurar"
)
status_col <- status_col_map[status_val]
if (!is.na(status_col) && status_col %in% MODEL_COLS) {
  row[[status_col]] <- 1
}

# Try prediction
message("\nTrying prediction...")
tryCatch({
  pred <- predict(modelo_rf, newdata = row)
  print(pred)
}, error = function(e) {
  message("Error caught in predict: ", conditionMessage(e))
})
