@echo off
title Data Meets Home — Lanzando app...
echo.
echo  ==========================================
echo   Data Meets Home - Valencia Housing App
echo  ==========================================
echo.
echo  Abriendo la app en tu navegador...
echo  (Cierra esta ventana para detener la app)
echo.

"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "shiny::runApp('shiny_app/', launch.browser=TRUE, port=3838)"

pause
