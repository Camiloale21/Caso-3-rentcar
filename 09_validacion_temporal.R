# =============================================================================
# 09_validacion_temporal.R — Punto 7 (comparación): capacidad predictiva
#   MAE y RMSE en la ESCALA ORIGINAL del KPI, con separación temporal
#   entrenamiento / evaluación.
# Responsable: Persona 2
#
# Corte: entrenamiento hasta 2025-08-31 (incluye la temporada alta de 2024 y un
# verano completo); evaluación desde 2025-09-07 hasta el final (incluye la
# temporada alta de 2025). Así las dummies se estiman con una temporada y se
# evalúan sobre otra que el modelo no vio.
#
# Retransformación del log: exp(pred) subestima la media condicional. Se reporta
# (a) exp(pred) "ingenuo" y (b) exp(pred) * smearing de Duan, calculado SOLO con
# los residuos del entrenamiento.
#
# Entradas: data/processed/base_modelos.rds, data/processed/especificacion.rds
# Salidas : outputs/tablas/09_metricas_fuera_muestra.csv
#           outputs/tablas/09_predicciones_test.csv
#           outputs/figuras/09_predicciones_test_Sales.png
# =============================================================================
source("00_paquetes.R")
source("utils.R")
source("funciones_modelos.R")
source("funciones_caminos.R")

base <- leer_procesado("base_modelos.rds", "08_log_vs_dummies.R")
esp  <- leer_procesado("especificacion.rds", "07_regresion_multiple.R")
regresores <- c(esp$costos, esp$controles)

FECHA_CORTE <- as.Date("2025-08-31")
train <- base[base$Week <= FECHA_CORTE, ]
test  <- base[base$Week >  FECHA_CORTE, ]
cat("Entrenamiento:", nrow(train), "semanas | Evaluación:", nrow(test), "semanas\n")

# Cada dummy debe variar en el entrenamiento; si no, no se puede estimar
sin_variacion <- DUMMIES[vapply(train[DUMMIES], function(x) length(unique(x)) < 2, logical(1))]
dummies_ok <- setdiff(DUMMIES, sin_variacion)
if (length(sin_variacion) > 0) {
  warning("Dummies sin variación en entrenamiento (se excluyen): ",
          paste(sin_variacion, collapse = ", "))
}

resultados <- list()
predicciones <- data.frame(Week = test$Week)
for (k in esp$kpis) {
  modelos <- ajustar_caminos(k, regresores, train, dummies = dummies_ok)
  for (nm in names(modelos)) {
    m <- modelos[[nm]]
    variantes <- if (es_log(nm)) c(TRUE, FALSE) else TRUE
    for (corr in variantes) {
      etiqueta <- paste0(nm, if (es_log(nm)) ifelse(corr, " (smearing)", " (exp ingenuo)") else "")
      pred <- predecir_original(m, nm, test, corregir = corr)
      met  <- metricas(test[[k]], pred)
      resultados[[length(resultados) + 1]] <- data.frame(
        kpi = k, modelo = etiqueta, n_train = nrow(train), n_test = nrow(test),
        MAE = met[["MAE"]], RMSE = met[["RMSE"]],
        MAE_rel_media = met[["MAE"]] / mean(test[[k]]))
      if (corr) predicciones[[paste0(k, "__", nm)]] <- pred
    }
  }
  predicciones[[paste0(k, "__real")]] <- test[[k]]
}
resultados <- do.call(rbind, resultados)
resultados <- resultados[order(resultados$kpi, resultados$RMSE), ]
print(resultados, digits = 4)

# Gráfico: real vs predicho en la ventana de evaluación (Sales)
cols_sales <- grep("^Sales__", names(predicciones), value = TRUE)
largo <- tidyr::pivot_longer(predicciones[c("Week", cols_sales)], cols = dplyr::all_of(cols_sales),
                             names_to = "serie", values_to = "valor")
largo$serie <- sub("^Sales__", "", largo$serie)
g <- ggplot(largo, aes(Week, valor, color = serie, linewidth = serie == "real")) +
  geom_line() +
  scale_linewidth_manual(values = c(`TRUE` = 1.1, `FALSE` = 0.5), guide = "none") +
  scale_y_continuous(labels = scales::label_comma()) +
  labs(title = "Sales en la ventana de evaluación: real vs predicciones",
       subtitle = paste("Modelos estimados con datos hasta", format(FECHA_CORTE),
                        "| log retransformado con smearing"),
       x = NULL, y = "Sales (u.m.)", color = NULL) +
  tema_caso()
guardar_figura(g, "09_predicciones_test_Sales", ancho = 9)

guardar_tabla(resultados,   "09_metricas_fuera_muestra")
guardar_tabla(predicciones, "09_predicciones_test")
cat("OK 09: métricas fuera de muestra calculadas.\n")
