setwd("c:/Users/rtorr/OneDrive/Documentos/uni/4/Proyecto II/Proyecto inmuebles/shiny_app")
library(dplyr)
library(caret)
library(randomForest)

modelo_rf <- readRDS("../models/modelo_rf.rds")
datos_2025 <- readRDS("../models/datos_limpios.rds")

# Prepare dataset
datos_predecir <- datos_2025 %>%
    filter(district != "Alboraya Centro", district != "La Patacona") %>%
    transmute(
        FLOORCLEAN = floor,
        PRICE = price,
        CONSTRUCTEDAREA = as.numeric(size),
        ROOMNUMBER = rooms,
        BATHNUMBER = bathrooms,
        DISTRITO = district,
        DISTANCE_TO_CITY_CENTER = distance / 1000, # In Km!
        status = status,
        HASLIFT = as.factor(hasLift),
        UNITPRICE = priceByArea,
        DISTANCE_TO_METRO = distancia_min_estacion_m / 1000, # In Km!
    )

datos_predecir <- datos_predecir %>%
    filter(!is.na(status), !is.na(HASLIFT))

mediana_floor <- median(datos_predecir$FLOORCLEAN, na.rm = TRUE)
datos_predecir$FLOORCLEAN[is.na(datos_predecir$FLOORCLEAN)] <- mediana_floor

datos_predecir$status <- ifelse(datos_predecir$status == "newdevelopment", "Nueva", ifelse(datos_predecir$status == "renew", "Restaurar", "BuenEstado"))
datos_predecir$status <- as.factor(datos_predecir$status)
datos_predecir$HASLIFT = as.factor(datos_predecir$HASLIFT)

dummies <- dummyVars(PRICE ~ ., data = datos_predecir)
datos_dummies <- predict(dummies, newdata = datos_predecir)
cols_to_remove <- grep("^HASLIFT\\.", colnames(datos_dummies), value = TRUE)
datos_predecir2 <- datos_dummies[, !(colnames(datos_dummies) %in% cols_to_remove)]
datos_predecir2 <- as.data.frame(datos_predecir2)
datos_predecir2$PRICE <- datos_predecir$PRICE
datos_predecir2$HASLIFT <- as.numeric(as.character(datos_predecir$HASLIFT))

colnames(datos_predecir2)[colnames(datos_predecir2) == "DISTRITOCamins al Grau"] <- "DISTRITOCamins.al.Grau"
colnames(datos_predecir2)[colnames(datos_predecir2) == "DISTRITOCiutat Vella"] <- "DISTRITOCiutat.Vella"
colnames(datos_predecir2)[colnames(datos_predecir2) == "DISTRITOEl Pla del Real"] <- "DISTRITOEl.Pla.del.Real"
colnames(datos_predecir2)[colnames(datos_predecir2) == "DISTRITOL'Eixample"] <- "DISTRITOL.Eixample"
colnames(datos_predecir2)[colnames(datos_predecir2) == "DISTRITOL'Olivereta"] <- "DISTRITOL.Olivereta"
colnames(datos_predecir2)[colnames(datos_predecir2) == "DISTRITOLa Saïdia"] <- "DISTRITOLa.Saidia"
colnames(datos_predecir2)[colnames(datos_predecir2) == "DISTRITOPatraix"] <- "DISTRITOPatraix"
colnames(datos_predecir2)[colnames(datos_predecir2) == "DISTRITOPoblats Marítims"] <- "DISTRITOPoblats.Marítims"
colnames(datos_predecir2)[colnames(datos_predecir2) == "DISTRITOQuatre Carreres"] <- "DISTRITOQuatre.Carreres"
colnames(datos_predecir2)[colnames(datos_predecir2) == "DISTRITORascanya"] <- "DISTRITORascanya"

pred_rf_raw <- predict(modelo_rf, newdata = datos_predecir2)

factors <- seq(1.5, 2.0, by = 0.05)
for (f in factors) {
  pred <- pred_rf_raw * f
  mae <- MAE(pred, datos_predecir2$PRICE)
  rmse <- RMSE(pred, datos_predecir2$PRICE)
  print(paste("Factor:", f, "-> MAE:", round(mae), "-> RMSE:", round(rmse), "-> Median Pred:", median(pred)))
}
