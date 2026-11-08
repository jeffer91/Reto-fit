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
4. Guarda el PIN en los teléfonos que van a subir informes.

Cualquiera con el link puede ver los datos; solo quien tiene el PIN puede guardar, borrar o marcar pagos.

## Cómo se usa

1. **Elegir informes**: selecciona uno o varios PDF (o fotos). La app lee los valores sola.
2. Revisa las tarjetas (lo dudoso sale en amarillo) y toca **Guardar todos**.
3. Elige el **mes** arriba: reglamento, **lista de pagos**, tabla de todos los meses y % de avance.
4. En la lista de pagos marca quién ya pagó y usa **Copiar lista para WhatsApp**.

## Reglamento

Cada mes se compara el informe de cada persona con su informe anterior,
usando el promedio del % de cambio de las 6 medidas
(bajar peso, IMC, masa grasa y % grasa es avance; subir músculo y puntuación es avance).

| Resultado | Regla |
|---|---|
| ★ Estrella dorada | Mejora más de 0,5 % |
| $1 | Se mantiene (entre −0,5 % y +0,5 %) |
| $5 | Empeora más de 0,5 % |
| $0 | Puntuación corporal mayor a 75: no paga |
