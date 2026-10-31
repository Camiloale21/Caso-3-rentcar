# =============================================================================
# 02_agregados_amazon.R — Punto 2: canales agregados de Amazon
# Responsable: Persona 1
#
# Regla del caso: sumar horizontalmente, por semana, las columnas cuyo nombre
# COMIENZA por el prefijo y TERMINA en ".Cost" (costos) o ".Impression"
# (impresiones). Las campañas Google NO entran en los agregados de Amazon.
#
# Entrada : data/processed/base_cruda.rds
# Salidas : data/processed/base_amazon.rds
#           outputs/tablas/02_mapa_columnas.csv
#           outputs/tablas/02_comprobacion_manual.csv
# =============================================================================
source("00_paquetes.R")
source("utils.R")

base <- leer_procesado("base_cruda.rds", "01_carga_auditoria.R")

CANALES <- c(Amazon_DSP = "DSP", Amazon_Search = "Search", Amazon_Sponsored = "Sponsored")
# Número de campañas por canal según el anexo del caso (sirve de control)
CAMPANAS_ESPERADAS <- c(Amazon_DSP = 2, Amazon_Search = 4, Amazon_Sponsored = 4)
# Semanas para la comprobación manual: la primera de la muestra y una de temporada alta
SEMANAS_COMPROBACION <- as.Date(c("2024-01-07", "2025-12-14"))

columnas_de <- function(prefijo, sufijo) {
  n <- names(base)
  n[startsWith(n, prefijo) & endsWith(n, sufijo)]
}

# --- 1. Mapa de columnas por canal y construcción de agregados ----------------
mapa <- data.frame(canal = character(), tipo = character(), columna = character())
for (canal in names(CANALES)) {
  pref <- CANALES[[canal]]
  c_cost <- columnas_de(pref, ".Cost")
  c_impr <- columnas_de(pref, ".Impression")

  if (length(c_cost) != CAMPANAS_ESPERADAS[[canal]] ||
      length(c_impr) != CAMPANAS_ESPERADAS[[canal]]) {
    stop("Número de campañas inesperado para ", canal, ": ",
         length(c_cost), " costos y ", length(c_impr), " impresiones.")
  }
  if (any(startsWith(c(c_cost, c_impr), "Google"))) stop("Se colaron columnas Google en ", canal)

  base[[paste0(canal, "_Cost")]]        <- rowSums(base[, c_cost, drop = FALSE])
  base[[paste0(canal, "_Impressions")]] <- rowSums(base[, c_impr, drop = FALSE])

  mapa <- rbind(mapa,
                data.frame(canal = canal, tipo = "Cost",       columna = c_cost),
                data.frame(canal = canal, tipo = "Impression", columna = c_impr))
}

# Totales Google SOLO para exploración (no entran en los modelos de Amazon)
g_cost <- columnas_de("Google", ".Cost")
g_impr <- columnas_de("Google", ".Impression")
base$Google_Total_Cost        <- rowSums(base[, g_cost, drop = FALSE])
base$Google_Total_Impressions <- rowSums(base[, g_impr, drop = FALSE])
mapa <- rbind(mapa,
              data.frame(canal = "Google (solo exploración)", tipo = "Cost",       columna = g_cost),
              data.frame(canal = "Google (solo exploración)", tipo = "Impression", columna = g_impr))

# Toda columna de campaña debe quedar asignada exactamente a un canal
campanas <- grep("\\.(Cost|Impression)$", names(base), value = TRUE)
campanas <- setdiff(campanas, c(grep("^Amazon_|^Google_Total", campanas, value = TRUE)))
sin_asignar <- setdiff(campanas, mapa$columna)
if (length(sin_asignar) > 0) stop("Campañas sin canal: ", paste(sin_asignar, collapse = ", "))
stopifnot(!any(duplicated(mapa$columna)))

# --- 2. Comprobación manual de las sumas en dos semanas -----------------------
comprobacion <- list()
for (s in seq_along(SEMANAS_COMPROBACION)) {
  fila <- base[base$Week == SEMANAS_COMPROBACION[s], ]
  if (nrow(fila) != 1) stop("La semana ", SEMANAS_COMPROBACION[s], " no está en la base.")
  for (canal in names(CANALES)) {
    for (tipo in c("Cost", "Impression")) {
      cols    <- mapa$columna[mapa$canal == canal & mapa$tipo == tipo]
      valores <- unlist(fila[cols])
      col_ag  <- paste0(canal, if (tipo == "Cost") "_Cost" else "_Impressions")
      comprobacion[[length(comprobacion) + 1]] <- data.frame(
        semana          = format(SEMANAS_COMPROBACION[s]),
        canal           = canal,
        tipo            = tipo,
        operacion       = paste(format(valores, big.mark = ",", scientific = FALSE, trim = TRUE),
                                collapse = " + "),
        suma_manual     = sum(valores),
        agregado_script = fila[[col_ag]],
        diferencia      = sum(valores) - fila[[col_ag]]
      )
    }
  }
}
comprobacion <- do.call(rbind, comprobacion)
stopifnot(all(abs(comprobacion$diferencia) < 1e-6))
print(comprobacion[, c("semana", "canal", "tipo", "suma_manual", "agregado_script", "diferencia")])

guardar_tabla(mapa,         "02_mapa_columnas")
guardar_tabla(comprobacion, "02_comprobacion_manual")
saveRDS(base, ruta_proc("base_amazon.rds"))
cat("OK 02: agregados de Amazon construidos y verificados.\n")
