# ============================================================
# deploy_v2025.R
# Despliega la versión estable con datos 2025 en una URL separada
# URL: https://datameetshome.shinyapps.io/data-meets-home-2025/
# ============================================================

if (!require("rsconnect", quietly = TRUE)) {
  install.packages("rsconnect", dependencies = TRUE, repos = "https://cloud.r-project.org")
  library(rsconnect)
}

message("Configurando credenciales...")
rsconnect::setAccountInfo(
  name   = 'datameetshome',
  token  = '82AB60EB1766A946542BF8D219DBD0C7',
  secret = 'Eq+HxVjtDaMiREEq95bt0XnHOdcZUq/vRYcYM3kg'
)

message("Desplegando versión estable 2025 a URL separada...")
rsconnect::deployApp(
  appDir   = '.', # Desplegar el directorio actual (shiny_app/)
  appName  = 'data-meets-home-2025',   # URL distinta: .../data-meets-home-2025/
  forceUpdate = TRUE
)

message("¡Desplegado! URL: https://datameetshome.shinyapps.io/data-meets-home-2025/")
