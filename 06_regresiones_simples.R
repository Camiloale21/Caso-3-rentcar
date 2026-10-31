# =============================================================================
# 06_regresiones_simples.R — Punto 5: Modelo (1)
#   Sales_t = b0 + b1 * Cost_{j,t} + e_t,  j = DSP, Search, Sponsored
# Responsable: Persona 2
#
# Entrada : data/processed/base_semanal.rds
# Salidas : outputs/tablas/06_simples_coeficientes.csv
#           outputs/tablas/06_simples_ajuste.csv
#           outputs/figuras/06_pendientes_simples.png
#           outputs/modelos/modelos_simples.rds
# =============================================================================
source("00_paquetes.R")
source("utils.R")
source("funciones_modelos.R")

base <- leer_procesado("base_semanal.rds", "03_controles_externos.R")

modelos_simples <- lapply(COSTOS_AMAZON, function(x) ajustar("Sales", x, base))
names(modelos_simples) <- paste0("M1_", sub("_Cost$", "", COSTOS_AMAZON))

coefs  <- do.call(rbind, Map(tabla_coeficientes, modelos_simples, names(modelos_simples)))
ajuste <- do.call(rbind, Map(tabla_ajuste,       modelos_simples, names(modelos_simples)))

# Efecto asociado a 1.000 u.m. adicionales de costo (más legible para negocio)
pend <- coefs[coefs$termino != "(Intercept)", ]
pend$efecto_por_1000     <- pend$estimacion * 1000
pend$efecto_por_1000_inf <- pend$ic95_inf * 1000
pend$efecto_por_1000_sup <- pend$ic95_sup * 1000
print(pend[, c("modelo", "estimacion", "ic95_inf", "ic95_sup", "p_valor", "p_valor_hac")])
print(ajuste[, c("modelo", "n", "r2", "r2_aj", "F", "p_F")])

g <- ggplot(pend, aes(x = modelo, y = efecto_por_1000)) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_pointrange(aes(ymin = efecto_por_1000_inf, ymax = efecto_por_1000_sup)) +
  coord_flip() +
  scale_y_continuous(labels = scales::label_comma()) +
  labs(title = "Regresiones simples: cambio en Sales por 1.000 u.m. de costo",
       subtitle = "Estimación puntual e IC 95 % (MCO clásico)",
       x = NULL, y = "Cambio asociado en Sales (u.m.)") +
  tema_caso()
guardar_figura(g, "06_pendientes_simples")

guardar_tabla(coefs,  "06_simples_coeficientes")
guardar_tabla(ajuste, "06_simples_ajuste")
saveRDS(modelos_simples, file.path(RUTAS$modelos, "modelos_simples.rds"))
cat("OK 06: tres regresiones simples estimadas.\n")
