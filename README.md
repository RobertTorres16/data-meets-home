# Data Meets Home — Predicción de Precios de Vivienda en Valencia

Proyecto de análisis y predicción de precios de vivienda en la ciudad de Valencia, utilizando datos de **Idealista** (2018 y 2025). Combina técnicas de web scraping, limpieza de datos, análisis exploratorio, clustering de distritos y modelos de Machine Learning.

Memoria completa: [`docs/Memoria - Data Meets Home.pdf`](docs/Memoria%20-%20Data%20Meets%20Home.pdf)

Proyecto desarrollado en la asignatura **Proyecto II** del segundo curso del Grado en Ciencia de Datos de la **Universitat Politècnica de València (UPV)**.

---

## Estructura del Proyecto

```
├── notebooks/
│   ├── 01_api_scraping.ipynb        # Scraping de la API de Idealista (Python)
│   ├── 02_distancia_metro.ipynb     # Cálculo de distancia al metro más cercano (Python)
│   ├── 03_limpieza_2018.Rmd        # Limpieza del dataset 2018 (R)
│   ├── 04_limpieza_2025.Rmd        # Limpieza del dataset 2025 (R)
│   ├── 05_modelos.Rmd              # Entrenamiento y evaluación de modelos (R)
│   └── 06_ajuste_ipv.Rmd           # Ajuste con el IPV para predicción 2025 (R)
├── data/                            # Datasets originales y auxiliares
├── models/                          # Modelos entrenados (.rds, no versionados)
├── docs/                            # Memoria del proyecto (PDF)
├── .gitignore
└── README.md
```

---

## Metodología

### 1. Obtención de Datos
- **API de Idealista**: Extracción de propiedades en venta en Valencia mediante la API oficial.
- **API de Overpass (OpenStreetMap)**: Obtención de ubicaciones de estaciones de metro para calcular la distancia al transporte público más cercano.

### 2. Limpieza y Preparación
- Eliminación de duplicados y variables irrelevantes.
- Parsing de columnas JSON (priceInfo, detailedType, parkingSpace).
- Detección y tratamiento de valores anómalos.
- Feature engineering: ratio habitaciones/baños, rango de precios, clasificación por tamaño.

### 3. Análisis Exploratorio
- Distribución de precios por distrito y tipo de vivienda.
- Análisis de correlación entre variables.
- Clustering de distritos mediante PCA + K-Means / Hierarchical Clustering.

### 4. Modelos Predictivos

| Modelo | RMSE | MAE | R² |
|--------|------|-----|-----|
| Regresión Lineal | ~110.000 € | ~65.000 € | 0.60 |
| **Random Forest** | **~55.000 €** | **~37.000 €** | **0.79** |
| XGBoost | ~58.000 € | ~39.000 € | 0.77 |
| LightGBM | ~57.000 € | ~38.000 € | 0.77 |

**Random Forest** fue seleccionado como el mejor modelo, con un equilibrio óptimo entre precisión y capacidad de generalización.

### 5. Ajuste Temporal con IPV
Las predicciones del modelo (entrenado con datos de 2018) se ajustan con el **Índice de Precios de la Vivienda (IPV)** de la Comunidad Valenciana para reflejar la evolución real del mercado hasta 2025.

---

## Tecnologías

### R
`dplyr` · `ggplot2` · `caret` · `randomForest` · `xgboost` · `lightgbm` · `sf` · `leaflet` · `FactoMineR` · `factoextra` · `NbClust` · `corrplot` · `readxl` · `jsonlite` · `tidyr`

### Python
`requests` · `pandas` · `numpy`

---

## Requisitos

### R (>= 4.0)
```r
install.packages(c(
  "dplyr", "readxl", "ggplot2", "caret", "readr", "jsonlite", "stringr",
  "knitr", "sf", "leaflet", "shiny", "geojsonsf", "ggcorrplot", "broom",
  "MASS", "tidyr", "cluster", "FactoMineR", "factoextra", "NbClust",
  "clValid", "lightgbm", "corrplot", "scales", "doParallel", "tinytex",
  "rmarkdown"
))
```

### Python (>= 3.8)
```bash
pip install requests pandas numpy openpyxl
```

---

## Reproducción

1. Clonar el repositorio.
2. Instalar las dependencias de R y Python indicadas arriba.
3. Ejecutar los notebooks en orden numérico (`01_` → `06_`).

> **Nota:** El notebook `01_api_scraping.ipynb` requiere credenciales propias de la API de Idealista. Los datos ya descargados están en `data/`.

> **Nota:** Los modelos entrenados (`models/*.rds`) no están versionados por su tamaño. Para regenerarlos, ejecutar `05_modelos.Rmd`.

---

## Autores

- **Robert Torres Mingarro** — Limpieza de datos 2018 y ajuste de predicciones con el IPV
- **Jorge Acín Zurita** — Entrenamiento, evaluación y selección de modelos predictivos
- **Mihai Cristian Mihalache Farcas** — Limpieza de datos 2025 y análisis exploratorio
- **Rubén Tormo Piles** — Scraping de datos, cálculo de distancias al metro y feature engineering geoespacial

---

## Licencia

Proyecto académico — Grado en Ciencia de Datos, Universitat Politècnica de València (UPV).
