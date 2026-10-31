# =============================================================================
# 03_controles_externos.R — Punto 3: ampliación con controles externos
# Responsable: Persona 1
#
# Series incorporadas (además de SP500 y WEI, que ya vienen en la base):
#   Trends_Brand     Google Trends: "hertz + avis + enterprise rent a car"
#   Trends_NonBrand  Google Trends: "car rental + rental car"
#   Gas_Precio       FRED GASREGW: precio promedio gasolina regular EE. UU. (USD/galón)
#   ICSA             FRED ICSA: solicitudes iniciales de desempleo (personas)
#
# Regla de alineación (sin información futura): para cada semana t (domingo en
# que inicia la semana) se toma la última observación cuya FECHA DE PUBLICACIÓN
# es <= t. Fecha de publicación = fecha de la observación + rezago:
#   Trends:  0 días (índice de la misma semana; Google lo publica casi en tiempo real)
#   GASREGW: 1 día  (EIA publica el lunes de la observación, en la tarde)
#   ICSA:    5 días (la semana que termina el sábado se publica el jueves siguiente)
#
# Entradas: data/processed/base_amazon.rds
#           google_trends_brand_nonbrand.csv (descarga manual)
#           GASREGW.csv, ICSA.csv (se descargan si faltan)
#           registro_descargas.csv (fechas de consulta)
# Salidas : data/processed/base_semanal.rds y .csv
#           outputs/tablas/03_ficha_controles.csv
#           outputs/tablas/03_trazabilidad_alineacion.csv
# =============================================================================
source("00_paquetes.R")
source("utils.R")

base <- leer_procesado("base_amazon.rds", "02_agregados_amazon.R")
n0 <- nrow(base)

ARCHIVO_TRENDS   <- file.path(RUTAS$externos, "google_trends_brand_nonbrand.csv")
TERMINO_BRAND    <- "hertz"            # palabra que identifica la columna Brand en el CSV
DESCARGAR_FRED_SI_FALTA <- TRUE
FRED_DESDE <- "2023-09-01"             # margen previo para que la 1.a semana tenga dato rezagado
FRED_HASTA <- "2026-08-31"

FRED <- data.frame(
  codigo   = c("GASREGW", "ICSA"),
  variable = c("Gas_Precio", "ICSA"),
  rezago   = c(1, 5),
  stringsAsFactors = FALSE
)

# --- Funciones de lectura -----------------------------------------------------
leer_trends <- function(ruta) {
  lineas <- readLines(ruta, encoding = "UTF-8", warn = FALSE)
  lineas <- sub("^﻿", "", lineas)                       # quita BOM si existe
  i <- grep("^\"?(Week|Semana|Time|Tiempo|Day|Día)\"?,", lineas)[1]
  if (is.na(i)) stop("No se encontró la fila de encabezado en ", ruta)
  df <- read.csv(text = paste(lineas[i:length(lineas)], collapse = "\n"),
                 check.names = FALSE, stringsAsFactors = FALSE)
  if (ncol(df) != 3) stop("El CSV de Trends debe tener 3 columnas (fecha, Brand, Non-Brand).")
  a_numero <- function(x) {
    x <- trimws(as.character(x))
    x[x == "<1"] <- "0.5"                                    # Trends reporta "<1" para valores muy bajos
    as.numeric(x)
  }
  es_brand <- grepl(TERMINO_BRAND, names(df)[2:3], ignore.case = TRUE)
  if (sum(es_brand) != 1) stop("No se pudo identificar la columna Brand con '", TERMINO_BRAND, "'.")
  data.frame(
    fecha           = as.Date(df[[1]], tryFormats = c("%Y-%m-%d", "%m/%d/%Y", "%d/%m/%Y")),
    Trends_Brand    = a_numero(df[[c(2, 3)[es_brand]]]),
    Trends_NonBrand = a_numero(df[[c(2, 3)[!es_brand]]]),
    columna_brand    = names(df)[c(2, 3)[es_brand]],
    columna_nonbrand = names(df)[c(2, 3)[!es_brand]]
  )
}

leer_fred <- function(ruta, codigo) {
  df <- read.csv(ruta, stringsAsFactors = FALSE)
  col <- which(toupper(names(df)) == codigo)
  if (length(col) == 0) col <- 2
  out <- data.frame(fecha = as.Date(df[[1]], tryFormats = c("%Y-%m-%d", "%m/%d/%Y")),
                    valor = suppressWarnings(as.numeric(df[[col]])))  # FRED usa "." para faltantes
  out[!is.na(out$fecha) & !is.na(out$valor), ]
}

# Último dato publicado en o antes de cada semana (as-of join)
alinear_asof <- function(semanas, fecha_obs, rezago_dias, valor) {
  disponible <- fecha_obs + rezago_dias
  o <- order(disponible)
  fecha_obs <- fecha_obs[o]; disponible <- disponible[o]; valor <- valor[o]
  i <- findInterval(as.numeric(semanas), as.numeric(disponible))
  i[i == 0] <- NA
  data.frame(valor = valor[i], fecha_obs = fecha_obs[i], fecha_disponible = disponible[i])
}

# --- 1. Google Trends (descarga manual obligatoria) ---------------------------
if (!file.exists(ARCHIVO_TRENDS)) {
  stop("Falta ", ARCHIVO_TRENDS, ". Descárgalo de Google Trends siguiendo ",
       "fuentes_y_glosario.md (sección Google Trends).", call. = FALSE)
}
trends <- leer_trends(ARCHIVO_TRENDS)
cat("Trends: columna Brand =", trends$columna_brand[1],
    "| Non-Brand =", trends$columna_nonbrand[1], "\n")

