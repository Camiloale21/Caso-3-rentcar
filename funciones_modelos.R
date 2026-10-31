# =============================================================================
# funciones_modelos.R — Funciones de modelación compartidas (scripts 06-10)
# Responsable: Persona 2
# =============================================================================

# Las constantes (KPIS, COSTOS_AMAZON, CONTROLES_CANDIDATOS, ...) están en utils.R

# Coeficientes con t, p e IC 95 % clásicos + errores HAC (Newey-West) como robustez
tabla_coeficientes <- function(modelo, nombre, hac = TRUE) {
  s  <- summary(modelo)$coefficients
  ci <- confint(modelo, level = 0.95)
  out <- data.frame(
    modelo     = nombre,
    termino    = rownames(s),
    estimacion = s[, 1],
    error_std  = s[, 2],
    t          = s[, 3],
    p_valor    = s[, 4],
    ic95_inf   = ci[, 1],
    ic95_sup   = ci[, 2],
    row.names  = NULL
  )
  if (hac) {
    V  <- sandwich::NeweyWest(modelo, prewhite = FALSE, adjust = TRUE)
    ct <- lmtest::coeftest(modelo, vcov. = V)
    out$error_hac   <- ct[, 2]
    out$p_valor_hac <- ct[, 4]
  }
  out$signif <- cut(out$p_valor, c(-Inf, 0.01, 0.05, 0.10, Inf),
                    labels = c("***", "**", "*", ""))
  out
}

# Bondad de ajuste y prueba F global
tabla_ajuste <- function(modelo, nombre) {
  s <- summary(modelo)
  f <- s$fstatistic
  data.frame(
    modelo = nombre,
    n      = stats::nobs(modelo),
    k      = length(coef(modelo)) - 1,
    r2     = s$r.squared,
    r2_aj  = s$adj.r.squared,
    F      = unname(f[1]),
    gl1    = unname(f[2]),
    gl2    = unname(f[3]),
    p_F    = unname(stats::pf(f[1], f[2], f[3], lower.tail = FALSE)),
    sigma  = s$sigma,
    AIC    = stats::AIC(modelo)
  )
}

# VIF (factor de inflación de la varianza) de cada regresor de un modelo lineal.
# VIF_j = 1 / (1 - R2_j), donde R2_j sale de regresar el regresor j contra los
# demás regresores. Equivale a car::vif() para regresores numéricos (sin factores).
calcular_vif <- function(modelo) {
  X <- stats::model.matrix(modelo)
  X <- X[, colnames(X) != "(Intercept)", drop = FALSE]
  if (ncol(X) < 2) stop("El VIF necesita al menos 2 regresores.")
  vapply(colnames(X), function(j) {
    r2 <- summary(stats::lm(X[, j] ~ X[, colnames(X) != j, drop = FALSE]))$r.squared
    1 / (1 - r2)
  }, numeric(1))
}

# Ajusta un lm a partir de nombres de columnas (evita escribir fórmulas a mano)
ajustar <- function(respuesta, regresores, datos) {
  stats::lm(stats::reformulate(regresores, response = respuesta), data = datos)
}
