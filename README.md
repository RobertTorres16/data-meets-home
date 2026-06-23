# 🏠 Data Meets Home — Predicción de Precios de Vivienda en Valencia

> **Proyecto II · Grado en Ciencia de Datos · Universitat Politècnica de València (UPV)**  
> Aplicación interactiva para la estimación y exploración del mercado inmobiliario en Valencia, basada en datos reales de Idealista (2018–2025) y modelos de Machine Learning.

---

## 🔗 Links de Entrega

| Recurso | URL |
|---|---|
| 🌐 **App online** | https://datameetshome.shinyapps.io/data-meets-home/ |
| 📂 **Código fuente** | https://github.com/RobertTorres16/data-meets-home |
| 🎬 **Vídeo demo** | *(enlace pendiente de subir a Google Drive)* |
| 📄 **Memoria** | [`docs/Memoria - Data Meets Home.pdf`](docs/Memoria%20-%20Data%20Meets%20Home.pdf) |

---

## 📌 Descripción del Proyecto

**Data Meets Home** es una aplicación Shiny interactiva que permite a cualquier ciudadano:

- 🧮 **Estimar el precio** de una vivienda en Valencia en 2025 según sus características (superficie, planta, habitaciones, baños, ascensor, distrito, estado).
- 🗺️ **Explorar el mapa** con las propiedades reales del dataset 2025, filtrables por precio, distrito y estado.
- 📊 **Analizar el mercado** inmobiliario por distrito con gráficos interactivos de precios, precio por m² y distribución estadística.

El modelo subyacente es un **Random Forest** entrenado con 9.000+ propiedades de Idealista 2018, ajustado temporalmente al mercado de 2025 mediante el **Índice de Precios de la Vivienda (IPV)** del INE.

---