al_brand    <- alinear_asof(base$Week, trends$fecha, 0, trends$Trends_Brand)
al_nonbrand <- alinear_asof(base$Week, trends$fecha, 0, trends$Trends_NonBrand)
if (any(al_brand$fecha_obs != base$Week, na.rm = TRUE)) {
  warning("Algunas semanas de Trends no coinciden exactamente con Week; ",
          "se usa la semana de Trends más reciente anterior. Revisar trazabilidad.")
}
base$Trends_Brand    <- al_brand$valor
base$Trends_NonBrand <- al_nonbrand$valor

# --- 2. FRED (descarga automática si falta el archivo) ------------------------
traza <- data.frame(Week = base$Week,
                    Trends_fecha_obs = al_brand$fecha_obs)
for (k in seq_len(nrow(FRED))) {
  cod  <- FRED$codigo[k]
  ruta <- file.path(RUTAS$externos, paste0(cod, ".csv"))
  if (!file.exists(ruta) && DESCARGAR_FRED_SI_FALTA) {
    url <- paste0("https://fred.stlouisfed.org/graph/fredgraph.csv?id=", cod,
                  "&cosd=", FRED_DESDE, "&coed=", FRED_HASTA)
    message("Descargando ", cod, " desde FRED...")
    tryCatch(download.file(url, ruta, mode = "wb", quiet = TRUE),
             error = function(e) stop("No se pudo descargar ", cod,
                                      ". Descárgalo manualmente desde https://fred.stlouisfed.org/series/",
                                      cod, " y guárdalo como ", ruta, call. = FALSE))
  }
  serie <- leer_fred(ruta, cod)
  al <- alinear_asof(base$Week, serie$fecha, FRED$rezago[k], serie$valor)
  base[[FRED$variable[k]]] <- al$valor
  traza[[paste0(FRED$variable[k], "_fecha_obs")]]  <- al$fecha_obs
  traza[[paste0(FRED$variable[k], "_dias_desfase")]] <- as.numeric(base$Week - al$fecha_obs)
}

# --- 3. Controles de calidad del merge ----------------------------------------
NUEVAS <- c("Trends_Brand", "Trends_NonBrand", FRED$variable)
stopifnot(nrow(base) == n0)                                  # la muestra no se reduce
faltan <- base$Week[!stats::complete.cases(base[NUEVAS])]
if (length(faltan) > 0) {
  stop("Semanas sin dato externo tras el merge: ", paste(format(faltan), collapse = ", "),
       ". Amplía el rango de descarga.", call. = FALSE)
}
for (v in FRED$variable) {
  d <- traza[[paste0(v, "_dias_desfase")]]
  if (any(d > 14)) warning(v, ": hay semanas con dato de hace más de 14 días (máx = ", max(d), ").")
}

# --- 4. Ficha de cada serie (trazabilidad exigida en el punto 3) --------------
registro_ruta <- file.path(RUTAS$externos, "registro_descargas.csv")
registro <- read.csv(registro_ruta, stringsAsFactors = FALSE)
if (any(is.na(registro$fecha_consulta) | registro$fecha_consulta == "")) {
  warning("Completa fecha_consulta en ", registro_ruta, " antes de entregar.")
}
fecha_de <- function(serie) registro$fecha_consulta[registro$serie == serie][1]

ficha <- data.frame(
  variable = NUEVAS,
  concepto = c("Interés relativo de búsqueda de marcas de alquiler de autos",
               "Interés relativo de búsqueda genérica de alquiler de autos",
               "Precio minorista promedio de la gasolina regular",
               "Solicitudes iniciales de seguro de desempleo"),
  termino_o_codigo = c(trends$columna_brand[1], trends$columna_nonbrand[1], "GASREGW", "ICSA"),
  fuente = c("Google Trends", "Google Trends",
             "U.S. Energy Information Administration vía FRED (St. Louis Fed)",
             "U.S. Employment and Training Administration vía FRED (St. Louis Fed)"),
  url = c(rep("https://trends.google.com/trends/explore", 2),
          "https://fred.stlouisfed.org/series/GASREGW",
          "https://fred.stlouisfed.org/series/ICSA"),
  cobertura = "Estados Unidos",
  frecuencia_original = c("Semanal (domingo)", "Semanal (domingo)",
                          "Semanal (lunes)", "Semanal (termina sábado), SA"),
  unidad = c("Índice 0-100 relativo a la consulta", "Índice 0-100 relativo a la consulta",
             "USD por galón", "Número de solicitudes"),
  regla_alineacion = c("Misma semana (fecha Trends = Week)", "Misma semana (fecha Trends = Week)",
                       "Último lunes publicado (+1 día) <= Week",
                       "Última semana publicada (+5 días) <= Week"),
  criterio_merge = "As-of join por Week; se conservan las 135 semanas",
  fecha_consulta = c(fecha_de("Trends"), fecha_de("Trends"),
                     fecha_de("GASREGW"), fecha_de("ICSA"))
)

guardar_tabla(ficha, "03_ficha_controles")
guardar_tabla(traza, "03_trazabilidad_alineacion")
saveRDS(base, ruta_proc("base_semanal.rds"))
write.csv(base, ruta_proc("base_semanal.csv"), row.names = FALSE)
cat("OK 03: base ampliada con", length(NUEVAS), "controles externos (", nrow(base), "semanas ).\n")
