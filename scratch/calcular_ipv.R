# Calculo limpio del factor IPV:
# Solo las primeras 72 columnas de datos = IPV General C. Valenciana (fila 13)
# con trimestres de la fila 7, ordenados de 2024T4 a 2007T1

library(readxl)

datos_ipv <- suppressMessages(suppressWarnings(
  read_excel("data/IPV_ComunidadValenciana.xlsx")
))

# Extraer solo los primeros 72 valores (1 serie de indices, sin variaciones)
# El Excel tiene 288 columnas de datos: 72 trimestres x 4 series (indice, var trim, var anual, var anual s.m.)
n_trim <- 72

trimestres <- as.character(unlist(datos_ipv[7,  2:(n_trim + 1)]))
ipv_val    <- as.numeric(unlist(datos_ipv[13, 2:(n_trim + 1)]))

cat("Serie IPV General Comunitat Valenciana:\n")
for (i in seq_along(trimestres)) {
  cat(sprintf("  %s : %.3f\n", trimestres[i], ipv_val[i]))
}

# 2018T1 es el más antiguo entre los de 2018 → último índice en grep
idx_2018 <- grep("^2018", trimestres)
ipv_2018T1  <- ipv_val[max(idx_2018)]   # 2018T1
trim_2018T1 <- trimestres[max(idx_2018)]

# 2024T4 es el más reciente → primer elemento
ipv_2024T4  <- ipv_val[1]
trim_2024T4 <- trimestres[1]

factor_ipv <- ipv_2024T4 / ipv_2018T1

cat("\n═══════════════════════════════════════════════\n")
cat(sprintf("IPV %s (inicio datos entrenamiento): %.3f\n", trim_2018T1, ipv_2018T1))
cat(sprintf("IPV %s (último dato disponible):     %.3f\n", trim_2024T4,  ipv_2024T4))
cat(sprintf("FACTOR IPV REAL = %.3f / %.3f = %.4f\n", ipv_2024T4, ipv_2018T1, factor_ipv))
cat(sprintf("Redondeado a 2 decimales: %.2f\n", round(factor_ipv, 2)))
cat("═══════════════════════════════════════════════\n")