## 📂 Estructura del Proyecto

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
│   ├── ASSETID.csv                  # Identificadores de activos
│   ├── estaciones_valencia.xlsx     # Coordenadas de estaciones de metro/tranvía
│   ├── IPC.xlsx / IPV.xlsx          # Índices de precios del INE
│   └── barris.csv                   # Shapefile de barrios de Valencia
├── models/                          # Modelos entrenados (no versionados por tamaño)
├── docs/
│   └── Memoria - Data Meets Home.pdf # Memoria completa del proyecto
├── shiny_app/
│   ├── app.R                        # Aplicación Shiny (UI + Server, ~980 líneas)
│   ├── install_packages.R           # Script de instalación de dependencias
│   ├── deploy.R                     # Script de despliegue a shinyapps.io
│   └── models/                      # Modelos comprimidos para la app
│       ├── datos_limpios.rds        # Dataset procesado (~8.000 propiedades)
│       ├── modelo_rf_puro.rds       # Modelo Random Forest entrenado
│       └── factor_ipv.rds           # Factor de ajuste IPV 2018→2025
├── Lanzar App.bat                   # Acceso directo para ejecutar la app localmente
├── Desplegar App.bat                # Acceso directo para desplegar en shinyapps.io
└── requirements.txt                 # Dependencias de Python
```

---

## 🔬 Metodología

### 1. Obtención de Datos
- **API de Idealista**: Extracción de propiedades en venta en Valencia (2018 y 2025) mediante la API oficial REST de Idealista. Datos de: precio, superficie, habitaciones, baños, planta, coordenadas GPS, estado y distrito.
- **API de Overpass (OpenStreetMap)**: Obtención de las coordenadas de todas las estaciones de metro y tranvía de Valencia para calcular la distancia al transporte público más cercano.

### 2. Feature Engineering
- Parsing de columnas JSON anidadas (`priceInfo`, `detailedType`, `parkingSpace`).
- Cálculo de **distancia al centro histórico** (Plaza del Ayuntamiento) por haversine.
- Cálculo de **distancia a la estación de metro/tranvía más cercana** para cada propiedad.
- Creación de variables derivadas: precio/m², clasificación por tamaño, codificación ordinal de planta.
- Detección y tratamiento de outliers (precio < 30k€, superficie < 20m²).

### 3. Análisis Exploratorio
- Distribución de precios por distrito y tipo de vivienda.
- Análisis de correlación entre variables continuas.
- **Clustering de distritos** con PCA + K-Means y Clustering Jerárquico para detectar zonas con perfiles similares.

### 4. Modelos Predictivos

| Modelo | RMSE | MAE | R² |
|--------|------|-----|----|
| Regresión Lineal | ~110.000 € | ~65.000 € | 0.60 |
| **Random Forest** | **~55.000 €** | **~37.000 €** | **0.79** |
| XGBoost | ~58.000 € | ~39.000 € | 0.77 |
| LightGBM | ~57.000 € | ~38.000 € | 0.77 |

El **Random Forest** fue seleccionado por su mejor equilibrio entre precisión (R² = 0.79 en 2018) y capacidad de generalización al dataset de 2025.

### 5. Ajuste Temporal con IPV
Las predicciones del modelo (entrenado con datos de 2018) se ajustan multiplicando por el ratio:

```
IPV_FACTOR = IPV(2024-T4) / IPV(2018-T1)  →  ~×1.43
```

Este factor se calcula automáticamente en `06_ajuste_ipv.Rmd` a partir de los datos del INE y se serializa en `factor_ipv.rds`.

**Error medio en 2025 (con ajuste IPV): ~115.000 €** (R² = 0.73)

---

## 🖥️ Funcionalidades de la App

### 🧮 Calculadora de Precios
- Configura las características de una vivienda y obtén un precio estimado instantáneo.
- Las distancias al centro y al metro se rellenan automáticamente al seleccionar el distrito.
- El resultado incluye: precio estimado, precio/m², comparativa con la mediana del distrito, y métricas del modelo.

### 🗺️ Mapa Interactivo (Valencia 2025)
- Visualiza más de 8.000 propiedades reales sobre mapa Leaflet.
- Filtra por rango de precio, distrito y estado de la vivienda.
- Clusters inteligentes con colores por densidad de precios.
- Popups con precio, características y enlace directo a Idealista.

### 📊 Análisis del Mercado
- **Barras**: precio medio o €/m² por distrito, ordenado de mayor a menor.
- **Scatter**: precio vs. superficie para 1.200 propiedades aleatorias, coloreadas por distrito.
- **Boxplot**: distribución completa de precios por distrito, con media, mediana y outliers.

---

## 🚀 Ejecutar en Local

### Prerrequisitos
- R ≥ 4.0
- RStudio (recomendado)

### Instalación

```r
# 1. Instalar dependencias
source("shiny_app/install_packages.R")

# 2. Lanzar la app
shiny::runApp("shiny_app/")
```

O simplemente ejecuta el archivo **`Lanzar App.bat`** incluido en el repositorio.

---

## ☁️ Despliegue en shinyapps.io

```r
# Desde el directorio shiny_app/
source("deploy.R")
```

URL pública: **https://datameetshome.shinyapps.io/data-meets-home/**

---

## 🛠️ Tecnologías

### R
`shiny` · `bslib` · `leaflet` · `plotly` · `dplyr` · `randomForest` · `ggplot2` · `caret` · `xgboost` · `lightgbm` · `sf` · `FactoMineR` · `factoextra` · `NbClust` · `corrplot` · `readxl` · `jsonlite` · `tidyr` · `rsconnect`

### Python
`requests` · `pandas` · `numpy` · `openpyxl`

---

## 👥 Autores

| Nombre | Contribución principal |
|---|---|
| **Robert Torres Mingarro** | Limpieza de datos 2018 y ajuste de predicciones con el IPV |
| **Jorge Acín Zurita** | Entrenamiento, evaluación y selección de modelos predictivos |
| **Mihai Cristian Mihalache Farcas** | Limpieza de datos 2025 y análisis exploratorio |
| **Rubén Tormo Piles** | Scraping de datos, distancias al metro y feature engineering geoespacial |

---

## 📄 Licencia

Proyecto académico — Grado en Ciencia de Datos, Universitat Politècnica de València (UPV).  
Los datos de Idealista se usan exclusivamente con fines académicos.
