# Fuentes externas y glosario de variables — Caso 3

Responsable: Persona 1. Este documento cumple la trazabilidad exigida en el punto 3 del caso. La tabla `outputs/tablas/03_ficha_controles.csv` se genera desde `03_controles_externos.R` con la misma información.

## 1. Cómo descargar las series externas

### 1.1 Google Trends (Brand y Non-Brand) — descarga manual

1. Abrir esta consulta (ya trae toda la configuración):
   https://trends.google.com/trends/explore?date=2024-01-07%202026-08-08&geo=US&cat=67&q=hertz%20%2B%20avis%20%2B%20enterprise%20rent%20a%20car,car%20rental%20%2B%20rental%20car
2. Verificar en pantalla:
   - País: **Estados Unidos**
   - Rango: **2024-01-07 a 2026-08-08** (con menos de 5 años de rango, Trends entrega datos **semanales** que inician el domingo, igual que `Week`)
   - Categoría: **Viajes** (código 67)
   - Tipo de búsqueda: **Búsqueda web**
   - Términos: `hertz + avis + enterprise rent a car` (Brand) y `car rental + rental car` (Non-Brand). El signo `+` en Trends significa "o": suma el interés de varias frases.
3. En el gráfico "Interés a lo largo del tiempo", descargar el CSV (ícono de flecha).
4. Guardarlo **sin editar** como `google_trends_brand_nonbrand.csv`.
5. Registrar la fecha de descarga en la columna `fecha_consulta` de `registro_descargas.csv` (formato AAAA-MM-DD).

**Decisiones y su justificación**

- **Brand.** La empresa del caso es anónima, así que no podemos medir búsquedas de su propia marca. Usamos como aproximación el interés combinado en las tres marcas líderes de alquiler en EE. UU. Mide la demanda "con intención de marca" de la categoría. *Limitación:* no es el interés en la marca de la empresa.
- **Non-Brand.** `car rental` y `rental car` son las dos formas genéricas más comunes de buscar el servicio en inglés.
- **Categoría Viajes.** Se usa para quitar el ruido de búsquedas no relacionadas, como "hertz" la unidad de frecuencia.
- **Descarga conjunta.** Ambos términos están en una sola consulta, por lo que comparten la misma escala (el máximo de los dos vale 100). Los índices son **relativos** al período y la configuración de la consulta, **no son volúmenes absolutos**. Una nueva descarga con otro rango cambia los valores.
- Trends reporta `<1` para interés muy bajo; el script lo convierte a 0.5.

### 1.2 FRED — descarga automática

`03_controles_externos.R` descarga `GASREGW.csv` e `ICSA.csv` si no están en ``. Si la descarga falla, se bajan a mano desde la página de cada serie (botón *Download → CSV*) con el mismo nombre de archivo. Hay que registrar la fecha de consulta en `registro_descargas.csv`.

## 2. Ficha de cada serie nueva

| Variable final | Concepto | Término / código | Entidad y URL | Cobertura | Frecuencia original | Unidad | Alineación semanal | Merge |
|---|---|---|---|---|---|---|---|---|
| `Trends_Brand` | Interés de búsqueda de marcas de alquiler | `hertz + avis + enterprise rent a car` (cat. Viajes) | Google Trends, https://trends.google.com | EE. UU. | Semanal (domingo) | Índice 0–100 relativo | Misma semana: la fecha de Trends coincide con `Week` | As-of join por `Week` |
| `Trends_NonBrand` | Interés de búsqueda genérica de alquiler | `car rental + rental car` (cat. Viajes) | Google Trends | EE. UU. | Semanal (domingo) | Índice 0–100 relativo | Igual que Brand | As-of join por `Week` |
| `Gas_Precio` | Precio minorista de la gasolina regular | `GASREGW` | EIA vía FRED, https://fred.stlouisfed.org/series/GASREGW | EE. UU. | Semanal (lunes) | USD/galón | Último lunes publicado (+1 día) en o antes de `Week` | As-of join |
| `ICSA` | Solicitudes iniciales de desempleo | `ICSA` | U.S. ETA vía FRED, https://fred.stlouisfed.org/series/ICSA | EE. UU. | Semanal (termina sábado), desestacionalizada | Número de solicitudes | Última semana publicada (+5 días, jueves) en o antes de `Week` | As-of join |

**Por qué estos controles**

- **Gas_Precio:** el combustible encarece manejar un carro alquilado y también los viajes por carretera en general. Esperamos una relación negativa con la demanda, aunque la gasolina también sube en verano, cuando más se viaja.
- **ICSA:** mide el deterioro del mercado laboral casi en tiempo real. Si sube, cae el gasto en viajes.
- **Trends_Brand / Trends_NonBrand:** aproximan la demanda latente de la categoría. *Advertencia:* son contemporáneas a las ventas y pueden reflejar la misma intención de compra. Por eso las incluimos como controles de demanda, no como causas.

**Fecha de consulta:** ver `registro_descargas.csv`.

## 3. Por qué no hay información futura

`Week` cae siempre en domingo (verificado en `01_carga_auditoria.R`) y la interpretamos como el **inicio** de la semana. Para cada semana solo se usa un dato externo si su **fecha de publicación** es anterior o igual a ese domingo:

- ICSA de la semana que termina el sábado S se publica el jueves S+5. Por eso la semana que empieza el domingo S+1 usa el dato de la semana anterior.
- GASREGW del lunes L se publica ese mismo lunes, así que se usa desde el martes L+1.
- Trends es el índice de la misma semana, que Google publica casi en tiempo real.

`outputs/tablas/03_trazabilidad_alineacion.csv` muestra, para cada semana, qué fecha de cada serie se usó.

## 4. Glosario de variables derivadas

| Variable | Definición | Uso |
|---|---|---|
| `Amazon_DSP_Cost` / `_Impressions` | Suma por semana de las columnas que empiezan por `DSP` y terminan en `.Cost` / `.Impression` (2 campañas) | Regresor / descriptivos |
| `Amazon_Search_Cost` / `_Impressions` | Ídem con prefijo `Search` (4 campañas) | Regresor / descriptivos |
| `Amazon_Sponsored_Cost` / `_Impressions` | Ídem con prefijo `Sponsored` (4 campañas) | Regresor / descriptivos |
| `Google_Total_Cost` / `_Impressions` | Suma de las 4 campañas Google | Solo exploración |
| `ln_Sales`, `ln_Orders` | Logaritmo natural del KPI | Camino A (modelo 3) |
| `D_FinAno` | 1 si la semana se cruza con el período entre Thanksgiving y el 24 de diciembre (sin la semana de Navidad) | Camino B (modelo 4) |
| `D_Navidad` | 1 si la semana se cruza con el período del 25 de diciembre al 1 de enero | Camino B |
| `D_Verano` | 1 si la semana se cruza con el período entre Memorial Day y Labor Day | Camino B |

**Unidades.** El caso no documenta la moneda de `Sales` ni de los costos, así que se reportan como "unidades monetarias (u.m.)". `Orders` trae decimales. En toda la muestra se cumple que `Sales = 25.000 × Orders`.
