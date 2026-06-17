library(readxl)

datos_ipv_raw <- suppressMessages(suppressWarnings(
  read_excel("data/IPV_ComunidadValenciana.xlsx")
))

N_TRIM <- 72
trimestres_ipv <- as.character(unlist(datos_ipv_raw[7,  2:(N_TRIM + 1)]))
valores_ipv    <- as.numeric(unlist(datos_ipv_raw[13, 2:(N_TRIM + 1)]))

idx_2018    <- grep("^2018", trimestres_ipv)
ipv_2018T1  <- valores_ipv[max(idx_2018)]
trim_2018T1 <- trimestres_ipv[max(idx_2018)]
ipv_ultimo  <- valores_ipv[1]
trim_ultimo <- trimestres_ipv[1]

factor_ipv_real <- ipv_ultimo / ipv_2018T1

cat(sprintf("IPV %s (referencia 2018): %.3f\n", trim_2018T1, ipv_2018T1))
cat(sprintf("IPV %s (ultimo dato):     %.3f\n", trim_ultimo,  ipv_ultimo))
cat(sprintf("FACTOR REAL = %.4f\n", factor_ipv_real))

ipv_info <- list(
  factor         = round(factor_ipv_real, 4),
  ipv_2018T1     = ipv_2018T1,
  ipv_ultimo     = ipv_ultimo,
  trimestre_base = trim_2018T1,
  trimestre_ref  = trim_ultimo,
  fuente         = "INE - Indice de Precios de la Vivienda, Comunitat Valenciana, General"
)

saveRDS(ipv_info, file = "models/factor_ipv.rds")
saveRDS(ipv_info, file = "shiny_app/models/factor_ipv.rds")
message("Guardado: models/factor_ipv.rds y shiny_app/models/factor_ipv.rds")
