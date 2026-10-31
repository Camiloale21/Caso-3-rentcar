# =============================================================================
# 05_visualizaciones.R — Punto 4 (gráficos): series de tiempo de los KPI,
#                          costos e impresiones por canal y dispersiones
# Responsable: Persona 1
#
# Entrada : data/processed/base_semanal.rds
# Salidas : outputs/figuras/05_*.png
# =============================================================================
source("00_paquetes.R")
source("utils.R")

base <- leer_procesado("base_semanal.rds", "03_controles_externos.R")
eje_miles <- scales::label_comma()

# --- 1. Una serie de tiempo por KPI -------------------------------------------
for (kpi in KPIS) {
  g <- ggplot(base, aes(Week, .data[[kpi]])) +
    geom_line(color = "#1f4e79") +
    geom_point(size = 0.8, color = "#1f4e79") +
    scale_y_continuous(labels = eje_miles) +
    scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y") +
    labs(title = paste("Evolución semanal de", kpi), x = NULL,
         y = if (kpi == "Sales") "Ventas (u.m.)" else "Órdenes") +
    tema_caso()
  guardar_figura(g, paste0("05_serie_", kpi))
}

# --- 2. Costos e impresiones por canal de Amazon ------------------------------
largo_costos <- tidyr::pivot_longer(base, cols = dplyr::all_of(COSTOS_AMAZON),
                                    names_to = "canal", values_to = "costo")
largo_costos$canal <- sub("_Cost$", "", largo_costos$canal)
g_costos <- ggplot(largo_costos, aes(Week, costo, color = canal)) +
  geom_line() +
  scale_y_continuous(labels = eje_miles) +
  labs(title = "Costo semanal por canal agregado de Amazon", x = NULL,
       y = "Costo (u.m.)", color = NULL) +
  tema_caso()
guardar_figura(g_costos, "05_costos_por_canal")

largo_impr <- tidyr::pivot_longer(base, cols = dplyr::all_of(IMPR_AMAZON),
                                  names_to = "canal", values_to = "impresiones")
largo_impr$canal <- sub("_Impressions$", "", largo_impr$canal)
g_impr <- ggplot(largo_impr, aes(Week, impresiones)) +
  geom_line(color = "#5b7f3a") +
  facet_wrap(~canal, ncol = 1, scales = "free_y") +
  scale_y_continuous(labels = eje_miles) +
  labs(title = "Impresiones semanales por canal de Amazon", x = NULL, y = "Impresiones") +
  tema_caso()
guardar_figura(g_impr, "05_impresiones_por_canal", alto = 6)

# Google: solo para reconocer el alcance del dataset
cols_google <- grep("^Google .*\\.Cost$", names(base), value = TRUE)
largo_google <- tidyr::pivot_longer(base[c("Week", cols_google)], cols = dplyr::all_of(cols_google),
                                    names_to = "campana", values_to = "costo")
largo_google$campana <- sub("\\.Cost$", "", largo_google$campana)
g_google <- ggplot(largo_google, aes(Week, costo, color = campana)) +
  geom_line() +
  scale_y_continuous(labels = eje_miles) +
  labs(title = "Costo semanal de campañas Google (exploración; fuera de los modelos)",
       x = NULL, y = "Costo (u.m.)", color = NULL) +
  tema_caso()
guardar_figura(g_google, "05_costos_google")

# --- 3. Dispersión de Sales contra costos y contra controles ------------------
g_disp_costos <- ggplot(largo_costos, aes(costo, Sales)) +
  geom_point(alpha = 0.6) +
  geom_smooth(method = "lm", se = TRUE, formula = y ~ x, color = "#b2182b") +
  facet_wrap(~canal, scales = "free_x") +
  scale_x_continuous(labels = eje_miles) +
  scale_y_continuous(labels = eje_miles) +
  labs(title = "Sales vs costo semanal por canal de Amazon",
       x = "Costo del canal (u.m.)", y = "Sales (u.m.)") +
  tema_caso()
guardar_figura(g_disp_costos, "05_dispersion_sales_costos", ancho = 10)

largo_ctrl <- tidyr::pivot_longer(base[c("Week", "Sales", CONTROLES_CANDIDATOS)],
                                  cols = dplyr::all_of(CONTROLES_CANDIDATOS),
                                  names_to = "control", values_to = "valor")
g_disp_ctrl <- ggplot(largo_ctrl, aes(valor, Sales)) +
  geom_point(alpha = 0.6) +
  geom_smooth(method = "lm", se = TRUE, formula = y ~ x, color = "#b2182b") +
  facet_wrap(~control, scales = "free_x") +
  scale_y_continuous(labels = eje_miles) +
  labs(title = "Sales vs variables de control", x = NULL, y = "Sales (u.m.)") +
  tema_caso()
guardar_figura(g_disp_ctrl, "05_dispersion_sales_controles", ancho = 10, alto = 6)

# --- 4. Evolución de los controles --------------------------------------------
g_ctrl_t <- ggplot(largo_ctrl, aes(Week, valor)) +
  geom_line(color = "#555555") +
  facet_wrap(~control, scales = "free_y", ncol = 2) +
  labs(title = "Evolución semanal de los controles", x = NULL, y = NULL) +
  tema_caso()
guardar_figura(g_ctrl_t, "05_series_controles", ancho = 9, alto = 6)

cat("OK 05: gráficos guardados en outputs/figuras.\n")
