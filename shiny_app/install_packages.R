# ============================================================
# install_packages.R
# Run this script ONCE before launching the app to ensure
# all required packages are installed.
# ============================================================

pkgs_needed <- c(
  "shiny",
  "bslib",
  "leaflet",
  "plotly",
  "dplyr",
  "caret",
  "randomForest",
  "htmltools",
  "htmlwidgets"
)

pkgs_missing <- pkgs_needed[!pkgs_needed %in% rownames(installed.packages())]

if (length(pkgs_missing) > 0) {
  message("Installing missing packages: ", paste(pkgs_missing, collapse = ", "))
  install.packages(pkgs_missing, dependencies = TRUE)
} else {
  message("✓ All required packages are already installed.")
}

message("\nTo launch the app, run:\n  shiny::runApp('shiny_app/')")
