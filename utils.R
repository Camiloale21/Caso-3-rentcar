# =============================================================================
# utils.R — Rutas y funciones auxiliares compartidas por todos los scripts
# Responsable: Persona 1
# Regla: los scripts se ejecutan SIEMPRE desde la raíz del proyecto
#        (abrir caso3.Rproj en RStudio). Todos los archivos del repositorio
#        están en la raíz; las carpetas data/processed y outputs las crea el código.
# =============================================================================

if (!file.exists("utils.R")) {
  stop("Ejecuta los scripts desde la raíz del proyecto (abre caso3.Rproj).",
       call. = FALSE)
}

RUTAS <- list(
  raw       = ".",                       # los archivos de datos están en la raíz
  externos  = ".",
  processed = file.path("data", "processed"),
  figuras   = file.path("outputs", "figuras"),
  tablas    = file.path("outputs", "tablas"),
  modelos   = file.path("outputs", "modelos")
)

# Nombres de variables que usan todos los scripts de análisis
KPIS          <- c("Sales", "Orders")
COSTOS_AMAZON <- c("Amazon_DSP_Cost", "Amazon_Search_Cost", "Amazon_Sponsored_Cost")
IMPR_AMAZON   <- c("Amazon_DSP_Impressions", "Amazon_Search_Impressions",
                   "Amazon_Sponsored_Impressions")
CONTROLES_EXTERNOS   <- c("Trends_Brand", "Trends_NonBrand", "Gas_Precio", "ICSA")
CONTROLES_CANDIDATOS <- c("SP500", "WEI", CONTROLES_EXTERNOS)

# Crea las carpetas de salida si no existen
invisible(lapply(RUTAS, dir.create, recursive = TRUE, showWarnings = FALSE))

ruta_proc <- function(nombre) file.path(RUTAS$processed, nombre)

guardar_tabla <- function(df, nombre) {
  write.csv(df, file.path(RUTAS$tablas, paste0(nombre, ".csv")), row.names = FALSE)
  invisible(df)
}

guardar_figura <- function(grafico, nombre, ancho = 8, alto = 4.5) {
  ggplot2::ggsave(file.path(RUTAS$figuras, paste0(nombre, ".png")), grafico,
                  width = ancho, height = alto, dpi = 150, bg = "white")
  invisible(grafico)
}

tema_caso <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(plot.title = ggplot2::element_text(face = "bold"),
                   legend.position = "bottom")
}

# Lee un .rds de data/processed y, si no existe, indica qué script correr antes
leer_procesado <- function(nombre, script_previo) {
  f <- ruta_proc(nombre)
  if (!file.exists(f)) {
    stop("No existe ", f, ". Ejecuta primero ", script_previo, " (o main.R).",
         call. = FALSE)
  }
  readRDS(f)
}
