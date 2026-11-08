# Reto Fit Familia

App para el reto fit en familia con los informes de la báscula RENPHO:
peso, masa muscular, IMC, masa grasa, % de grasa y puntuación corporal.
Los datos se guardan en **Supabase**.

**Abrir la app:** https://jeffer91.github.io/Reto-fit/

## Configurar Supabase (una sola vez)

1. Crea un proyecto en [supabase.com](https://supabase.com) (el plan gratis alcanza).
2. Abre [`supabase.sql`](supabase.sql), cambia `CAMBIA-ESTE-PIN` por el PIN de la familia,
   y ejecútalo en **SQL Editor → New query → Run**. Crea las tablas, la seguridad y carga los informes que ya había.
3. La URL y la clave publishable del proyecto están en `index.html` (`RETOFIT_CONFIG`).


Acceso directo: cualquiera con el link puede subir informes y marcar pagos. No se permiten duplicados: un informe por persona y mes, y un mismo informe no se guarda dos veces.

## Cómo se usa

1. **Elegir informes**: selecciona uno o varios PDF (o fotos). La app lee los valores sola.
2. Revisa las tarjetas (lo dudoso sale en amarillo) y toca **Guardar todos**.
3. Elige el **mes** arriba: reglamento, **lista de pagos**, tabla de todos los meses y % de avance.
4. En la lista de pagos marca quién ya pagó y usa **Copiar lista para WhatsApp**.

## Reglamento

Cada mes se compara el informe de cada persona con su informe anterior. La app solo muestra
**Mejoró / Se mantuvo / Empeoró** y un **porcentaje**, con el porqué en palabras simples.

Por dentro mira lo que importa para la salud, según la meta del propio informe de cada uno:

| Factor | Peso |
|---|---|
| Grasa corporal (bajar mientras esté por encima de su rango sano) | 35 % |
| Masa muscular (ganar suma, perder siempre resta) | 30 % |
| Puntuación corporal RENPHO | 20 % |
| Grasa visceral | 15 % |

El peso solo no cuenta (bajar de peso perdiendo músculo no es mejorar). Cambios menores a 0,2 kg
no cuentan porque están dentro del error de la báscula.

| Resultado | Regla |
|---|---|
| ★ Mejoró | más de +10 % |
| $1 Se mantuvo | entre −10 % y +10 % |
| $5 Empeoró | menos de −10 % |
| $0 | Puntuación corporal mayor a 75: no paga |

Recomendación: pesarse en ayunas, a la misma hora y sin haber hecho ejercicio.
