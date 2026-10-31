# =============================================================================
# 08_log_vs_dummies.R — Punto 7: Camino A (log) y Camino B (dummies)
# Responsable: Persona 2
#
# Entradas: data/processed/base_semanal.rds     (script 03)
#           data/processed/especificacion.rds   (script 07: controles finales)
# Salidas : data/processed/base_modelos.rds
#           outputs/tablas/08_dummies_semanas.csv
#           outputs/tablas/08_caminos_coeficientes.csv
#           outputs/tablas/08_caminos_ajuste_muestra_comun.csv
#           outputs/modelos/modelos_caminos.rds
# =============================================================================
source("00_paquetes.R")
source("utils.R")
source("funciones_modelos.R")
source("funciones_caminos.R")

base <- leer_procesado("base_semanal.rds", "03_controles_externos.R")
esp  <- leer_procesado("especificacion.rds", "07_regresion_multiple.R")
stopifnot(all(dia_semana(base$Week) == 0))         # el supuesto de las dummies

base <- preparar_base_modelos(base)
regresores <- c(esp$costos, esp$controles)
cat("Regresores comunes:", paste(regresores, collapse = ", "), "\n")

# Semanas marcadas por cada dummy (para verificar que sigan el calendario)
marcadas <- base[rowSums(base[DUMMIES]) > 0, c("Week", DUMMIES)]
cat("Semanas por dummy:\n"); print(colSums(base[DUMMIES]))

# --- Estimación sobre la muestra común (las 135 semanas) ----------------------
modelos <- list()
for (k in esp$kpis) {
  m <- ajustar_caminos(k, regresores, base)
  names(m) <- paste0(names(m), "_", k)
  modelos <- c(modelos, m)
}

coefs <- do.call(rbind, Map(tabla_coeficientes, modelos, names(modelos)))
# Lectura en % para los modelos log: 100 * (exp(b) - 1)
coefs$efecto_pct_unidad <- ifelse(es_log(coefs$modelo), 100 * (exp(coefs$estimacion) - 1), NA)
coefs$efecto_pct_por_1000 <- ifelse(es_log(coefs$modelo) & coefs$termino %in% esp$costos,
                                    100 * (exp(1000 * coefs$estimacion) - 1), NA)

# Diagnósticos comparables en la escala ORIGINAL (el R2 de un log no es comparable
# con el de un modelo en niveles porque la variable dependiente es distinta)
ajuste <- do.call(rbind, lapply(names(modelos), function(nm) {
  m <- modelos[[nm]]
  kpi <- if (grepl("_Sales$", nm)) "Sales" else "Orders"
  pred <- predecir_original(m, nm, base)
  cbind(tabla_ajuste(m, nm),
        escala_dependiente = if (es_log(nm)) "log" else "nivel",
        t(metricas(base[[kpi]], pred)),
        smearing = if (es_log(nm)) smearing(m) else NA)
}))
names(ajuste)[names(ajuste) %in% c("MAE", "RMSE")] <- c("MAE_dentro_muestra", "RMSE_dentro_muestra")
print(ajuste[, c("modelo", "n", "r2_aj", "escala_dependiente", "MAE_dentro_muestra", "RMSE_dentro_muestra")])

guardar_tabla(marcadas, "08_dummies_semanas")
guardar_tabla(coefs,    "08_caminos_coeficientes")
guardar_tabla(ajuste,   "08_caminos_ajuste_muestra_comun")
saveRDS(base,    ruta_proc("base_modelos.rds"))
saveRDS(modelos, file.path(RUTAS$modelos, "modelos_caminos.rds"))
cat("OK 08: caminos A y B estimados para", paste(esp$kpis, collapse = " y "), ".\n")
