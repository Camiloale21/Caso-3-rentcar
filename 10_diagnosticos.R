# =============================================================================
# 10_diagnosticos.R — Punto 8: diagnóstico y mejora
# Responsable: Persona 2
#
# Para los modelos relevantes (M2, M3, M4 y M5, muestra completa):
#   - Residuos vs ajustados y residuos vs tiempo
#   - Heterocedasticidad: Breusch-Pagan
#   - Autocorrelación: Durbin-Watson (orden 1) y Breusch-Godfrey (orden 4)
#   - Valores influyentes: distancia de Cook y leverage
#   - Estacionalidad residual: ACF (rezagos 1-60, incluido 52) y residuos por mes
#   - Multicolinealidad: VIF
#   - Mejora / sensibilidad: errores HAC y reestimación sin observaciones influyentes
# Como Sales = 25.000 x Orders, los diagnósticos de Orders son idénticos a los
# de Sales (salvo la escala de los residuos); se reportan ambos en las tablas y
# los gráficos se hacen para Sales.
#
# Entradas: outputs/modelos/modelos_caminos.rds, data/processed/base_modelos.rds
# Salidas : outputs/tablas/10_*.csv, outputs/figuras/10_*.png
# =============================================================================
source("00_paquetes.R")
source("utils.R")
source("funciones_modelos.R")
source("funciones_caminos.R")

base <- leer_procesado("base_modelos.rds", "08_log_vs_dummies.R")
ruta_mod <- file.path(RUTAS$modelos, "modelos_caminos.rds")
if (!file.exists(ruta_mod)) stop("Falta ", ruta_mod, ". Ejecuta 08_log_vs_dummies.R")
modelos <- readRDS(ruta_mod)
n <- nrow(base)

# --- 1. Pruebas formales ------------------------------------------------------
pruebas <- do.call(rbind, lapply(names(modelos), function(nm) {
  m  <- modelos[[nm]]
  bp <- lmtest::bptest(m)
  dw <- lmtest::dwtest(m)
  bg <- lmtest::bgtest(m, order = 4)
  sw <- stats::shapiro.test(stats::residuals(m))
  r  <- stats::residuals(m)
  ac <- stats::acf(r, lag.max = 60, plot = FALSE)$acf[-1]
  data.frame(modelo = nm,
             BP_estadistico = unname(bp$statistic), BP_p = bp$p.value,
             DW = unname(dw$statistic), DW_p = dw$p.value,
             BG4_estadistico = unname(bg$statistic), BG4_p = bg$p.value,
             Shapiro_p = sw$p.value,
             ACF_rezago1 = ac[1], ACF_rezago52 = ac[52],
             banda_95 = 1.96 / sqrt(n))
}))
print(pruebas, digits = 3)

# --- 2. VIF -------------------------------------------------------------------
vifs <- do.call(rbind, lapply(names(modelos), function(nm) {
  v <- car::vif(modelos[[nm]])
  data.frame(modelo = nm, variable = names(v), vif = unname(v))
}))

# --- 3. Observaciones influyentes ---------------------------------------------
influyentes <- do.call(rbind, lapply(names(modelos), function(nm) {
  m  <- modelos[[nm]]
  cd <- stats::cooks.distance(m)
  h  <- stats::hatvalues(m)
  p  <- length(coef(m))
  sel <- which(cd > 4 / n)
  if (length(sel) == 0) return(NULL)
  data.frame(modelo = nm, Week = base$Week[sel], cook = cd[sel], leverage = h[sel],
             leverage_alto = h[sel] > 2 * p / n, row.names = NULL)
}))
if (is.null(influyentes)) {
  influyentes <- data.frame(modelo = character(), Week = as.Date(character()), cook = numeric(),
                            leverage = numeric(), leverage_alto = logical())
}
resumen_infl <- data.frame(modelo = names(modelos),
                           n_cook_mayor_4_n = vapply(names(modelos),
                                                     function(nm) sum(influyentes$modelo == nm),
                                                     numeric(1)),
                           row.names = NULL)
print(resumen_infl)

