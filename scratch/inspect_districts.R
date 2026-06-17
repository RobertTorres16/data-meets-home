# Inspect data to see district names and model column expectations
library(dplyr)

datos_raw <- readRDS("shiny_app/models/datos_limpios.rds")
modelo_rf <- readRDS("shiny_app/models/modelo_rf.rds")

print("Unique districts in datos_raw:")
print(unique(datos_raw$district))

print("DIST_CENTRO:")
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
print(DIST_CENTRO)

print("Check if caretaker model RF expects these exact column names:")
print(modelo_rf$coefnames)
