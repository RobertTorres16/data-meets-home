# Data Meets Home — Predicción de Precios de Vivienda en Valencia

Aplicación interactiva de análisis y predicción de precios de vivienda en la ciudad de Valencia, utilizando datos reales de Idealista (2018 y 2025). Combina técnicas de web scraping, limpieza de datos, análisis exploratorio, clustering de distritos y modelos de Machine Learning.

**App online:** https://datameetshome.shinyapps.io/data-meets-home/

---

## Descripción

Data Meets Home permite a cualquier usuario:

- **Estimar el precio** de una vivienda en Valencia según sus características (superficie, planta, habitaciones, baños, ascensor, distrito, estado).
- **Explorar el mapa** con propiedades reales del dataset 2025, filtrables por precio, distrito y estado.
- **Analizar el mercado** inmobiliario por distrito con gráficos interactivos de precios, precio por m² y distribución estadística.

El modelo subyacente es un **Random Forest** entrenado con más de 9.000 propiedades de Idealista 2018, ajustado temporalmente al mercado de 2025 mediante el **Índice de Precios de la Vivienda (IPV)** del INE.

---

## Estructura del Proyecto

```
├── notebooks/                       # Pipeline completo de datos y modelos
│   ├── 01_api_scraping.ipynb        # Scraping de la API de Idealista (Python)
│   ├── 02_distancia_metro.ipynb     # Distancia al metro más cercano vía OpenStreetMap (Python)
│   ├── 03_limpieza_2018.Rmd         # Limpieza y EDA del dataset 2018 (R)
│   ├── 04_limpieza_2025.Rmd         # Limpieza del dataset 2025 (R)
│   ├── 05_modelos.Rmd               # Entrenamiento, evaluación y selección de modelos (R)
│   └── 06_ajuste_ipv.Rmd            # Ajuste temporal con el IPV del INE (R)
├── data/                            # Datasets originales y auxiliares
│   ├── propiedades_valencia.xlsx    # Dataset Idealista 2018 (~9.000 propiedades)
│   ├── propiedades_valencia_2025.xlsx # Dataset Idealista 2025 (~8.000 propiedades)
│   ├── estaciones_valencia.xlsx     # Coordenadas de estaciones de metro/tranvía
│   ├── IPC.xlsx / IPV.xlsx          # Índices de precios del INE
│   └── barris.csv                   # Shapefile de barrios de Valencia
├── models/                          # Modelos entrenados (no versionados por tamaño)
├── docs/
│   └── Memoria - Data Meets Home.pdf
├── shiny_app/
│   ├── app.R                        # Aplicación Shiny (UI + Server, ~1.100 líneas)
│   ├── install_packages.R           # Script de instalación de dependencias
│   ├── deploy.R                     # Script de despliegue a shinyapps.io
│   └── models/                      # Modelos serializados para la app
│       ├── datos_limpios.rds        # Dataset procesado
│       ├── modelo_rf_puro.rds       # Modelo Random Forest
│       └── factor_ipv.rds           # Factor de ajuste IPV 2018→2025
├── Lanzar App.bat                   # Ejecutar la app localmente (Windows)
├── Desplegar App.bat                # Desplegar en shinyapps.io (Windows)
└── requirements.txt                 # Dependencias de Python
```

---

## Metodología

### 1. Obtención de Datos
- **API de Idealista**: Extracción de propiedades en venta en Valencia (2018 y 2025) con precio, superficie, habitaciones, baños, planta, coordenadas GPS, estado y distrito.
- **API de Overpass (OpenStreetMap)**: Coordenadas de todas las estaciones de metro y tranvía de Valencia para calcular la distancia al transporte público más cercano.

### 2. Feature Engineering
- Parsing de columnas JSON anidadas (`priceInfo`, `detailedType`, `parkingSpace`).
- Cálculo de distancia al centro histórico (Plaza del Ayuntamiento) por fórmula haversine.
- Cálculo de distancia a la estación de metro/tranvía más cercana para cada propiedad.
- Detección y tratamiento de outliers (precio < 30k€, superficie < 20m²).

### 3. Análisis Exploratorio
- Distribución de precios por distrito y tipo de vivienda.
- Análisis de correlación entre variables continuas.
- Clustering de distritos con PCA + K-Means y Clustering Jerárquico.

### 4. Modelos Predictivos

| Modelo | RMSE | MAE | R² |
|--------|------|-----|----|
| Regresión Lineal | ~110.000 € | ~65.000 € | 0.60 |
| **Random Forest** | **~55.000 €** | **~37.000 €** | **0.79** |
| XGBoost | ~58.000 € | ~39.000 € | 0.77 |
| LightGBM | ~57.000 € | ~38.000 € | 0.77 |

El **Random Forest** fue seleccionado por su mejor equilibrio entre precisión y capacidad de generalización al dataset de 2025.

### 5. Ajuste Temporal con IPV
Las predicciones del modelo (entrenado con datos de 2018) se ajustan multiplicando por el ratio IPV(2024-T4) / IPV(2018-T1) ≈ ×1.43, calculado automáticamente desde los datos del INE y serializado en `factor_ipv.rds`.

**Error medio en 2025 tras ajuste IPV: ~115.000 € (R² = 0.73)**

---

## Ejecutar en Local

```r
# Instalar dependencias
source("shiny_app/install_packages.R")

# Lanzar la app
shiny::runApp("shiny_app/")
```

O ejecuta el archivo `Lanzar App.bat` incluido en el repositorio.

---

## Tecnologías

**R:** `shiny` · `bslib` · `leaflet` · `plotly` · `dplyr` · `randomForest` · `ggplot2` · `caret` · `xgboost` · `lightgbm` · `sf` · `FactoMineR` · `factoextra` · `NbClust` · `corrplot` · `readxl` · `jsonlite` · `tidyr` · `rsconnect`

**Python:** `requests` · `pandas` · `numpy` · `openpyxl`

---

## Licencia

Los datos de Idealista se usan exclusivamente con fines académicos y de investigación.
