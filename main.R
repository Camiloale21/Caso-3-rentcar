# =============================================================================
# main.R — Ejecuta el proyecto completo del Caso 3 de principio a fin
# Responsable: Persona 2 (integración)
#
# Uso: abrir caso3.Rproj y ejecutar  source("main.R")
#      o desde la terminal, en la raíz:  Rscript main.R
# =============================================================================

if (!file.exists("utils.R")) {
  stop("Ejecuta main.R desde la raíz del proyecto (abre caso3.Rproj).", call. = FALSE)
}

RENDER_INFORME <- TRUE    # FALSE para correr solo el análisis (sin LaTeX)

source("00_paquetes.R")
source("utils.R")

PASOS <- c(
  "01_carga_auditoria.R",       # Persona 1
  "02_agregados_amazon.R",      # Persona 1
  "03_controles_externos.R",    # Persona 1
  "04_descriptivos.R",          # Persona 1
  "05_visualizaciones.R",       # Persona 1
  "06_regresiones_simples.R",   # Persona 2
  "07_regresion_multiple.R",    # Persona 2
  "08_log_vs_dummies.R",        # Persona 2
  "09_validacion_temporal.R",   # Persona 2
  "10_diagnosticos.R"           # Persona 2
)

inicio <- Sys.time()
for (paso in PASOS) {
  message("\n==================== ", paso, " ====================")
  source(paso, local = new.env(), echo = FALSE)   # cada script en su propio entorno
}

# --- Comprobaciones de que el pipeline produjo todo lo necesario --------------
esperados <- c(
  ruta_proc("base_semanal.rds"), ruta_proc("especificacion.rds"), ruta_proc("base_modelos.rds"),
  file.path(RUTAS$tablas, paste0(c(
    "01_resumen_general", "01_auditoria_columnas", "01_registro_ajustes",
    "02_mapa_columnas", "02_comprobacion_manual",
    "03_ficha_controles", "03_trazabilidad_alineacion",
    "04_descriptivos", "04_covarianzas_sales", "04_matriz_correlaciones",
    "06_simples_coeficientes", "06_simples_ajuste",
    "07_pertinencia_controles", "07_multiple_coeficientes", "07_multiple_ajuste",
    "08_caminos_coeficientes", "08_caminos_ajuste_muestra_comun",
    "09_metricas_fuera_muestra",
    "10_pruebas_formales", "10_vif", "10_sensibilidad_influyentes"), ".csv")),
  file.path(RUTAS$figuras, paste0(c(
    "05_serie_Sales", "05_serie_Orders", "05_costos_por_canal",
    "05_dispersion_sales_costos", "04_matriz_correlaciones",
    "09_predicciones_test_Sales", "10_residuos_vs_ajustados", "10_residuos_vs_tiempo",
    "10_acf_residuos"), ".png"))
)
estado <- data.frame(archivo = esperados, existe = file.exists(esperados))
if (!all(estado$existe)) {
  print(estado[!estado$existe, ])
  stop("Faltan salidas del pipeline (ver lista arriba).", call. = FALSE)
}

# Comprobaciones de consistencia
base <- readRDS(ruta_proc("base_semanal.rds"))
stopifnot(
  nrow(base) == 135,                                              # no se perdió muestra
  !anyNA(base[c("Trends_Brand", "Trends_NonBrand", "Gas_Precio", "ICSA")]),
  all(abs(read.csv(file.path(RUTAS$tablas, "02_comprobacion_manual.csv"))$diferencia) < 1e-6)
)
message("\nComprobaciones superadas: ", nrow(estado), " salidas presentes, 135 semanas, sin NA.")

writeLines(capture.output(sessionInfo()), file.path("outputs", "session_info.txt"))

# --- Informe PDF --------------------------------------------------------------
if (RENDER_INFORME) {
  tryCatch(
    rmarkdown::render("informe.Rmd", output_dir = ".",
                      knit_root_dir = getwd(), quiet = TRUE),
    error = function(e) message("No se pudo compilar el PDF: ", conditionMessage(e),
                                "\n¿Está instalado LaTeX? Ejecuta tinytex::install_tinytex().")
  )
}

message("Tiempo total: ", round(difftime(Sys.time(), inicio, units = "mins"), 2), " min")
