# =============================================================================
# funciones_caminos.R — Dummies de calendario y especificaciones de los
#                         caminos A (log) y B (dummies)
# Responsable: Persona 2
#
# Supuesto: Week es el DOMINGO en que inicia la semana (se verificó en 01 que
# todas las fechas son domingo). La semana cubre [Week, Week + 6].
# Las dummies se construyen SOLO con fechas de calendario de EE. UU., nunca a
# partir del valor del KPI.
# =============================================================================

fecha_ymd   <- function(a, m, d) as.Date(sprintf("%04d-%02d-%02d", a, m, d))
dia_semana  <- function(x) as.POSIXlt(x)$wday                         # 0 = domingo

thanksgiving <- function(a) {                                          # 4.º jueves de noviembre
  d <- fecha_ymd(a, 11, 1)
  d + ((4 - dia_semana(d)) %% 7) + 21
}
memorial_day <- function(a) {                                          # último lunes de mayo
  d <- fecha_ymd(a, 5, 31)
  d - ((dia_semana(d) - 1) %% 7)
}
labor_day <- function(a) {                                             # primer lunes de septiembre
  d <- fecha_ymd(a, 9, 1)
  d + ((1 - dia_semana(d)) %% 7)
}

# TRUE si la semana [inicio, inicio + 6] se cruza con el intervalo [desde, hasta]
se_solapa <- function(inicio, desde, hasta) inicio <= hasta & (inicio + 6) >= desde

crear_dummies <- function(semanas) {
  anios <- seq(as.integer(format(min(semanas), "%Y")) - 1,
               as.integer(format(max(semanas), "%Y")))
  fin_ano <- navidad <- verano <- rep(FALSE, length(semanas))
  for (a in anios) {
    fin_ano <- fin_ano | se_solapa(semanas, thanksgiving(a), fecha_ymd(a, 12, 24))
    navidad <- navidad | se_solapa(semanas, fecha_ymd(a, 12, 25), fecha_ymd(a + 1, 1, 1))
    verano  <- verano  | se_solapa(semanas, memorial_day(a), labor_day(a))
  }
  fin_ano <- fin_ano & !navidad          # la semana que contiene el 25-dic cuenta como Navidad
  data.frame(D_FinAno = as.integer(fin_ano),
             D_Navidad = as.integer(navidad),
             D_Verano = as.integer(verano))
}

DUMMIES <- c("D_FinAno", "D_Navidad", "D_Verano")

# Agrega dummies y logaritmos de los KPI a la base
preparar_base_modelos <- function(base) {
  if (any(base$Sales <= 0) || any(base$Orders <= 0)) {
    stop("Hay KPI <= 0: el logaritmo no está definido.", call. = FALSE)
  }
  base <- cbind(base, crear_dummies(base$Week))
  base$ln_Sales  <- log(base$Sales)
  base$ln_Orders <- log(base$Orders)
  base
}

# Las cuatro especificaciones con la MISMA muestra y los MISMOS controles
#   M2_nivel       : Modelo (2)  KPI ~ costos + X
#   M3_log         : Modelo (3)  ln(KPI) ~ costos + X                (Camino A)
#   M4_dummies     : Modelo (4)  KPI ~ costos + X + D                (Camino B)
#   M5_log_dummies : complemento ln(KPI) ~ costos + X + D           (A y B juntos)
ajustar_caminos <- function(kpi, regresores, datos, dummies = DUMMIES) {
  ln_kpi <- paste0("ln_", kpi)
  list(
    M2_nivel       = ajustar(kpi,    regresores,              datos),
    M3_log         = ajustar(ln_kpi, regresores,              datos),
    M4_dummies     = ajustar(kpi,    c(regresores, dummies),  datos),
    M5_log_dummies = ajustar(ln_kpi, c(regresores, dummies),  datos)
  )
}

es_log <- function(nombre_modelo) grepl("log", nombre_modelo)

# Factor de smearing de Duan: corrige el sesgo de exp(E[ln y]) al volver a niveles
smearing <- function(modelo) mean(exp(stats::residuals(modelo)))

# Predicción en la ESCALA ORIGINAL del KPI
predecir_original <- function(modelo, nombre, nuevos, corregir = TRUE) {
  p <- stats::predict(modelo, newdata = nuevos)
  if (!es_log(nombre)) return(p)
  if (corregir) exp(p) * smearing(modelo) else exp(p)
}

metricas <- function(real, pred) {
  c(MAE = mean(abs(real - pred)), RMSE = sqrt(mean((real - pred)^2)))
}
