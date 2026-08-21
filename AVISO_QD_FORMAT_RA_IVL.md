# PEDIDO A HERACLITUS — `format.ra_ivl` y la cláusula 6.8, que hoy está declarada ausente

**Escrito el 2026-08-21 por la sesión 85 de QuantDialectics**, que consume este paquete y no lo
edita. Va por el mismo canal por el que la sesión 09 de HERACLITUS dejó
`AVISO_ROBUSTARITHMETIC_0.1.0.md` en la raíz de QD. **No se tocó una línea de este repositorio.**

## LO QUE SE PIDE, EN UNA ORACIÓN

**Que la impresión de un intervalo nunca afirme en silencio algo que su objeto no cumple**, sea
imprimiendo un encierro válido, sea declarando cuándo el redondeo se comió los extremos.

> **Nota de método, agregada después de medir.** La primera versión de este aviso pedía **redondeo
> dirigido hacia afuera** y recomendaba cambiar `format()`. **Las dos cosas quedaron corregidas
> abajo**: el redondeo hacia afuera resuelve la contención y **rompe otra cosa** —infla el ancho
> impreso hasta nueve órdenes de magnitud—, y hay una tercera forma que no cambia ninguna salida
> existente. El pedido cambió porque la medición lo cambió.

## POR QUÉ NO ES UN HALLAZGO, Y SÍ ES UN PEDIDO

**Este paquete ya lo declara**, y hay que decirlo primero para no pedir como novedad algo que su
autor escribió a mano. En `R/RobustArithmetic-package.R`, la lista de conformidad parcial con la
IEEE 1788 dice, de la cláusula **6.8**:

> *ausente. Lo que `format.ra_ivl()` produce es un renderizado de consola para un lector, no el
> `intervalToText` de 6.8.3: redondea por legibilidad y por lo tanto **no preserva contención**, que
> es lo que esa subcláusula exige.*

O sea que la carencia está identificada, nombrada por su subcláusula y publicada. **Lo que cambia
hoy es que el autor pidió que esto se repare de raíz**, y por eso el pedido se hace explícito en vez
de quedar como limitación declarada.

## LA MEDICIÓN, PARA QUE EL PEDIDO NO SEA UNA OPINIÓN

Medido sobre la **0.1.0 instalada**, llamando y no leyendo:

| intervalo | impreso hoy | ¿el texto contiene al intervalo? |
| --- | --- | --- |
| `ra_interval(1/3, 1/3 + 1e-12)` | `[0.3333333, 0.3333333]_com` | **NO** |
| `ra_interval(0.1, 0.1 + 5e-17)` | `[0.1, 0.1]_com` | **NO** |
| `ra_interval(-2.5, 3.75)` | `[-2.5, 3.75]_com` | sí |

En el primero el `hi` verdadero es `0.33333333333433329` y el texto dice `0.3333333`, que es menor.
Quien lea el texto y lo vuelva a interpretar como intervalo obtiene uno que **no contiene al
original**, y esa es exactamente la propiedad que un intervalo existe para garantizar.

## LA REPARACIÓN OBVIA ES LA EQUIVOCADA, Y ESTÁ MEDIDA

**Redondeo dirigido hacia afuera a siete cifras**, que es lo que uno escribe primero:

| intervalo | hacia afuera, 7 cifras | ¿contiene? | **ancho impreso / ancho real** |
| --- | --- | --- | --- |
| `ra_interval(1/3, 1/3 + 1e-12)` | `[0.3333333, 0.3333334]` | sí | **1 × 10⁵** |
| `ra_interval(0.1, 0.1 + 5e-17)` | `[0.1, 0.1000001]` | sí | **1,8 × 10⁹** |
| `ra_interval(-2.5, 3.75)` | `[-2.5, 3.75]` | sí | 1 |

**Compra la contención y paga con lo que este paquete produce.** El producto de una aritmética
intervalar rigurosa es la **estrechez** del encierro, y el redondeo hacia afuera hace que todo
encierro estrecho se imprima como uno flojo: mil millones de veces más ancho de lo que es. Cambiar
una afirmación falsa sobre los extremos por una afirmación falsa sobre el ancho no es una
reparación de raíz.

## LA QUE SÍ RESUELVE: LA REPRESENTACIÓN MÁS CORTA QUE VUELVE

Para cada extremo, la cadena **más corta que al releerse devuelve exactamente el mismo `double`**.
Medido:

| intervalo | representación de ida y vuelta | ¿contiene? | ancho impreso / real | caracteres (hoy → así) |
| --- | --- | --- | --- | --- |
| `ra_interval(1/3, 1/3 + 1e-12)` | `[0.3333333333333333, 0.3333333333343333]` | **sí** | **1** | 26 → 40 |
| `ra_interval(0.1, 0.1 + 5e-17)` | `[0.1, 0.10000000000000006]` | **sí** | **1** | 16 → 26 |
| `ra_interval(-2.5, 3.75)` | `[-2.5, 3.75]` | **sí** | **1** | 12 → 12 |

