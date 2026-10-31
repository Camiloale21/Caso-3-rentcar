# Caso 3 — Marketing digital y demanda de alquiler de vehículos

Business Analytics 2026-3 · Pontificia Universidad Javeriana · Prof. Juan Nicolás Velásquez Rey

Proyecto reproducible en R que integra la pauta de Amazon (DSP, Search y Sponsored), las variables macroeconómicas incluidas en la base y cuatro controles externos (Google Trends Brand y Non-Brand, precio de la gasolina y solicitudes de desempleo). Con ellos se estiman y comparan regresiones para explicar `Sales` y `Orders` semanales.

## Integrantes y responsabilidades

| Persona | Responsabilidad | Archivos |
|---|---|---|
| Persona 1 | Puntos 1–4 y 9: auditoría de la base, agregados de Amazon, controles externos, descriptivos, gráficos y cierre ejecutivo | `00_paquetes.R`, `utils.R`, scripts `01` a `05`, `fuentes_y_glosario.md`, `README.md`, `01_datos.Rmd`, `02_exploracion.Rmd`, `05_cierre.Rmd` |
| Persona 2 | Puntos 5–8 e integración: regresiones simples y múltiple, log vs dummies, validación temporal, diagnósticos, `main.R` e informe | `funciones_modelos.R`, `funciones_caminos.R`, scripts `06` a `10`, `main.R`, `informe.Rmd`, `03_modelos.Rmd`, `04_comparacion_diagnostico.Rmd` |

## Estructura

Todos los archivos están en la raíz del repositorio. Las carpetas `data/processed/` (datos intermedios) y `outputs/` (tablas, figuras y modelos) las crea el código al ejecutarse y no se versionan.

| Tipo | Archivos |
|---|---|
| Ejecución | `main.R` (corre todo y compila el informe), `caso3.Rproj` |
| Configuración | `00_paquetes.R` (instala y carga paquetes), `utils.R` (rutas y funciones comunes) |
| Persona 1: puntos 1–4 | `01_carga_auditoria.R`, `02_agregados_amazon.R`, `03_controles_externos.R`, `04_descriptivos.R`, `05_visualizaciones.R` |
| Persona 2: puntos 5–8 | `funciones_modelos.R`, `06_regresiones_simples.R`, `07_regresion_multiple.R`, `funciones_caminos.R`, `08_log_vs_dummies.R`, `09_validacion_temporal.R`, `10_diagnosticos.R` |
| Datos | `Base_datos_caso_3.csv` (original, sin modificar), `google_trends_brand_nonbrand.csv`, `GASREGW.csv`, `ICSA.csv`, `registro_descargas.csv` |
| Informe | `informe.Rmd` (maestro), `01_datos.Rmd`, `02_exploracion.Rmd`, `03_modelos.Rmd`, `04_comparacion_diagnostico.Rmd`, `05_cierre.Rmd`, `informe.pdf` |
| Documentación | `fuentes_y_glosario.md` (trazabilidad de las series externas), `uso_ia.md` (declaración de uso de IA) |

## Requisitos

- R ≥ 4.2 y RStudio.
- Paquetes (se instalan solos al correr `00_paquetes.R`): `dplyr`, `tidyr`, `ggplot2`, `scales`, `lmtest`, `sandwich`, `knitr`, `rmarkdown`.
- Para el PDF: una distribución de LaTeX. La más simple es `install.packages("tinytex"); tinytex::install_tinytex()`.

## Cómo ejecutar

1. Clonar el repositorio y abrir `caso3.Rproj`.
2. Verificar que existe `google_trends_brand_nonbrand.csv` en la raíz. Si no, descargarlo siguiendo `fuentes_y_glosario.md`, sección 1.1. Las series de FRED se descargan solas.
3. En la consola:
   ```r
   source("main.R")
   ```
4. Salidas:
   - Tablas en `outputs/tablas/`.
   - Gráficos en `outputs/figuras/`.
   - Informe en `informe.pdf`.

Para correr solo el análisis sin compilar el PDF, poner `RENDER_INFORME <- FALSE` al inicio de `main.R`. Cada script también se puede correr por separado, en orden, desde la raíz.

## Comprobaciones automáticas

`main.R` se detiene con un error si alguna de estas condiciones falla:

- El archivo original no cambió (se verifica con MD5 en `01`).
- Los agregados de Amazon coinciden con la suma manual en dos semanas, y ninguna campaña Google entra en ellos (`02`).
- El merge conserva las 135 semanas, sin NA, y no usa datos publicados después de cada semana (`03`).
- Todas las tablas y figuras esperadas existen.

## Decisiones principales

- **Brand:** `hertz + avis + enterprise rent a car`. **Non-Brand:** `car rental + rental car`. Ambas en EE. UU., categoría Viajes, descargadas en una sola consulta.
- **Controles adicionales:** `GASREGW` (gasolina) e `ICSA` (desempleo), de FRED.
- **Selección de controles:** se eliminan iterativamente los controles con VIF > 5 (`07_regresion_multiple.R`).
- **Dummies:** Thanksgiving a Navidad, semana de Navidad a Año Nuevo, y Memorial Day a Labor Day. Se definen solo por calendario.
- **Validación:** entrenamiento hasta 2025-08-31 y evaluación desde 2025-09-07. El log se retransforma con smearing de Duan.
- `Sales = 25.000 × Orders` en todas las semanas. Por eso los modelos de Orders replican los de Sales a otra escala.

## Uso de IA

Ver `uso_ia.md`.
