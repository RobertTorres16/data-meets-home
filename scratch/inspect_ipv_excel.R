# Inspeccion manual del Excel IPV para identificar correctamente las filas
library(readxl)

datos_ipv <- suppressMessages(suppressWarnings(
  read_excel("data/IPV_ComunidadValenciana.xlsx")
))

cat("Primeras 25 filas, columnas 1 a 10:\n")
for (i in 1:min(25, nrow(datos_ipv))) {
  vals <- paste(as.character(unlist(datos_ipv[i, 1:min(10, ncol(datos_ipv))])), collapse=" | ")
  cat(sprintf("Fila %2d: %s\n", i, vals))
}
