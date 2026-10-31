# =============================================================================
# 07_regresion_multiple.R — Punto 6: Modelo (2)
#   KPI_t = b0 + b1 DSP_t + b2 Search_t + b3 Sponsored_t + g'X_t + e_t
# Responsable: Persona 2
#
# Selección de controles (documentada y reproducible):
#   1. Se parte de los 6 candidatos: SP500, WEI y los 4 controles externos.
#   2. Se revisa su correlación entre sí y con Sales.
#   3. Se estima el modelo con los 3 costos + todos los candidatos y se calcula
#      el VIF. Mientras algún CONTROL tenga VIF > UMBRAL_VIF, se elimina el de
#      mayor VIF (los costos de Amazon nunca se eliminan: son el objeto de estudio).
#   4. El equipo puede sustituir la regla fijando CONTROLES_MANUALES, pero
#      debe justificarlo en el informe.
#
# Entrada : data/processed/base_semanal.rds
# Salidas : data/processed/especificacion.rds   (la usan los scripts 08-10)
#           outputs/tablas/07_*.csv
#           outputs/modelos/modelos_multiples.rds
# =============================================================================
source("00_paquetes.R")
source("utils.R")
source("funciones_modelos.R")

base <- leer_procesado("base_semanal.rds", "03_controles_externos.R")

UMBRAL_VIF <- 5
CONTROLES_MANUALES <- NULL   # p. ej. c("WEI", "Trends_NonBrand", "Gas_Precio") para fijarlos a mano

# --- 1. Dependencia entre candidatos ------------------------------------------
cor_candidatos <- stats::cor(base[CONTROLES_CANDIDATOS])
print(round(cor_candidatos, 2))

# --- 2. Eliminación iterativa por VIF -----------------------------------------
seleccion_vif <- function(datos, respuesta, fijos, candidatos, umbral) {
  actuales <- candidatos
  historial <- list()
  repeat {
    m <- ajustar(respuesta, c(fijos, actuales), datos)
    v <- calcular_vif(m)
    historial[[length(historial) + 1]] <- data.frame(
      iteracion = length(historial) + 1, variable = names(v), vif = unname(v))
    v_ctrl <- v[actuales]
    if (max(v_ctrl) <= umbral || length(actuales) <= 1) break
    actuales <- setdiff(actuales, names(which.max(v_ctrl)))
  }
  list(controles = actuales, historial = do.call(rbind, historial))
}

sel <- seleccion_vif(base, "Sales", COSTOS_AMAZON, CONTROLES_CANDIDATOS, UMBRAL_VIF)
controles_finales <- if (is.null(CONTROLES_MANUALES)) sel$controles else CONTROLES_MANUALES
criterio <- if (is.null(CONTROLES_MANUALES)) {
  paste0("Eliminación iterativa del control con mayor VIF mientras VIF > ", UMBRAL_VIF)
} else {
  "Selección manual del equipo (ver justificación en el informe)"
}
cat("Controles finales:", paste(controles_finales, collapse = ", "), "\n")

# Tabla de pertinencia de cada candidato
m_todos <- ajustar("Sales", c(COSTOS_AMAZON, CONTROLES_CANDIDATOS), base)
ct_todos <- summary(m_todos)$coefficients
vif_ini <- sel$historial[sel$historial$iteracion == 1, ]
pertinencia <- data.frame(
  control         = CONTROLES_CANDIDATOS,
  cor_con_Sales   = stats::cor(base[CONTROLES_CANDIDATOS], base$Sales)[, 1],
  p_valor_modelo_completo = ct_todos[CONTROLES_CANDIDATOS, 4],
  vif_inicial     = vif_ini$vif[match(CONTROLES_CANDIDATOS, vif_ini$variable)],
  incluido        = CONTROLES_CANDIDATOS %in% controles_finales,
  row.names = NULL
)
print(pertinencia, digits = 3)

# --- 3. Modelo (2) para Sales y para Orders -----------------------------------
regresores <- c(COSTOS_AMAZON, controles_finales)
modelos_multiples <- lapply(KPIS, function(k) ajustar(k, regresores, base))
names(modelos_multiples) <- paste0("M2_", KPIS)

coefs  <- do.call(rbind, Map(tabla_coeficientes, modelos_multiples, names(modelos_multiples)))
ajuste <- do.call(rbind, Map(tabla_ajuste,       modelos_multiples, names(modelos_multiples)))
v_final   <- calcular_vif(modelos_multiples$M2_Sales)
vif_final <- data.frame(variable = names(v_final), vif = unname(v_final))
print(ajuste)

# Comprobación: si Sales = c * Orders, los coeficientes de Sales son c veces los de Orders
razon_coef <- coef(modelos_multiples$M2_Sales) / coef(modelos_multiples$M2_Orders)
cat("Razón coeficientes Sales/Orders:", paste(round(razon_coef, 4), collapse = " | "), "\n")

# --- 4. Guardar especificación para los scripts 08, 09 y 10 ------------------
especificacion <- list(
  kpis = KPIS,
  costos = COSTOS_AMAZON,
  controles = controles_finales,
  candidatos = CONTROLES_CANDIDATOS,
  criterio = criterio,
  creado = Sys.time()
)
saveRDS(especificacion, ruta_proc("especificacion.rds"))

guardar_tabla(data.frame(variable = rownames(cor_candidatos), cor_candidatos, check.names = FALSE),
              "07_correlacion_candidatos")
guardar_tabla(sel$historial, "07_historial_vif")
guardar_tabla(pertinencia,   "07_pertinencia_controles")
guardar_tabla(coefs,         "07_multiple_coeficientes")
guardar_tabla(ajuste,        "07_multiple_ajuste")
guardar_tabla(vif_final,     "07_vif_modelo_final")
saveRDS(modelos_multiples, file.path(RUTAS$modelos, "modelos_multiples.rds"))
cat("OK 07: modelos múltiples para Sales y Orders; especificación guardada.\n")
