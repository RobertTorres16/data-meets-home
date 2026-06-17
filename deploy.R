# ============================================================
# deploy.R
# Script para desplegar la app de Shiny en shinyapps.io
# ============================================================

# 1. Asegurar que rsconnect esté instalado
if (!require("rsconnect", quietly = TRUE)) {
  message("Instalando el paquete 'rsconnect' necesario para el despliegue...")
  install.packages("rsconnect", dependencies = TRUE, repos = "https://cloud.r-project.org")
  library(rsconnect)
}

# 2. Configurar la cuenta con tus credenciales
message("Configurando las credenciales de rsconnect...")
rsconnect::setAccountInfo(
  name   = 'datameetshome',
  token  = '82AB60EB1766A946542BF8D219DBD0C7',
  secret = 'Eq+HxVjtDaMiREEq95bt0XnHOdcZUq/vRYcYM3kg'
)

# 3. Desplegar la aplicación
# Por defecto se desplegará el contenido de la carpeta 'shiny_app'
# Puedes cambiar 'appName' si deseas que la URL final tenga otro nombre
message("Iniciando el despliegue de la aplicación a shinyapps.io...")
rsconnect::deployApp(
  appDir = 'shiny_app',
  appName = 'data-meets-home', # URL: https://datameetshome.shinyapps.io/data-meets-home/
  forceUpdate = TRUE
)

message("¡Despliegue finalizado con éxito!")
