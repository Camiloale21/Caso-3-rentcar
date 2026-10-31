# =============================================================================
# 01_carga_auditoria.R — Punto 1: reconocimiento de la base
# Responsable: Persona 1
#
# Entrada : Base_datos_caso_3.csv   (NO se modifica; se verifica MD5)
# Salidas : data/processed/base_cruda.rds
#           outputs/tablas/01_resumen_general.csv
#           outputs/tablas/01_auditoria_columnas.csv
#           outputs/tablas/01_registro_ajustes.csv
#           outputs/tablas/01_semanas_atipicas.csv
# =============================================================================
source("00_paquetes.R")
source("utils.R")

archivo_original <- file.path(RUTAS$raw, "Base_datos_caso_3.csv")
if (!file.exists(archivo_original)) stop("Falta ", archivo_original, call. = FALSE)
md5_antes <- unname(tools::md5sum(archivo_original))

# check.names = FALSE conserva los nombres originales (p. ej. "DSP - Evergreen.Cost")
crudo <- read.csv(archivo_original, check.names = FALSE, stringsAsFactors = FALSE)
n_inicial <- nrow(crudo)
ajustes <- data.frame(ajuste = character(), motivo = character(),
                      filas_antes = integer(), filas_despues = integer())

cat("Filas:", nrow(crudo), "| Columnas:", ncol(crudo), "\n")

# --- 1. Fecha semanal ---------------------------------------------------------
crudo$Week <- as.Date(crudo$Week, format = "%Y-%m-%d")
if (anyNA(crudo$Week)) stop("Hay valores de Week que no se pudieron leer como fecha.")
ajustes[nrow(ajustes) + 1, ] <- list("Week: texto -> Date",
                                     "Permitir operaciones de fecha y merges",
                                     n_inicial, nrow(crudo))

if (is.unsorted(crudo$Week)) {
  crudo <- crudo[order(crudo$Week), ]
  ajustes[nrow(ajustes) + 1, ] <- list("Ordenar por Week", "Orden temporal",
                                       nrow(crudo), nrow(crudo))
}

saltos_dias <- as.numeric(diff(crudo$Week))
dia_semana  <- as.POSIXlt(crudo$Week)$wday           # 0 = domingo
cat("Rango:", format(min(crudo$Week)), "a", format(max(crudo$Week)), "\n")
cat("Días entre semanas consecutivas:\n"); print(table(saltos_dias))
cat("Día de la semana de Week (0 = domingo):\n"); print(table(dia_semana))

# --- 2. Duplicados ------------------------------------------------------------
dup_semanas <- sum(duplicated(crudo$Week))
dup_filas   <- sum(duplicated(crudo))
if (dup_filas > 0) {
  antes <- nrow(crudo)
  crudo <- crudo[!duplicated(crudo), ]
  ajustes[nrow(ajustes) + 1, ] <- list("Eliminar filas duplicadas exactas",
                                       "Evitar doble conteo", antes, nrow(crudo))
}
if (sum(duplicated(crudo$Week)) > 0) {
  stop("Hay semanas repetidas con valores distintos: revisar manualmente antes de seguir.")
}

# --- 3. Tipos, faltantes, ceros, negativos y valores extremos -----------------
cols_num  <- names(crudo)[vapply(crudo, is.numeric, logical(1))]
cols_otra <- setdiff(names(crudo), c("Week", cols_num))
if (length(cols_otra) > 0) {
  warning("Columnas no numéricas inesperadas: ", paste(cols_otra, collapse = ", "))
}

resumen_columna <- function(x) {
  z <- (x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)
  c(n_na        = sum(is.na(x)),
    n_ceros     = sum(x == 0, na.rm = TRUE),
    n_negativos = sum(x < 0, na.rm = TRUE),
    minimo      = min(x, na.rm = TRUE),
    mediana     = median(x, na.rm = TRUE),
    maximo      = max(x, na.rm = TRUE),
    n_z_mayor_3 = sum(abs(z) > 3, na.rm = TRUE))   # columnas todo-cero dan z = NaN -> 0
}
aud <- t(vapply(crudo[cols_num], resumen_columna, numeric(7)))
auditoria <- data.frame(
  columna = rownames(aud),
  clase   = vapply(crudo[cols_num], function(x) class(x)[1], character(1)),
  aud, row.names = NULL, check.names = FALSE
)

# Semanas con |z| > 3 en los KPI (se reportan; NO se eliminan)
z_sales <- as.numeric(scale(crudo$Sales))
atipicas <- data.frame(Week = crudo$Week, Sales = crudo$Sales, Orders = crudo$Orders,
                       z_Sales = round(z_sales, 2))[abs(z_sales) > 3, ]

# --- 4. Relación entre Sales y Orders ------------------------------------------
razon <- crudo$Sales / crudo$Orders
# Tolerancia relativa: Orders viene redondeado, así que la razón varía solo
# en el sexto decimal (p. ej. 24999.99999 a 25000.00001)
razon_constante <- diff(range(razon)) / mean(razon) < 1e-6
if (razon_constante) {
  message("ATENCIÓN: Sales = ", format(round(mean(razon)), big.mark = ","),
          " x Orders en TODAS las semanas. Los modelos de Sales y Orders",
          " tendrán los mismos t, p y R2 (solo cambia la escala).")
}

# --- 5. Resumen general y verificación de integridad del original -------------
md5_despues <- unname(tools::md5sum(archivo_original))
stopifnot(identical(md5_antes, md5_despues))

resumen <- data.frame(
  filas = nrow(crudo), columnas = ncol(crudo),
  fecha_min = format(min(crudo$Week)), fecha_max = format(max(crudo$Week)),
  semanas_consecutivas_7d = all(saltos_dias == 7),
  dia_semana_Week = paste(unique(weekdays(crudo$Week)), collapse = "/"),
  semanas_duplicadas = dup_semanas, filas_duplicadas = dup_filas,
  total_na = sum(is.na(crudo)),
  razon_Sales_Orders_constante = razon_constante,
  razon_Sales_Orders = if (razon_constante) round(mean(razon)) else NA_real_,
  md5_original = md5_antes
)
print(t(resumen))

guardar_tabla(resumen,   "01_resumen_general")
guardar_tabla(auditoria, "01_auditoria_columnas")
guardar_tabla(ajustes,   "01_registro_ajustes")
guardar_tabla(atipicas,  "01_semanas_atipicas")
saveRDS(crudo, ruta_proc("base_cruda.rds"))
cat("OK 01: base_cruda.rds guardada (", nrow(crudo), "filas ).\n")
