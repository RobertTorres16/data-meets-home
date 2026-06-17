@echo off
title Data Meets Home — Desplegando app a shinyapps.io...
echo.
echo  ==================================================
echo   Data Meets Home - Despliegue en shinyapps.io
echo  ==================================================
echo.
echo  Esto subira tu aplicacion a la nube (shinyapps.io).
echo  Asegurate de tener conexion a internet activa.
echo.

cd shiny_app
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" deploy.R
cd ..

pause
