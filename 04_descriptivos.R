# =============================================================================
# 04_descriptivos.R — Punto 4 (tablas): estadísticas descriptivas,
#                       covarianzas y correlaciones
# Responsable: Persona 1
#
# Entrada : data/processed/base_semanal.rds   (script 03)
# Salidas : outputs/tablas/04_descriptivos.csv
#           outputs/tablas/04_covarianzas_sales.csv
#           outputs/tablas/04_matriz_covarianzas.csv
#           outputs/tablas/04_matriz_correlaciones.csv
#           outputs/tablas/04_semanas_pico.csv
#           outputs/tablas/04_promedios_anuales.csv
#           outputs/figuras/04_matriz_correlaciones.png
# =============================================================================
source("00_paquetes.R")
source("utils.R")

base <- leer_procesado("base_semanal.rds", "03_controles_externos.R")

VARS_DESC <- c(KPIS, COSTOS_AMAZON, IMPR_AMAZON, "SP500", "WEI", CONTROLES_EXTERNOS)
faltan <- setdiff(VARS_DESC, names(base))
if (length(faltan) > 0) stop("Faltan variables en la base: ", paste(faltan, collapse = ", "))

# --- 1. Tabla N, media, DE, mínimo, máximo ------------------------------------
desc <- data.frame(
  variable = VARS_DESC,
  N        = vapply(base[VARS_DESC], function(x) sum(!is.na(x)), numeric(1)),
  media    = vapply(base[VARS_DESC], mean, numeric(1), na.rm = TRUE),
  de       = vapply(base[VARS_DESC], sd,   numeric(1), na.rm = TRUE),
  minimo   = vapply(base[VARS_DESC], min,  numeric(1), na.rm = TRUE),
  maximo   = vapply(base[VARS_DESC], max,  numeric(1), na.rm = TRUE),
  row.names = NULL
)
desc$cv <- desc$de / desc$media      # coeficiente de variación (comparación entre escalas)
print(desc, digits = 4)

# --- 2. Covarianzas de Sales y matriz de correlaciones ------------------------
mat_cov <- stats::cov(base[VARS_DESC])
mat_cor <- stats::cor(base[VARS_DESC])
cov_sales <- data.frame(variable    = colnames(mat_cov),
                        cov_con_Sales = mat_cov["Sales", ],
                        cor_con_Sales = mat_cor["Sales", ],
                        row.names = NULL)
cov_sales <- cov_sales[cov_sales$variable != "Sales", ]
cov_sales <- cov_sales[order(-abs(cov_sales$cor_con_Sales)), ]

cor_largo <- as.data.frame(as.table(mat_cor))
names(cor_largo) <- c("var1", "var2", "r")
g_cor <- ggplot(cor_largo, aes(var1, var2, fill = r)) +
  geom_tile(color = "white") +
  geom_text(aes(label = sprintf("%.2f", r)), size = 2.4) +
  scale_fill_gradient2(low = "#2166ac", mid = "white", high = "#b2182b",
                       midpoint = 0, limits = c(-1, 1)) +
  labs(title = "Matriz de correlaciones (Pearson)", x = NULL, y = NULL, fill = "r") +
  tema_caso() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
guardar_figura(g_cor, "04_matriz_correlaciones", ancho = 9, alto = 8)

# --- 3. Picos de demanda y cambios de nivel -----------------------------------
picos <- base[order(-base$Sales), c("Week", "Sales", "Orders", COSTOS_AMAZON)][1:10, ]
base$anio <- format(base$Week, "%Y")
anuales <- stats::aggregate(base[c(KPIS, COSTOS_AMAZON)], by = list(anio = base$anio), FUN = mean)
anuales$semanas <- as.vector(table(base$anio)[anuales$anio])

guardar_tabla(desc, "04_descriptivos")
guardar_tabla(cov_sales, "04_covarianzas_sales")
guardar_tabla(data.frame(variable = rownames(mat_cov), mat_cov, check.names = FALSE),
              "04_matriz_covarianzas")
guardar_tabla(data.frame(variable = rownames(mat_cor), mat_cor, check.names = FALSE),
              "04_matriz_correlaciones")
guardar_tabla(picos,   "04_semanas_pico")
guardar_tabla(anuales, "04_promedios_anuales")
cat("OK 04: descriptivos, covarianzas y correlaciones.\n")
