# =============================================================================
# 00_paquetes.R — Instala (si faltan) y carga los paquetes del proyecto
# Responsable: Persona 1
# =============================================================================

paquetes <- c(
  "dplyr",      # manipulación de datos
  "tidyr",      # pivot_longer para gráficos
  "ggplot2",    # visualizaciones
  "scales",     # formato de ejes
  "lmtest",     # coeftest, bptest, bgtest, dwtest
  "sandwich",   # errores estándar HAC (Newey-West)
  "car",        # VIF
  "knitr",      # tablas del informe
  "rmarkdown"   # compilación del informe
)

faltantes <- setdiff(paquetes, rownames(installed.packages()))
if (length(faltantes) > 0) {
  install.packages(faltantes, repos = "https://cloud.r-project.org")
}

suppressPackageStartupMessages(
  invisible(lapply(paquetes, library, character.only = TRUE))
)