# --- 4. Gráficos de residuos (Sales) -------------------------------------------
mods_sales <- modelos[grepl("_Sales$", names(modelos))]
resid_df <- do.call(rbind, lapply(names(mods_sales), function(nm) {
  m <- mods_sales[[nm]]
  data.frame(modelo = sub("_Sales$", "", nm), Week = base$Week,
             ajustado = stats::fitted(m), residuo = stats::residuals(m),
             mes = factor(format(base$Week, "%m")))
}))

g_rf <- ggplot(resid_df, aes(ajustado, residuo)) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_point(alpha = 0.6) +
  geom_smooth(method = "loess", formula = y ~ x, se = FALSE, color = "#b2182b") +
  facet_wrap(~modelo, scales = "free") +
  labs(title = "Residuos vs valores ajustados (Sales)",
       subtitle = "Modelos log: residuos y ajustados en escala logarítmica",
       x = "Ajustado", y = "Residuo") +
  tema_caso()
guardar_figura(g_rf, "10_residuos_vs_ajustados", ancho = 9, alto = 6)

g_rt <- ggplot(resid_df, aes(Week, residuo)) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_line(color = "#1f4e79") +
  facet_wrap(~modelo, scales = "free_y", ncol = 1) +
  labs(title = "Residuos en el tiempo (Sales)", x = NULL, y = "Residuo") +
  tema_caso()
guardar_figura(g_rt, "10_residuos_vs_tiempo", ancho = 9, alto = 8)

g_mes <- ggplot(resid_df, aes(mes, residuo)) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_boxplot(outlier.size = 0.8) +
  facet_wrap(~modelo, scales = "free_y") +
  labs(title = "Estacionalidad residual: residuos por mes (Sales)", x = "Mes", y = "Residuo") +
  tema_caso()
guardar_figura(g_mes, "10_residuos_por_mes", ancho = 9, alto = 6)

acf_df <- do.call(rbind, lapply(names(mods_sales), function(nm) {
  a <- stats::acf(stats::residuals(mods_sales[[nm]]), lag.max = 60, plot = FALSE)
  data.frame(modelo = sub("_Sales$", "", nm), rezago = a$lag[-1], acf = a$acf[-1])
}))
g_acf <- ggplot(acf_df, aes(rezago, acf)) +
  geom_hline(yintercept = c(-1, 1) * 1.96 / sqrt(n), linetype = "dashed", color = "#b2182b") +
  geom_segment(aes(xend = rezago, yend = 0)) +
  geom_vline(xintercept = 52, linetype = "dotted") +
  facet_wrap(~modelo) +
  labs(title = "Autocorrelación de los residuos (Sales)",
       subtitle = "Línea punteada: rezago 52 (un año). Bandas: ±1,96/√n",
       x = "Rezago (semanas)", y = "ACF") +
  tema_caso()
guardar_figura(g_acf, "10_acf_residuos", ancho = 9, alto = 6)

# --- 5. Mejora / sensibilidad -------------------------------------------------
# (a) Inferencia robusta: p-valores HAC ya incluidos en tabla_coeficientes.
# (b) Reestimar cada modelo de Sales sin las semanas con Cook > 4/n y comparar
#     los coeficientes de los costos.
esp <- leer_procesado("especificacion.rds", "07_regresion_multiple.R")
sensibilidad <- do.call(rbind, lapply(names(mods_sales), function(nm) {
  m <- mods_sales[[nm]]
  quitar <- stats::cooks.distance(m) > 4 / n
  m2 <- stats::lm(stats::formula(m), data = base[!quitar, ])
  data.frame(modelo = nm, termino = esp$costos,
             coef_completo = coef(m)[esp$costos],
             p_completo = summary(m)$coefficients[esp$costos, 4],
             coef_sin_influyentes = coef(m2)[esp$costos],
             p_sin_influyentes = summary(m2)$coefficients[esp$costos, 4],
             semanas_excluidas = sum(quitar), row.names = NULL)
}))
print(sensibilidad, digits = 3)

guardar_tabla(pruebas,      "10_pruebas_formales")
guardar_tabla(vifs,         "10_vif")
guardar_tabla(influyentes,  "10_influyentes")
guardar_tabla(resumen_infl, "10_resumen_influyentes")
guardar_tabla(sensibilidad, "10_sensibilidad_influyentes")
cat("OK 10: diagnósticos completos.\n")