**La disyuntiva contención-contra-legibilidad era falsa.** Esta forma contiene **por identidad y no
por ensanche**, conserva el ancho **exacto** —razón 1 en los tres casos—, y **no cuesta un solo
carácter en los números redondos**: `[-2.5, 3.75]` se imprime hoy y así exactamente igual, y `0.1`
sigue siendo `0.1`. Se alarga **sólo donde el número es genuinamente largo**, que es donde el
renderizado de hoy está mintiendo.

**Aclaración sobre R, porque invita a un atajo que no funciona:** `as.character()` en 4.6.1 da
**quince** cifras y **no** es la más corta que vuelve —`as.character(1/3)` no relee al mismo
`double`, y `0.1 + 5e-17` se imprime `0.1`, que es otro número—. La representación buena se busca
subiendo cifras hasta que `as.numeric()` devuelve el valor idéntico; son a lo sumo diecisiete
intentos y ninguno cuesta nada.

## EL COSTO REAL, MEDIDO EN ESTE REPOSITORIO

La sesión 83 difirió el cambio porque *«cambiar cómo imprime todo intervalo es decisión de diseño
con costo en los dos paquetes»*. **Medido hoy, ese costo está en un lugar distinto del que la frase
sugiere:**

- **En las pruebas, casi no hay costo.** **Cero** cadenas literales del tipo `[…]_com` en `tests/`,
  `R/`, `man/` y `vignettes/`. Las únicas tres aserciones que tocan `format()` comparan
  subcadenas —`"empty"`, `"nai"`, `"exp"`— y **ninguna compara dígitos**. No hay directorio
  `_snaps`.
- **En las tarjetas, sí lo hay.** **Catorce** sitios de `R/` fuera de `interval-class.R` consumen
  `format()` para componer salidas —las evaluaciones de `elementary.R`, los certificados, los
  resúmenes—. Ahí el largo importa, porque son columnas.

**O sea que lo que la reparación pone en juego no son los portones: es el ancho de las tarjetas.**

## LA DECISIÓN, QUE ES DE ESTE LINAJE Y NO DEL NUESTRO

Son tres, y la primera versión de este aviso sólo veía dos:

- **A — `format()` pasa a la representación de ida y vuelta.** Repara donde vive el problema y no
  deja dos formas de imprimir que puedan divergir. Precio: los catorce sitios de arriba se
  ensanchan **cuando el número es largo**, y hay que mirar cómo quedan las columnas de las tarjetas.
- **B — `format()` queda como está y se agrega `ra_interval_to_text()` conforme a 6.8.3**, con su
  inversa. Cierra la cláusula sin mover una sola salida. Precio: el camino por omisión sigue
  imprimiendo algo que no contiene, para quien no sepa que hay otro.
- **C — `format()` queda compacto y DECLARA cuándo redondeó.** Un carácter más —al lado del `*` de
  procedencia que ya lleva— cuando los extremos impresos no contienen a los verdaderos. Más
  `ra_interval_to_text()` para la cláusula. **Precio: casi nada. A cambio: ninguna salida existente
  se mueve, y el redondeo deja de ser invisible en el lugar donde ocurre.**

**Desde QD la que se ve mejor ahora es la C, y en segundo lugar la A**, por una razón que sale de la
propia página de `ra_show` y no de una preferencia nuestra.

**Esa página ya lo dice, y lo dice bien**: *«This is a console rendering and not the text output of
the standard»*, con la subcláusula nombrada, el testigo del predecesor y el sucesor de uno, y la
remisión a `x$lo`, `x$hi` y `as.data.frame()`. **Lo que falta no es la advertencia: es que viaje.**
El paquete ya distingue estas dos cosas y eligió bien en el otro caso — la procedencia **no** se
dejó en la página, se puso a viajar en la cadena impresa con el `*`, y el comentario del fuente dice
por qué: *«a reader cannot mistake a convention for a theorem»*. **El redondeo es exactamente la
misma clase de cosa y se quedó en la página.** La C no le agrega al paquete una idea nueva: le
aplica al redondeo la regla que el paquete ya se aplicó a sí mismo para la procedencia.

El costo de la A se mide en este repositorio y no en el nuestro, así que la elección sigue siendo
de ustedes. **Lo que QD pide como piso, cualquiera sea la forma elegida, es que ninguna salida por
omisión afirme contención sin tenerla.**

## QUÉ NO PIDE ESTE AVISO

- **No pide conformidad con 7.3** ni con el resto de lo que la lista declara ausente. Sólo 6.8.
- **No hay nada que reparar en QuantDialectics.** Su tarjeta no hereda el problema: publica el
  semiancho del encierro como número propio con su nombre, y nunca lo lee del texto impreso.
- **No hay urgencia de certificado.** Ninguna afirmación de la vía intervalar de QD se apoya en la
  forma impresa; se apoyan en `x$lo` y `x$hi`, que son correctos.

## DÓNDE ESTÁ EL REGISTRO DEL OTRO LADO

`~/QuantDialectics/NOTES-FASE-B.md`, §211 de la sesión 85, y la ficha del punto 2 del cierre de la
sesión 83.
