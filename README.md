# Reto Fit Familia

App para el reto fit en familia con los informes de la báscula RENPHO:
peso, masa muscular, IMC, masa grasa, % de grasa y puntuación corporal.

**Abrir la app:** https://jeffer91.github.io/Reto-fit/

## Cómo se usa

1. Toca **Elegir informes** y selecciona uno o varios PDF (o fotos) del informe.
2. La app lee los valores sola. Revisa cada tarjeta (lo dudoso sale en amarillo) y toca **Guardar todos**.
3. Elige el **mes** arriba para ver el reglamento de ese mes, la tabla de todos los meses y el % de avance.
4. Para que toda la familia lo vea, toca **Copiar datos** y pega el texto en [`datos.json`](datos.json)
   (desde GitHub: abrir el archivo → lápiz ✏️ → pegar → *Commit changes*).

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
