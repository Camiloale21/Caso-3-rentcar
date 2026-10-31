# Declaración de uso de IA

Esta nota responde a la regla del syllabus: cada entrega debe indicar dónde y cómo se usó IA.

**Herramienta utilizada:** Claude (Anthropic), en una conversación en claude.ai.

## Uso general en el proyecto

- **Generación de código:** todo el código R del repositorio (scripts `00` a `10`, `utils.R`, `funciones_modelos.R`, `funciones_caminos.R` y `main.R`) lo generó la IA a partir del enunciado del caso.
- **Estructura y documentación:** la IA propuso la organización del repositorio, el `README.md`, `fuentes_y_glosario.md` y la plantilla del informe (`informe.Rmd` y sus secciones).
- **Decisiones metodológicas propuestas por la IA y aceptadas por el equipo:**
  - Términos de Google Trends: `hertz + avis + enterprise rent a car` (Brand) y `car rental + rental car` (Non-Brand), en la categoría Viajes, para EE. UU.
  - Controles adicionales de FRED: GASREGW (gasolina) e ICSA (solicitudes de desempleo).
  - Regla de alineación semanal según la fecha de publicación de cada serie.
  - Selección de controles por VIF > 5.
  - Dummies de calendario: Thanksgiving a Navidad, Navidad a Año Nuevo, y Memorial Day a Labor Day.
  - Corte temporal: entrenamiento hasta el 31 de agosto de 2025.
  - Retransformación del logaritmo con smearing de Duan.
- **Hallazgo señalado por la IA:** que `Sales = 25.000 × Orders` en todas las semanas.
- **Lo que NO hizo la IA:** no ejecutó el código ni produjo los resultados numéricos. Las tablas y gráficos se generaron al correr `main.R` en nuestro computador. Las interpretaciones del informe se redactaron o revisaron por el equipo a partir de esos resultados.

## Persona 1 — Datos, fuentes externas y exploración

Responsable de los scripts 00 a 05 y de las secciones 1, 2 y 5 del informe.

Verificaciones realizadas (marcar con [x] las hechas):

- [ ] Ejecuté los scripts 01 a 05 y revisé que terminaran con `OK`.
- [ ] Revisé que la comprobación manual de las sumas de Amazon diera diferencia 0.
- [ ] Descargué los CSV de Google Trends y FRED con la configuración documentada y registré la fecha de consulta.
- [ ] Confirmé que la base ampliada conserva las 135 semanas sin datos faltantes.
- [ ] Revisé que los gráficos y la tabla descriptiva fueran coherentes con los datos.
- [ ] Revisé y ajusté la redacción de las interpretaciones y del cierre ejecutivo.

## Persona 2 — Modelos, comparación y diagnóstico

Responsable de los scripts 06 a 10, `main.R`, el informe maestro y las secciones 3 y 4.

Verificaciones realizadas (marcar con [x] las hechas):

- [ ] Ejecuté `main.R` completo desde cero sin errores.
- [ ] Confirmé que los coeficientes de Sales son 25.000 veces los de Orders.
- [ ] Revisé que las semanas marcadas por las dummies correspondan al calendario de EE. UU.
- [ ] Revisé los controles seleccionados por VIF y estuve de acuerdo con la selección.
- [ ] Elegí el modelo preferido con base en el MAE y RMSE fuera de muestra y en los diagnósticos.
- [ ] Revisé y ajusté la redacción de las interpretaciones de los modelos y diagnósticos.

## Compromiso

Ambas integrantes revisamos el código y los resultados, y estamos en capacidad de explicarlos y defenderlos sin ayuda de la IA, como exige el syllabus.
