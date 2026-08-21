# RobustArithmetic — bitácora de construcción

Paquete separado nacido de la pausa comisionada de QuantDialectics (sesión 78 diseña, 79
ejecuta). Gobiernan `~/.qd_s78_work/BLOQUE_V_ARITMETICA_INTERVALAR.md`,
`BLOQUE_VI_LECTURA_DE_MAPA.md` y `PAUTAS_EJECUCION_OPUS.md`. Cero commits hasta orden del
autor.

---

## §1. Sesión 79 — fases 0 y 1, con sus dos portones cruzados

### §1.1. Fase 0 — esqueleto, tabla cerrada, sondas portadas

**Esqueleto**: `~/RobustArithmetic` (ext4), `License: GPL (>= 3)` con `LICENSE.md` en
`.Rbuildignore`, Roxygen2 8.0.0 con el set completo de tags en cada exportada, testthat
edición 3, `Imports: stats`, `Suggests: Rmpfr, testthat, knitr, rmarkdown`.

**La tabla de operadores, cerrada por CUATRO criterios y no por uno.** Las pautas pedían
enumerar contra el `stats::D` instalado; eso es condición necesaria y no suficiente. Los
cuatro, todos medidos contra el software instalado (`dev/measure_statsD.R` y
`dev/close_operator_table.R`, con sus salidas al lado):

- **C1** — el `stats::D` instalado lo deriva.
- **C2** — **la tabla es CERRADA bajo diferenciación**: la derivada de un símbolo admitido,
  y la de ésa, hasta punto fijo, se escribe con símbolos admitidos. Es el criterio que una
  tabla armada por gusto falla, y fallarlo no es una molestia sino un agujero: la forma del
  valor medio de la fase 3 se sale de la tabla en el primer paso y no hay qué evaluar.
- **C3** — existe error máximo conocido en ulps para la libm de esta máquina (glibc 2.43) en
  el reporte de Gladman, Innocente, Mather, Ozaki y Zimmermann, edición de febrero de 2026,
  Tabla 3. Sin ese número no hay holgura declarable.
- **C4** — MPFR la provee correctamente redondeada, para que el nivel riguroso y la escalada
  tengan a dónde ir.

**La tabla v1, 16 funciones**: exp log sin cos tan sinh cosh tanh sqrt expm1 log1p log2 log10
asin acos atan. Más los operadores `+ - * / ^ (` y el menos unario. **La clausura del
conjunto es el propio conjunto** — verificado, y re-verificado en cada corrida por
`ra_verify_operator_table()` y por un caminante independiente escrito en el test.

**Las exclusiones, cada una con el criterio que falla y su medición**:

- **La familia gamma** (`gamma`, `lgamma`, `digamma`, `trigamma`, `psigamma`) sale por **C4
  MEDIDO**: el Rmpfr instalado contesta «Math op. 43 not yet implemented» a `trigamma`, y la
  cadena `gamma → digamma → trigamma` la alcanza en la tercera derivada. Nótese que C2 pasa
  formalmente (la derivada de `psigamma` es `psigamma` de orden mayor: el SÍMBOLO cierra),
  pero el orden crece sin techo y ningún conjunto finito de funciones cierra la familia.
- **`pnorm`/`dnorm`** salen por **C3**: R las computa en su propia biblioteca numérica y no
  en la libm, así que la Tabla 3 no dice nada sobre ellas y no hay holgura declarable sobre
  un error que nunca se midió. Puerta nombrada: si alguna vez se mide contra `Rmpfr::pnorm`,
  entran.
- `abs sign asinh acosh atanh floor ceiling round trunc max min %% %/%` salen por **C1**.

**Un hallazgo que corrige una sospecha propia**: creí que `stats::D` no traía la regla
general de la potencia (que `D(x^y, "x")` daba sólo `x^(y-1)*y`). **Es falso**: con exponente
dependiente de x da los dos términos y es correcta (`D(x^x) = x^(x-1)*x + x^x*log(x)`,
verificado contra la derivada verdadera y contra la diferencia central). La medición cerró la
duda; no hay guarda que escribir.

**Las holguras** `slack(f) = ceiling(2*e(f) + 1)`, con las cinco cifras del Bloque V
confirmadas contra el reporte y once más añadidas: exp/log/sin/cos/tan/expm1/log1p/log2/asin/
acos/atan **3 ulps**; sinh/cosh/log10 **5**; tanh **6**; sqrt **2**. La entrada de `sqrt` es
deliberadamente conservadora: su 0,500 es cota SUPERIOR por teorema (IEEE 754-2019 §5.4.1
exige redondeo correcto de la raíz), no inferior como el resto; se le aplica igual la
convención uniforme para que ninguna función lleve regla propia.

**Las dos sondas portables, hechas tests permanentes con sus controles positivos**:
`test-rounding.R` (sonda 2) y `test-mpfr-bridge.R` (sonda 1b). Los CP disparan: la fórmula
ingenua `phi = 2^-53` viola validez en x = 1; quitar el término `eta` rompe en 0;
`as.numeric` subdesborda a 0 donde `toNum` da 2^-1074.

**Portón 0 cruzado**: `R CMD check` natural **Status: OK**.

### §1.2. La lectura de la fase 1, y lo que cambió por leerla

**RZBM 2009, entero.** El Teorema 2.1 da la validez (`cinf ≤ pred(c)`, `succ(c) ≤ csup`) para
`c ∈ F` **finito**. El Teorema 2.2 da algo que la sonda 78 había medido y no sabía que era un
teorema: **la igualdad vale para todo `c` finito fuera de la franja `|c| ∈ [u⁻¹η/2, 2u⁻¹η]`,
que en binary64 son las dos binadas `[2^-1022, 2^-1020]`, y dentro de la franja el resultado
está a un bit.** Ambos teoremas están verificados en Coq.

**Lo verifiqué en esta máquina y da exactamente eso**: de 180 092 puntos, **8 no exactos, y
los ocho en `2^-1022` y `2^-1021` y sus negativos** — todos dentro de la franja, ninguno
fuera. La aserción del test pasó de estadística («99,99 % exactos») a **estructural** («todo
punto no exacto cae en la franja que el teorema excluye»), que es la que puede fallar
informativamente: una proporción puede seguir alta mientras las excepciones se mudan a donde
el teorema las prohíbe.

**Otro punto del papel que licencia el diseño**: la nota a (1.5) dice que el encierro vale
«si `a∘b` se reemplaza por cualquier real y, por ejemplo `y = sin x`, **mientras `c` sea el
redondeo correcto de y**». Ésa es exactamente la condición que la libm NO cumple y la razón
por la que existe la holgura del nivel rápido.

**Neumaier §5.6 (y 5.1.8–5.1.10).** Tres cosas:

1. **El paso 3 del algoritmo de bisección de Neumaier ES la verificación de candidato por
   inflado**: «tratar de verificar la existencia de una solución en una caja angosta `x' ⊇ x`
   por los métodos de §5.5». La sonda 4 de la 78 lo descubrió por su cuenta al fallar 12 de
   27; está en el algoritmo de referencia desde 1990. La reparación no era una ocurrencia:
   era la canónica, y ahora tiene cita.
2. **El Teorema 5.1.8(iii) NO pide `0 ∉ f'(X)` como hipótesis**: pide `x̌ ∈ int(x)` y
   `∅ ≠ H(x̌,x) ⊆ int(x)`, y de ahí DERIVA que A es fuertemente regular. La formulación del
   Bloque V (que añade `0 ∉ f'(X)`) es suficiente y no mínima; en una dimensión son
   operacionalmente equivalentes. Anotado para la fase 4: la hipótesis se implica, no se
   asume.
3. **El paso 5 parte la caja de modo que el minimizador aproximado quede en la parte MAYOR**,
   y la menor va a la pila. El V.5 dice «bisección al punto medio», que es válido; el
   algoritmo de referencia es más fino. Anotado para la fase 4.

**Hansen–Walster §9.2.** Las ecuaciones (9.2.3) y (9.2.4) son la tabla de casos exacta de la
división extendida del paso de Newton, con sus tres ramas (`c = 0`, `d = 0`, `c < 0 < d`).
Implementada tal cual en `.ra_div_pieces()`.

**Rump *Acta Numerica* §§1–4.** El §4 trae **una trampa que toca a la semilla de QD**:
el Teorema 4.2 «no es válido si se reemplaza `R*A - eye(n)` por `eye(n) - R*A`; en ese caso
la multiplicación y la resta deben computarse en modos de redondeo OPUESTOS». La
`ivl_verified_inverse` de QD usa justamente la forma `I - RA` (`id - ax$hi`, `id - ax$lo`) y
la resuelve intercambiando extremos, que es la forma intervalar de la prescripción — pero
cuando esa capa reciba redondeo hacia afuera, ahí está la trampa esperando. Anotado.

### §1.3. El texto del estándar CORRIGE un veredicto del Bloque V

Portón de lectura de V.6 cumplido sobre IEEE Std 1788.1-2017 (cláusulas 4.2, 4.5.1–4.5.4,
5.2–5.7). **Manda la letra, y la letra dice otra cosa que el Bloque V en un punto**:

> **V.6 decía**: «los errores de dominio (log de intervalo que toca ≤ 0, etc.) con `ill` y su
> condición tipada».
>
> **La cláusula 5.3 dice**: `ill` surge **si y sólo si** (a) un constructor no puede
> construir un intervalo decorado válido, o (b) una operación aritmética de la biblioteca
> recibe una entrada mal formada. **Un error de dominio NO es `ill`**: es que `def` falla, y
> la decoración más fuerte que queda es **`trv`**.

**Aplicado**: `log([-1,2])`, `1/[-1,1]`, `x^(-1)` sobre intervalo que contiene 0 — todos
`trv`, ninguno `ill`. `ill` queda para NaI: construcción inválida y su propagación.

Otras tres cosas de la letra que el Bloque V no decía y que ahora están:

- **`newDec` (5.5.1)**: `com` si es no vacío y **acotado**; **`dac` si es no acotado**; `trv`
  si es vacío. Un intervalo no acotado NO puede llevar `com`.
- **Combinaciones prohibidas (5.4)**: `∅` con `def`/`dac`/`com`, y `com` con no acotado.
  `setDec` las **repara** en lugar de rechazarlas o producirlas.
- **`setDec` (5.5.2) es obligatoria** y no estaba en el diseño. Escrita: `ra_set_dec()`. La
  destapó un test que quería construir una combinación prohibida y no tenía por dónde.
- **Regla del mínimo (5.6)**: `dw = min{dv0, dv1, …, dvk}` en el orden
  `com > dac > def > trv > ill`, con `dv0` la decoración local de la operación.
- **Operaciones no aritméticas (5.7.1)**: `intersection` y `convexHull` se decoran `trv`.
- **Cláusula 4.2**: los infinitos son COTAS y nunca miembros, así que `[+∞, +∞]` y `[−∞, −∞]`
  no son intervalos no vacíos. El constructor los rechaza.

**Una divergencia declarada** (el paquete reclama «conformidad parcial, subconjunto
nombrado»): el constructor **levanta** condición tipada donde el estándar dice que el
constructor decorado devuelve NaI. En R, un contrato violado en construcción debe frenar al
llamador y no viajar como valor; la forma valor queda disponible en `ra_nai()`.

**Y una conciliación, no una cesión**: las pautas piden que «la división por intervalo que
contiene 0 por la vía NO extendida DEBE rechazar», y el estándar pide que `div` sea total y
devuelva el casco con `trv`. Se cumplen las dos: `/` y `ra_div()` siguen al estándar (casco +
`trv`, que es la respuesta más ancha con la decoración más débil — grita, no susurra), y
`ra_div(x, y, zero = "error")` levanta `ra_division_straddles_zero`. Ninguna de las dos
miente; el control positivo prueba las dos.

### §1.4. Fase 1 — el núcleo inf-sup

Clase `ra_ivl`: tres vectores paralelos (`lo`, `hi`, `dec`), vectorizada. **Vacío** = par
invertido `(+Inf, -Inf)`, de modo que la vacuidad es `lo > hi` y la intersección es
`(max lo, min hi)` sin análisis de casos. **NaI** = `(NaN, NaN)` con `ill`.

Escrito: constructor con su invariante verificado UNA vez; `ra_empty/ra_entire/ra_nai`;
accesores; `ra_wid/mid/rad/mag/mig`; `Ops.ra_ivl` (`+ - * /` y menos unario, con comparaciones
**rechazadas** porque el orden que sugerirían no es el de los conjuntos); `ra_neg/add/sub/mul/
div`; `ra_div_extended`; `ra_sqr/ra_abs/ra_pown`; `ra_intersect/ra_hull`; `ra_set_dec`. Y
**todo lo que arrastra la clase, JUNTO** (§203.7 de QD): `format`, `print`, `as.data.frame`,
`summary` con su clase y su impresión, `length`, `c`, `[`.

**Dos defectos propios encontrados y reparados en el camino:**

1. **`ra_pown` heredaba el `trv` de la intersección.** El paso de estrechamiento interno usa
   `ra_intersect`, que el estándar decora `trv` por ser operación no aritmética — correcto
   para la operación y equivocado para este resultado, que sí es extensión intervalar de una
   función puntual. Se le calcula la decoración propia.
2. **`.ra_pown_tight` aplicaba UN paso de redondeo a `x$lo^q`.** El `^` de R con exponente
   entero multiplica repetidamente (`R_pow_di`), así que su error crece con el exponente y un
   paso deja de cubrirlo arriba del cubo. **El portón 1 lo cazó**: `pow3` violó contención
   contra MPFR. Reparado por construcción: exponenciación binaria sobre INTERVALOS, donde
   cada intermedio lleva su propio paso y el resultado es encierro sin suposición de
   exactitud ninguna.

**Un hallazgo cuantitativo de esa reparación**: el ensanchamiento de `pown` **crece lineal en
p aunque las operaciones crezcan como log2(p)**. Medido: 1 paso en p=2, 3 en p=3, 3 en p=4,
5 en p=5, 9 en p=8, 15 en p=16. La razón es que el error relativo de cada operación se lleva
a la siguiente y se multiplica por ella, de modo que en ulps **del resultado** la cuenta es
≈ p·u y no ≈ log2(p)·u. Documentado en el operador, y el test asiente `|p| + 1` en vez de la
cota logarítmica que yo había escrito primero y que era falsa.

### §1.5. Portón 1 — el núcleo contra MPFR a 300 bits

`tests/testthat/test-gate-kernel-vs-mpfr.R`. Referente externo: MPFR a 300 bits, que no
comparte con el núcleo ni código, ni convención de redondeo, ni representación.

- **Contención, aserción absoluta**: 10⁵ pares aleatorios por operador (magnitudes de 2^-40 a
  2^40, ambos signos, con casos incómodos inyectados: extremos en cero, intervalos que
  cruzan el cero, intervalos punto). El resultado puntual de alta precisión SIEMPRE adentro.
  Idem para `sqr`, `abs`, `neg`, `pown` con p ∈ {2, 3, 5} sobre 3·10⁴.
- **Estrechez, reportada y no enmascarada** — exceso en pasos (inferior + superior) contra el
  óptimo, que es el par de dobles más ajustado que contiene el rango exacto:

  | operación | n | media | q99 | máx |
  | --- | --- | --- | --- | --- |
  | add | 100 000 | 1,0527 | 2 | 2 |
  | sub | 100 000 | 1,0646 | 2 | 2 |
  | mul | 100 000 | 1,0497 | 2 | 2 |
  | div | 46 098 | 0,9992 | 2 | 2 |

  El portón pedía «≤ 2 ulps del óptimo en el 99 %»: **el máximo es 2, no el percentil 99**.
- **El óptimo mismo queda encerrado**, aserción absoluta aparte: el núcleo nunca es más
  estrecho que el par de dobles más ajustado válido.
- **Control positivo**: reemplazar el paso hacia afuera por uno hacia adentro DEBE romper la
  contención. Dispara (5 000 puntos, violaciones > 0), y el núcleo verdadero no viola sobre
  los mismos datos.

**Portón 1 cruzado.** Suite: **PASS 330 · FAIL 0 · WARN 0 · SKIP 2 · ERROR 0**
(los dos SKIP son ramas inalcanzables con Rmpfr instalado: lo que el paquete hace SIN el
backend). `R CMD check` natural: **Status: OK**.

### §1.6. Estado al cerrar la 79

- **Fases 0 y 1 TERMINADAS, con sus dos portones cruzados.** Pendiente: fases 2, 3, 4 y 5.
- **Cero commits**, en RobustArithmetic y en QD. QD sin tocar: ni `R/`, ni la suite.
- Espejo a Kingston: **NO movido todavía** — se mueve terminado, y no lo está.
- Lo que la fase 2 hereda escrito y medido: la tabla con sus 16 funciones y sus holguras, la
  escalera {106, 212, 424, 848}, el puente `ra_to_double`/`ra_enclose_mpfr` medido, y el
  núcleo entero sobre el que apoyar las elementales.

---

## §2. Sesión 80 — fases 2 y 3, con sus dos portones, y el ancla del criterio C3 corregida

Pre-registro de la fase 2 en `dev/PREREGISTRO_FASE_2.md`, escrito antes de la primera línea de
`R/elementary.R`, con **dos enmiendas fechadas** que se explican solas más abajo. Cero commits.

### §2.1. El paso 0, y la re-auditoría que sí encontró algo

Versiones confirmadas (R 4.6.1, Rmpfr 1.1.2, testthat 3.3.2, roxygen2 8.0.0, ED 0.1.10 sin
`Repository`, gdpar 0.0.0.9001, topologyR 0.3.0); `R/` ASCII puro en QD **y** acá; suite de
arranque **PASS 330 · FAIL 0 · WARN 0 · SKIP 2 · ERROR 0**, la cifra exacta de la 79.
`ra_verify_operator_table()` da `closed = TRUE` con los cuatro criterios vacíos, y su control
positivo dispara (admitir `gamma` a la fuerza hace escapar `digamma, psigamma, trigamma`).

**Y acá la re-auditoría dejó de ser un trámite.** La regla dice re-auditar las **premisas**, no
sólo las cifras. La premisa de la 79 era «las cinco holguras del Bloque V confirmadas contra el
reporte y once más añadidas». El reporte **no estaba en disco**: no estaba en
`Robust Arithmetic/Literatura/`, que tenía 17 documentos y ninguno era éste. Bajado y
depositado ahí (ahora son 18). Verificadas **las 16 cifras contra la Tabla 3, columna GNU libc
2.43, edición de febrero de 2026**: coinciden dígito a dígito, las 16. Los cinco autores son
los citados, Ozaki incluido.

Y la lectura trajo un dato que la bitácora no tenía y que la fase 2 necesitaba: **el §3.1
recorre el espacio ENTERO de binary64 mapeado a `uint64_t`**, y el texto nombra la reducción de
argumento cerca de `2^1024` para seno y coseno como algo que el buscador debe detectar solo.
Sin eso, la holgura de `sin`/`cos` tendría un agujero justo donde la fase 2 la apoya.

### §2.2. Fase 2 — las elementales de dos niveles

`R/elementary.R`. Cinco clases de forma, declaradas y **verificadas contra las propias
funciones** por `ra_verify_monotonicity()`, que lee los signos de las diferencias sucesivas
sobre una malla del dominio y distingue polo de período por la longitud de la corrida más
corta: un polo invierte el signo durante un paso, un semiperíodo durante cientos. Su control
positivo es declarar `cosh` creciente a propósito, y aparece en `disagreeing`.

**La búsqueda de extremos interiores** es lo que la fase pedía de verdad. Los puntos críticos
de `sin`/`cos` y los polos de `tan` se escriben todos como `q*pi + k*(m*pi)`, y la pregunta es
si el intervalo de índices `K = (X - q*pi)/(m*pi)` contiene un entero. `K` se computa con `pi`
**encerrado**, de modo que es SUPERCONJUNTO del verdadero: **puede ver un extremo que no está
—ensancha— y no puede perder uno que sí está**, que es el único modo de falla que rompería la
contención. Un intervalo degenerado se salta la búsqueda por teorema: **ningún doble es un
polo, porque todo polo es irracional**.

**Tres defectos propios, encontrados y reparados:**

1. **La holgura empujaba el extremo fuera del RANGO de la función.** `sqrt([0,4])` daba
   `[-2^-1074, 2]`: cota inferior negativa para una función que nunca es negativa. Válido y
   engañoso. Reparado interseccionando con el rango, con los límites irracionales guardados ya
   redondeados hacia afuera — **el doble más cercano a `pi/2` está por DEBAJO de `pi/2`, así
   que recortar `asin(1)` contra él cortaría el valor mismo**.
2. **La regla local de decoración de la aritmética no sirve para las elementales.**
   `.ra_local_total()` mira sólo la salida, y `atan([-Inf, Inf])` sale acotado desde una
   entrada que no lo es; la cláusula 5.5.1 pide que `com` afirme que la caja de ENTRADA es
   acotada. Regla propia escrita.
3. **`elementary.R` se carga antes que `rounding.R`** (orden alfabético), así que una tabla de
   rangos guardada como vector de nivel superior llamaba a `ra_succ()` inexistente y el paquete
   no cargaba. Es la tercera trampa silenciosa de R después de las dos ya anotadas: **el código
   de nivel superior no puede suponer el orden de lectura de los fuentes.**

### §2.3. El hallazgo de fondo: el criterio C3 estaba anclado a una rutina que R no llama

Lo destapó el **margen** del portón 2, que existe justamente porque un portón que pasa sin
decir por cuánto no distingue una holgura ajustada de una absurda.

**Primero hubo que reparar el instrumento del margen.** La primera versión medía el error en
binary64 y salía cuantizado en enteros — 1, 2 —, o sea **más grueso que todas las cifras que
tenía que resolver**, que van de 0,500 a 2,21. Es la regla del censo medido con instrumento más
angosto que su objeto, en su forma opuesta. Se mide en MPFR y ahí resolvió fracciones.

Con el instrumento reparado, **seis funciones dieron error observado por encima del publicado**
(`exp` 1,279 contra 0,511; `cos` 1,184 contra 0,516; `sin` 0,857 contra 0,516; `expm1`, `tan`,
`atan`). Que 20 000 puntos al azar le ganen a una búsqueda dirigida sobre 2^64 entradas es
**implausible**, y esa implausibilidad obligó a investigar en vez de anotar.

**Aislado fuera de R.** Un programa en C con `gcc -O2` que lee el argumento de `argv` — para que
no haya plegado de constantes — llama a `sin(0x1.b981319337b63p-26)` y obtiene
`0x1.b981319337b62p-26`, el correctamente redondeado (verificado en MPFR **y** por serie de
Taylor a 500 bits, que coinciden a 4e-34 ulp). **R devuelve `...b63`**, un ulp arriba. Es decir:
**R y la libm escalar de glibc 2.43 no dan lo mismo, y el que se aparta del correctamente
redondeado es R.**

**Mi primer diagnóstico fue FALSO y queda escrito.** Dije «vector de largo ≥ 2 va a `libmvec`».
Con `R_ENABLE_JIT=0` **todos** los caminos dan `...b63`, incluido el de largo 1; con el JIT en
su valor por defecto, el único camino que da `...b62` es una llamada a `sin` sobre un vector de
largo 1 **dentro de código compilado**, que es un atajo escalar del compilador de byte-code. No
es cuestión de largo de vector: es **ruta de evaluación**, y depende de si el código está
compilado. Y el atajo **no se alcanza** ni desde `vapply` ni desde `do.call` — medido, después
de haber escrito una «reparación» con `vapply` que no reparaba nada y que se revirtió.

**Qué se hizo y qué NO se hizo:**

- **No** se agrandó ninguna holgura. Las 16 quedan como las declaró la 79.
- **No** se escribió código con la forma que dispara el atajo del compilador: sería depender de
  un interno no documentado, la clase de dependencia que deja de valer sin avisar.
- **Sí** se corrigió el ANCLA declarada. C3 decía «existe error máximo conocido en ulps para la
  libm de esta máquina»; ahora dice que esa cifra es ancla para una **rutina** y no certificado
  para la **ruta** que R usa, y que la ruta se **mide**. `ra_measure_library_error()` es esa
  medición, exportada, y el portón asiente que la holgura declarada la cubre.
- **Sí** quedó test permanente de que la ruta en uso NO es la correctamente redondeada, escrito
  contra el valor de MPFR y no contra ningún interno de R.

Es la regla de apuntar el instrumento a su propio producto: el paquete venía comparándose
contra el reporte y **nunca contra su propia ruta de evaluación**.

### §2.4. La enmienda §4-bis: la frontera periódica la fija el formato, no la reducción

Escrita **antes** de correr nada, al derivar la aritmética para escribir la pieza. El
pre-registro decía que la frontera de resolución de `sin` sobre cajas grandes la pone la
precisión de la reducción de argumento. **Es falso.** `K = X/(2*pi) - q/m` tiene dos fuentes de
ancho: el ancho de `X` dividido por `2*pi`, y el redondeo de la división, del orden de
`(a*2^-52)/(2*pi)`. Pero `a*2^-52` es exactamente un ulp de `a`, y **ningún intervalo no
degenerado es más angosto que un ulp**. La segunda fuente nunca supera a la primera por más de
un factor chico: **manda la granularidad de binary64.** Por encima de `2^52 * 2*pi ~ 2^54,65`,
dos dobles vecinos están a más de un período uno de otro y `[-1,1]` no es una pérdida: es la
respuesta exacta y estrecha.

Predicción falsable pre-registrada y **cumplida**: la frontera medida para ancho relativo `r`
cae en `ceiling(log2(2*pi/r))` con tolerancia de un exponente, y **el nivel riguroso no la
corre** (diferencia en `{0,1}`). Medido con `r = 2^-20`: predicho 23, rápido 23, riguroso 23.
Si el riguroso la hubiera corrido mucho, la derivación sería falsa; si el rápido cayera muy por
debajo, la reducción rápida estaría peor de lo que la derivación admite. **El criterio puede
fallar por los dos lados.**

### §2.5. La escalada, con su abstención

`ra_elem_escalate(fun, x, decide, ladder)` sube {106, 212, 424, 848} hasta que el criterio del
llamador se cumple, y en el tope devuelve la palabra **«no verdict at this budget (848 bits)»**
con la cifra adentro. El criterio es del llamador y **nunca se afloja acá**. Objeto
`ra_escalation` con todo lo que arrastra una clase, JUNTO: `format`, `print`, `as.data.frame`,
`summary` con su clase y su impresión.

### §2.6. Fase 3 — expresiones, y la dependencia que no se tapa

`R/expression.R`. Extensión natural sobre el árbol; símbolo fuera de la tabla cerrada →
`ra_symbol_not_in_table` **con la razón por la que está excluido**; variable sin valor →
`ra_unbound_variable`, nunca un `NA` silencioso. Exponente entero constante por `ra_pown`
(estrecho, y aguanta base que cruza el cero); cualquier otro por `exp(y*log(x))`, que necesita
base positiva y lo dice **por decoración**, no por error.

**Tres rutas, y se INTERSECAN en vez de elegir.** Natural; forma del valor medio
`f(c) + f'(X)(X-c)` con `f'` de `stats::D`; y monotonía cuando `0` no está en `f'(X)`. Las tres
son teoremas, la intersección de encierros válidos es válida, y **no hay ninguna decisión que
auditar**: una regla que eligiera «la más angosta» estaría decidiendo por el llamador. Cuáles
contribuyeron viaja en el atributo `ra_routes` y no se infiere del ancho.

Control positivo del diseño, cumplido: **`x - x` sobre `[-1,1]` da `[-2,2]`**. No se implementa
la identidad simbólica, y el test fija esa elección: ser exacto en las expresiones que uno
reconoce y no en las demás es peor que sobreestimar parejo.

**Nota de método, dicha sin adorno**: en la fase 2 los controles positivos se escribieron antes
que la pieza, como manda la regla. En la fase 3 el control nombrado por el diseño (V.7, `x-x`)
estaba pre-registrado, pero **la batería del portón 3 se escribió después de la pieza**. La
sustancia no se resiente —la batería sale de la suite de QD, el muestreo es externo y las dos
negativas también— pero el orden no fue el que la regla pide, y queda anotado.

### §2.7. Portón 2 — las elementales contra MPFR a 300 bits, 10^6 puntos por función

**Criterio A, contención, absoluto: CERO salidas del enclosure en las dieciséis funciones**,
sobre 10^6 puntos por función repartidos por franjas de exponente dentro del dominio, con los
casos incómodos inyectados por nombre (bordes del dominio, cero, potencias de dos, múltiplos de
`pi/2`).

**Criterio C, el margen, reportado y no enmascarado.** Error observado de la ruta de evaluación
en uso, en ulps, contra la cifra publicada y contra la holgura declarada:

| función | n | e_obs | e_publicado | holgura | usado |
| --- | --- | --- | --- | --- | --- |
| exp | 1 000 019 | 1,4777 | 0,511 | 3 | 0,493 |
| log | 1 000 015 | 0,5125 | 0,520 | 3 | 0,171 |
| sin | 1 000 019 | 0,8659 | 0,516 | 3 | 0,289 |
| cos | 1 000 019 | 1,4793 | 0,516 | 3 | 0,493 |
| tan | 1 000 019 | 0,6665 | 0,619 | 3 | 0,222 |
| sinh | 1 000 019 | 1,6791 | 1,930 | 5 | 0,336 |
| cosh | 1 000 019 | 1,4530 | 1,930 | 5 | 0,291 |
| tanh | 1 000 019 | 2,1026 | 2,210 | 6 | 0,350 |
| sqrt | 1 000 017 | 0,5000 | 0,500 | 2 | 0,250 |
| expm1 | 1 000 019 | 0,9997 | 0,913 | 3 | 0,333 |
| log1p | 949 851 | 0,7707 | 0,899 | 3 | 0,257 |
| log2 | 1 000 015 | 0,5355 | 0,548 | 3 | 0,179 |
| log10 | 1 000 015 | 1,5349 | 1,620 | 5 | 0,307 |
| asin | 1 000 015 | 0,5116 | 0,516 | 3 | 0,171 |
| acos | 1 000 015 | 0,5177 | 0,523 | 3 | 0,173 |
| atan | 1 000 019 | 0,6667 | 0,523 | 3 | 0,222 |

**Ninguna holgura queda declarada ajustada**: el máximo del cociente `e_obs/holgura` es **0,493**
(`exp` y `cos`), y el umbral pre-registrado era 0,80. **Seis funciones superan la cifra publicada
para la rutina escalar** —`exp`, `sin`, `cos`, `tan`, `expm1`, `atan`—, que es el hallazgo del
§2.3 y **no** un fallo: la lectura 2 del pre-registro lo dice antes de haberlo visto.

**Y una confirmación que sólo el barrido grande podía dar**: las cifras **crecieron con `n`**.
`exp` pasó de 1,279 con 2·10^4 puntos a 1,478 con 10^6; `cos` de 1,184 a 1,479. Es exactamente
el comportamiento de una cota inferior hallada por búsqueda, y es la razón por la que el
pre-registro prohíbe leerla como techo.

### §2.8. Portón 3 — las expresiones contra su propio rango, muestreado denso

**24 expresiones** —las que la suite de QD parsea de verdad, más las tres formas normales con
`b = -1`, más nueve composiciones que ejercitan la capa elemental—, **400 cajas por expresión**
con anchos de `2^-30` a `2^1,5`, y **2 002 puntos por caja**: **19,2 millones de evaluaciones,
cero salidas del enclosure**. Las tres rutas contribuyen en 23 de las 24 (la constante `a` no
tiene derivada que excluya el cero, con razón). Las dos expresiones que la tabla cerrada RECHAZA
—`r * besselJ(Z, 1) + b` y `noexiste(x)`, las dos leídas de la misma suite— son parte del portón.

Segunda aserción del portón, contra la vacuidad: una caja de ancho `2^-20` DEBE dar un enclosure
de ancho menor que `10^-3` en todas las expresiones. Sin ella, contención sobre un enclosure que
se hubiera ensanchado a la recta entera sería trivialmente cierta.

### §2.9. Estado al cerrar la 80

- **Fases 0, 1, 2 y 3 TERMINADAS, con sus cuatro portones cruzados.** Pendientes: **4**
  (Hansen-Sengupta, paving y certificados) y **5** (el enchufe en QD).
- **Suite del paquete: PASS 694 / FAIL 0 / WARN 0 / SKIP 2 / ERROR 0.** Desde 330 en la 79:
  **364 aserciones nuevas**, y ninguna vieja perdida. Los dos SKIP son los mismos de siempre:
  las ramas que el paquete toma SIN el backend, inalcanzables con Rmpfr instalado.
  *Nota de honestidad sobre el conteo*: esa corrida usó `RA_GATE2_N=20000` para no repetir el
  barrido de 10^6, que corrió aparte y cuyo log está guardado. **El conteo de aserciones no
  depende de `N`** —el portón asienta una vez por función, sea cual sea el tamaño del barrido—,
  así que la cifra es la misma; lo que cambia es el tiempo.
- **`R CMD check` natural: Status OK**, sin ninguna variable de entorno que enmascare nada. Los
  portones llevan `skip_on_cran()`, que es por diseño: son barridos de decenas de millones de
  evaluaciones y no tienen lugar en un `check`.
- **Cero commits**, en RobustArithmetic y en QD. QD sin tocar: ni `R/`, ni la suite.
- Espejo a Kingston: **NO movido todavía** — se mueve terminado, y no lo está.
- **La documentación pasa a APA 7** por instrucción del autor dada en esta sesión. Lista canónica
  en `dev/REFERENCIAS_APA7.md`, guión mecánico en `dev/apply_apa7.R`, **aplicada a
  `R/elementary.R` y `R/expression.R`**; los seis archivos de la 79 quedan para la 81 y son
  mecánicos. Dos pedidos suyos más quedan aplazados por él hasta que la vía esté terminada: la
  revisión de la afirmación de conformidad del `Description:`, y la reescritura de la frase sobre
  el modo de redondeo, que él leyó —con razón, porque está mal escrita— como si hablara de sus
  otras librerías. **No habla de sus librerías: el modo de redondeo del FPU es estado por hilo
  del procesador y afecta a TODO el código que corra después en ese hilo, en todo el ecosistema
  de R.**
- Lo que la fase 4 hereda escrito y medido: `ra_elem()` con sus cinco clases de forma y su
  búsqueda de extremos, `ra_elem_escalate()` con la clase `ra_escalation` y su abstención,
  `ra_eval_natural()` y `ra_enclose_expr()` con las tres rutas y el atributo `ra_routes`, y
  `ra_measure_library_error()` para volver a medir el ancla cuando la máquina cambie.

---

## §3. Sesión 81 — las salvaguardas S1-S5, la fase 4 con su portón cruzado, y APA 7 completado

Sesión de ejecución (Fable, esfuerzo Max), con el autor presente al arranque. **El fallo de
C-54 llegó en el mensaje de apertura: opción (c)** — rápido adentro del paving, riguroso
obligatorio en todo veredicto que se imprime — y quedó registrado con su letra en
`CONSULTAS_PENDIENTES.md` de QD. Cero commits; espejo no movido; QD intacto.

### §3.1. El paso 0

Versiones confirmadas (R 4.6.1, Rmpfr 1.1.2, testthat 3.3.2, roxygen2 8.0.0); `R/` ASCII puro
en QD y acá; suite de arranque **PASS 694 · FAIL 0 · WARN 0 · SKIP 2 · ERROR 0** (con
`RA_GATE2_N=20000`, la convención de la 80 — la primera corrida se lanzó sin la variable, iba
a repetir el barrido de 10^6 y se cortó y relanzó). Premisas re-auditadas y no sólo cifras:
`ra_verify_operator_table()` sigue dando `closed = TRUE`, `ra_verify_monotonicity()` sigue
dando `agrees` vacío de desacuerdos, y **el test de que la ruta de R no es la correctamente
redondeada sigue disparando** (R da `...b63` donde el correctamente redondeado es `...b62`).

### §3.2. APA 7 terminado — los seis archivos de la 79 más el archivo de paquete

`dev/apply_apa7.R` extendido con los siete archivos (el mapa de `REFERENCIAS_APA7.md` ganó la
fila de `RobustArithmetic-package.R`, que no estaba); **26 bloques reescritos** y **19
localizadores movidos a la prosa** por guión anclado a la estructura
(`dev/move_locators.R`: rounding 3, interval-class 7, arithmetic 5, operator-table 3,
conditions 1). `devtools::document()` limpio.

**Defecto propio en el camino, y su reparación**: el primer guión de entradas reformateó las
ocho de la 80 y **pisó** `dev/apa_entries.rds`. Se restauraron **verbatim** con
`dev/restore_apa_entries.R`, que verifica cada entrada contra los bloques ya aplicados en
`R/elementary.R`/`R/expression.R` (la fuente de verdad) antes de guardar, y agrega las siete
nuevas con el convenio de las ocho (envoltura llana, descriptores editoriales en inglés — el
.md canónico los tiene en castellano y la correspondencia queda dicha en el propio guión).

### §3.3. Las salvaguardas S1-S5, primera obra, controles antes que las piezas

`tests/testthat/test-safeguards.R` se escribió ENTERO antes de `R/safeguards.R`. Las piezas:

- **S1 — 19 centinelas en `R/sysdata.rda`** (`dev/gen_sentinels.R`): las 16 entradas de peor
  caso de la Tabla 4 del reporte (columna GNU libc 2.43, hexadecimal exacto) más **tres puntos
  de discrepancia de ruta**: el de `sin` de la 80 (`0x1.b981319337b63p-26`) y los de `exp` y
  `cos`, que la 80 no dejó como constantes y el guión **re-encontró** con búsqueda sembrada
  (semilla 81): `exp` en `-0x1.fb2a34e298908p-27` (1,44 ulp observado) y `cos` en
  `0x1.d30eb05187365p-13` (1,40 ulp). Cada punto lleva su par de dobles encuadrantes y el
  correctamente redondeado (`cr`), computados a 500 bits y verificados a 800 (y por serie de
  Taylor el de `sin`). En `.onLoad`, `ra_check_sentinels()` evalúa la ruta en uso y cuenta los
  pasos de ensanchamiento necesarios contra la holgura; **un centinela que la exceda degrada
  el nivel rápido para la sesión**.
- **Defecto propio del diseño del generador, cazado por su primer control**: la aserción
  pedía par encuadrante DEGENERADO en el punto de `sin`. Es conceptualmente errónea: el valor
  verdadero es irracional y siempre cae entre dos dobles; lo que la 80 midió es que el
  **redondeado a nearest** difiere del que la ruta devuelve. Corregido: se guarda `cr` y la
  aserción viva es `sin(x) != cr`.
- **S2** — con backend presente, el primer uso rápido de la sesión corre
  `ra_measure_library_error(n = 400)`, cachea, y aplica la misma degradación si el observado
  excede la holgura. El vigía de recursión es poner la bandera ANTES de medir.
- **La degradación habla, nunca calla**: con backend, `ra_elem(level = "fast")` levanta
  `ra_fast_level_unsafe` (warning tipado, `ra_warn()` nuevo en `conditions.R`) y **escala al
  riguroso**; sin backend, la misma clase como error — no se devuelve un encierro que no se
  puede distinguir de uno inválido.
- **S3 — procedencia en el objeto, la opción (c) hecha estructura**: la clase `ra_ivl` gana el
  campo `prov` (`theorem` / `measured`) en TODOS sus sitios de construcción (constructor,
  especiales, `c`, `[`, `ra_set_dec`, `.ra_assemble` con argumento obligatorio y sus 15
  llamadores, la promoción de numéricos). El nivel rápido marca `measured`; el riguroso y el
  kernel preservan; **la mezcla propaga el más débil**. `format` marca con `*`, `print` agrega
  la leyenda, `summary` cuenta, `as.data.frame` gana la columna (un contrato viejo del test de
  la clase se actualizó a las cinco columnas). **El default para un objeto sin campo es
  `measured`**: un sitio olvidado subdeclara, nunca sobredeclara.
- **S4 — ancla de entorno nombrada** (glibc 2.43, R 4.6.1, JIT 3, Rmpfr 1.1.2, fecha, fuente):
  en carga se compara lo comparable y el desajuste se NOMBRA en el arranque y en el mensaje de
  degradación; **S1 es el control real, S4 sólo explica**.
- **S5 — el control que puede fallar**: `ra_check_sentinels(slack = 0)` DEBE fallar (falla),
  la degradación forzada DEBE producir la palabra (la produce, por las dos ramas), y los
  centinelas con la ruta sana DEBEN pasar (pasan, con al menos un punto necesitando ≥1 paso —
  el chequeo no es vacuo).

**37 aserciones nuevas, todas en verde a la primera corrida del arnés contra la pieza.**

### §3.4. Fase 4 — Hansen-Sengupta, paving y certificados, bajo el contrato (c)

`tests/testthat/test-newton.R` y `test-gate-newton.R` escritos ANTES que `R/newton.R`. La
pieza: `ra_newton_step()` (el paso de V.4 con la división extendida de Hansen-Walster),
`ra_solve()` sobre `.ra_solve_impl()` (cola FIFO, exclusión primero, contracción después;
**el split deja el candidato que resistió la contracción en la parte MAYOR** — el paso 5 de
Neumaier, corte en 2/3 —; **vigía de presupuesto** que al tope manda TODO lo no procesado a
no-excluible y lo dice con su cifra; fusión de clusters y **verificación de candidato por
inflado por épsilon**, con el knob interno `inflate` como manija del control positivo), y la
clase `ra_paving` con todo lo que arrastra JUNTO (`print` = la tarjeta, `format`,
`as.data.frame`, `summary` con su impresión). Las tres palabras: `unique`, ausencia
demostrada, no excluible — y la del tope de escalera con su cifra.

**El contrato (c) hecho estructura en `.ra_finish_paving()`**: con backend presente, CADA
certificado de unicidad se re-establece al nivel riguroso y CADA caja excluida se re-excluye
rigurosamente, subiendo la escalera {106, 212, 424, 848} cuando un rung no decide; lo que no
se decide en el tope baja a no-excluible con la palabra. Sin backend, los veredictos llevan
procedencia `measured` y la tarjeta lo rotula a la vista.

**El defecto que el portón 4 cazó, y es de fondo**: la primera verificación rigurosa
re-verificaba sobre el enclosure YA PULIDO (~7e-16 de ancho) con un ulp de inflado, y falló
la horquilla con r = 0,75 (26 de 27). La causa no era la raíz sino el **piso de ruido de la
aritmética binaria64 del árbol de expresiones**: `r*x - x^3` cerca de la raíz cancela dos
términos de ~0,65, el encierro del punto medio sale de ancho comparable a la caja pulida, y
**subir la escalera MPFR no baja ese piso porque el cuello es el kernel binario64, no la
precisión del backend** (las elementales van a MPFR; los operadores aritméticos del árbol
son binary64 con pred/succ). La reparación: la verificación rigurosa se establece sobre **la
MISMA caja inflada que certificó la vía rápida**, y el enclosure que la tarjeta imprime es el
**N riguroso** — el intervalo que el teorema respalda. Con eso: **27 de 27**.

### §3.5. Portón 4 — cruzado

**27 de 27 filas contra Strogatz** (9 valores de r × 3 formas, ventana [-3, 3]): (a) la
silla-nodo en r = 0 dice «no excluible» conteniendo al 0, apretado (±1e-3); (b) las cuatro
ventanas de r < 0 de la silla salen **demostradas vacías** y la tarjeta dice «absence
demonstrated»; (c) cero `unique` donde el álgebra no da raíz simple, cada raíz algebraica
adentro de su enclosure **verificada en MPFR a 300 bits** (no contra `sqrt` de doble), anchos
≤ 1e-8, ningún presupuesto agotado. Más los controles: sin inflado, la raíz de borde de
ventana NO se certifica (la lección de la sonda 4 puede fallar y falla); presupuesto de 3
cajas habla con su cifra; dos raíces a 2^-60 producen abstención y no mentira; raíz múltiple
jamás `unique`. **104 aserciones nuevas de la fase 4 (37 + 67), en verde.**

### §3.6. Estado al cerrar la 81

- **Fases 0, 1, 2, 3 y 4 TERMINADAS, portones 0-4 cruzados.** Pendiente: **5** (el enchufe en
  QD: sonda + plantado, tercera medición por CONTENCIÓN, semántica de mapa, fixturas VI.2).
- **Suite del paquete: **PASS 835 · FAIL 0 · WARN 0 · SKIP 2 · ERROR 0**.** Desde 694: 37 (salvaguardas) + 104 (fase 4) nuevas más
  el ajuste de un contrato viejo (columna `prov`).
- `R CMD check` natural: **Status: OK**.
- **Cero commits** en los dos paquetes; espejo a Kingston NO movido; **QD intacto** (cero
  cambios en `R/`, suite no corrida, sigue igualada en 89 078).
- Lo que la fase 5 hereda: `ra_solve()`/`ra_paving` con el contrato (c) adentro, `ra_prov()`
  y la procedencia en toda la clase, las salvaguardas activas en carga, y la tarjeta que ya
  sabe rotular `measured` — la frase que la tarjeta de procedencia de la fase 5 tiene que
  decir («error publicado como ancla, más el error medido de la ruta en uso») tiene ahora su
  estructura portadora.

---

## §4. Sesion 82 — fase 5: el enchufe en QD, la tercera medicion por contencion, y la lectura de mapa

Sesion de ejecucion (Opus, esfuerzo Max). El grueso de la obra de esta fase vive en el `R/` de
**QuantDialectics** y su detalle esta en `NOTES-FASE-B.md` §208; aca queda lo que
`RobustArithmetic` tiene que saber de si mismo. Pre-registro en `dev/PREREGISTRO_FASE_5.md`,
escrito antes de la primera linea, **con dos enmiendas fechadas que son dos predicciones mias
falladas**. Cero commits.

### §4.1. El paso 0

Suite de arranque **PASS 835 · FAIL 0 · WARN 0 · SKIP 2 · ERROR 0**, la cifra exacta de la 81,
con `RA_GATE2_N=20000`. `R/` ASCII puro aca y en QD. Premisas re-auditadas y no solo cifras: los
**19 centinelas dan `ok` en esta carga**, el test de que la ruta de evaluacion de R no es la
correctamente redondeada **sigue disparando**, y el porton 4 sigue en **27 de 27** (corre dentro
de la suite). Versiones sin cambio: R 4.6.1, Rmpfr 1.1.2, testthat 3.3.2, roxygen2 8.0.0.

### §4.2. El paquete queda INSTALADO, y por el camino que el autor usa

Hasta la 81 el paquete solo existia como fuente. La fase 5 lo necesita **en la biblioteca**,
porque QD lo alcanza por `requireNamespace` como a cualquier otro backend. Medido primero de
donde salen los backends que ya estan: `EmpiricalDynamics`, `gdpar` y `topologyR` viven todos en
`~/R/x86_64-redhat-linux-gnu-library/4.6` y estan empaquetados localmente (`Packaged:` con el
usuario del autor, sin campo `Repository`). Asi que:
`R CMD INSTALL --no-multiarch --with-keep.source ~/RobustArithmetic` a esa misma biblioteca. Ni
CRAN ni r-universe ni el espejo de Kingston: **el camino que el autor usa para sus propios
paquetes**.

### §4.3. La API que QD consume, y lo unico que hubo que envolver

`ra_enclose_expr()` con `env` para los coeficientes, `ra_interval()`, `ra_inf()`/`ra_sup()`,
`ra_prov()`, `ra_has_mpfr()` y `ra_check_sentinels()`. **Nada del paquete cambio para que QD
entrara**, que es la prueba de que la superficie de la fase 4 estaba bien puesta.

Lo unico que QD tuvo que envolver es la degradacion de S1/S2: `ra_fast_level_unsafe` se atrapa
con `withCallingHandlers` en **un solo lugar** (`fixed_point_enclose_one()`), se apaga el warning
para que no viaje afuera de una lectura que si obtuvo su respuesta, y **se registra que se
disparo**. El nivel se elige por el contrato (c) de C-54: `rigorous` cuando `ra_has_mpfr()`, y
`fast` con la procedencia rotulada a la vista si no.

### §4.4. Dos hallazgos que tocan a la aritmetica y no solo a QD

1. **El radio del encierro de `f'` sobre la caja de la raiz ES la resolucion de primer orden de
   C-47, y donde la curvatura se anula NO lo es.** Sobre los 43 estados del barrido canonico, el
   cociente `rad / (|f''| * du)` se aparta de 1 en a lo sumo **3,638e-12** — la igualdad es
   exacta y no aproximada, porque el ancho del rango de `x^2` sobre `[c-d, c+d]` es `4cd` sin
   resto. Pero en los 9 estados donde `f'' = 0` el termino de primer orden es cero y el radio
   riguroso sigue valiendo **2,235e-8**, que son **609 veces** el piso declarado de 3,667e-11. La
   resolucion de primer orden no es conservadora ahi. Ver E-1 del pre-registro.
2. **Una ventana cuya imagen toca su propio borde EXACTAMENTE no se puede certificar, y
   subdividir no ayuda.** `g(x) = -x` sobre `[-1, 1]` da `[-1,0000000000000007;
   1,0000000000000007]` con 1, 2, 4, 16 y 64 subcajas, **identico hasta el ultimo bit**: un
   encierro que redondea hacia afuera por construccion sobrepasa el borde por un ulp, y eso no es
   un problema de dependencia sino de redondeo. Es la §3.4 de la 81 en otro traje. Ver E-2.

### §4.5. Lo que la subdivision compro, medido

La dependencia sobre una caja ancha es severa y se paga con bisección, no con precision.
`g = x - x^3` sobre `[-1,2; 1,2]`, imagen verdadera `[-0,528; 0,528]`:

| subcajas | imagen encerrada | adentro de la ventana |
| --- | --- | --- |
| 1 | [-2,928; 2,928] | no |
| 2 | [-1,608; 1,608] | no |
| 4 | [-0,573; 0,573] | **si** |
| 8 | [-0,528; 0,528] | si (imagen verdadera) |

Costo medido: 256 subcajas al nivel rapido, 2,14 s; 64 al riguroso, 0,55 s. La escalera que QD
declara — `{1, 2, ..., 256}` con abstencion en el tope — tiene la misma forma que la escalera de
precision de este paquete y la misma palabra al final.

### §4.6. Estado al cerrar la 82

- **Fases 0-5 TERMINADAS.** La via intervalar queda cerrada.
- Suite del paquete: sin cambio, **PASS 835 · FAIL 0 · WARN 0 · SKIP 2 · ERROR 0**; `R CMD check`
  natural Status: OK. **Esta fase no agrego ni cambio una linea de `R/` de este paquete**: toda
  la obra fue del lado de QD.
- **Cero commits** en los dos paquetes.

## §5. Sesion 83 — la tanda del DESCRIPTION: el estandar no gradua, y la frase del modo de redondeo

Sesion de cierre de la via intervalar (Opus, esfuerzo Max). El grueso de la sesion fue del lado
de QD y esta en `NOTES-FASE-B.md` §209; aca queda lo que este paquete cambio, que es prosa y
ninguna linea de codigo. **Cero commits.**

### §5.1. Lo que el autor pidio en la 80 y se ejecuto al cruzar el porton 5

Dos instrucciones suyas, aplazadas por el hasta que la via estuviera terminada (§2-bis del prompt
81, puntos 1 y 2). La tercera de esa lista —APA 7 en la documentacion— quedo cerrada en la 81.

### §5.2. La conformidad, medida contra la clausula 6 punto por punto

**Su hipotesis al pedirlo era que la frase «partial conformance» se habia quedado corta**: ahora
esta la documentacion oficial completa, asi que quiza el subconjunto cubra todo y se pueda decir
«conformance» a secas. **Medido, el resultado va en la direccion contraria, y por una razon que
esta en el propio estandar antes que en el paquete.**

**La subclausula 1.5 no tiene grado parcial.** Define la conformidad como una lista de requisitos
que una implementacion **shall** satisfacer: las decoraciones de 5.2, las operaciones requeridas
de 6.7 con las exactitudes de 6.5, la entrada y salida de texto de 6.8.2 y 6.8.3, y la
representacion de intercambio de 7.3. La palabra «partial» no aparece en el documento en ese
sentido. De modo que **«partial conformance» no era una frase mas floja que «conformance»: era
una frase que la norma no licencia**, y la reparacion no es subir el grado ni bajarlo sino dejar
de graduarse y enumerar.

**Lo que hay, medido contra la clausula 6:**

| requisito | subclausula | estado |
| --- | --- | --- |
| constantes de intervalo | 6.7.1 | provistas |
| version intervalar de cada operacion de la Tabla 4.1 | 6.7.2 | **22 de 39** |
| suma y resta cancelativas | 6.7.3 | ausentes |
| interseccion y casco convexo | 6.7.4 | provistas |
| `numsToInterval` | 6.7.5 | provista, con divergencia declarada |
| `textToInterval` y los literales de 6.6 | 6.7.5, 6.6 | ausentes |
| las siete funciones numericas de la Tabla 4.3 | 6.7.6 | las siete |
| `isEmpty`, `isEntire`, `isNaI` | 6.7.7 | provistas |
| las comparaciones de la Tabla 4.5 | 6.7.7 | ausentes |
| `decorationPart`, `setDec` | 6.7.8 | provistas |
| `newDec` expuesta, `intervalPart`, orden de decoraciones | 6.7.8 | ausentes |
| exactitud **`tightest`** de las operaciones basicas | 6.5.2 | **no se cumple** |
| salida de texto (`intervalToText`) | 6.8.3 | **provista** (§6) |
| entrada de texto (`textToInterval`) | 6.8.2 | ausente |
| representacion de intercambio | 7.3 | ausente |

Las 17 que faltan de la Tabla 4.1: `recip`, `fma`, `pow`, `exp2`, `exp10`, `atan2`, `asinh`,
`acosh`, `atanh`, `sign`, `ceil`, `floor`, `trunc`, `roundTiesToEven`, `roundTiesToAway`, `min`,
`max`. **La razon de fondo, y es una sola**: la tabla de simbolos admisibles se cerro por los
criterios C1-C4 de la §1.1, que son los criterios de un motor de expresiones —que `stats::D` la
derive, que la tabla cierre bajo diferenciacion, que haya error publicado en ulps, que MPFR la
provea—, y **la lista de la norma no es esa lista**. Las dos son legitimas y no coinciden.

**Y las 22 que hay se verificaron como EXTENSIONES INTERVALARES y no como evaluacion de
extremos**, que es lo que 6.4 pide y lo que un conteo de nombres no distingue: `sin` sobre
`[0, pi]` da `[0, 1]` y no `[sin(0), sin(pi)]`, `cos` sobre `[0, 2pi]` da `[-1, 1]`, `sqr` sobre
`[-2, 1]` da `[0, 4]`, y `tan` sobre `[1, 2]` —que cruza el polo— da Entire con `trv`. Un total
que cierra puede tener el modelo equivocado; este no lo tiene.

### §5.3. El hallazgo que no se esperaba: la exactitud de 6.5.2

**La 6.5.2 exige que las operaciones basicas sean `tightest`**, o sea que devuelvan el **casco**
del resultado exacto. **No lo son, y no pueden serlo por construccion.** Medido:
`ra_add([1,1],[2^-60,2^-60])` devuelve `[pred(1), succ(1)]`, **1,5 ulps de ancho**, donde el casco
exacto mide uno; y `ra_add([1,1],[1,1])`, cuyo resultado es exactamente representable, devuelve un
intervalo de ancho 6,66e-16 en vez del punto. El redondeo hacia afuera ensancha un ulp de cada
lado, **y ensanchar es lo que hace demostrable el encierro sin tocar el modo de redondeo**: es el
precio del diseno entero de este paquete, no un defecto suyo. Lo que se cumple es el modo mas
debil, `valid`, y se cumple por teorema y no por medicion.

Es la clase de cosa que sale de leer la clausula que uno cita: el paquete cumplia la parte de 6.7
que enumera operaciones y fallaba la de 6.5 que las califica, y la frase del DESCRIPTION no
distinguia entre las dos.

### §5.4. La frase del modo de redondeo, sin sujeto ambiguo

Decia: «a change that is not available from R and would leak into linked libraries if it were».
El la leyo —con razon— como si hablara de **sus** otras librerias. No es eso, y la version nueva
lo dice sin sujeto que se pueda confundir: **el modo de redondeo es estado por hilo del
procesador, no una configuracion del que llama**, de manera que quien lo cambia lo cambia para
toda operacion de punto flotante que corra despues en ese hilo, la haga quien la haga y calcule
lo que calcule, hasta que alguien lo devuelva. La misma frase quedo reescrita en el
`@details` de la pagina del paquete, que la tenia con el mismo defecto y con una lista
—«las librerias de algebra lineal y el compilador de byte-code»— que angostaba lo que en realidad
es universal.

### §5.5. Tres cosas mas que la lectura de la clausula 6 destapo, y como quedaron

1. **La pagina de `format.ra_ivl` citaba la «subclausula 6.9», que no existe**: la clausula 6 de
   la norma simplificada termina en 6.8. La que gobierna la salida de texto es **6.8.3**, y este
   metodo **no la cumple**: 6.8.3 pide que la cadena **contenga** al intervalo del que salio, y
   representar para un lector redondea. Medido: el encierro cuyos extremos son el predecesor y el
   sucesor de uno imprime `[1, 1]`, que no contiene a ninguno de los dos. **Reparado en la
   pagina**, que ahora dice que es una representacion de consola y no la salida del estandar, y
   manda al lector a `x$lo`, `x$hi` y `as.data.frame()`, que llevan los extremos sin redondear.
   **No se cambio el comportamiento**: cambiar como imprime todo intervalo es decision de diseno
   con costo en los dos paquetes, y lo que estaba mal era la afirmacion, no la cifra que se ve.
   > **Superado por el §6.** El comportamiento SI se cambio despues, y la frase de arriba
   > —«costo en los dos paquetes»— era una estimacion que la medicion desmintio: el costo estaba
   > en otro lado y era chico. Lo que esta linea describe es lo que se decidio en la 83, no lo que
   > el paquete hace.
2. **La divergencia del constructor queda como divergencia** (D-83.5). La letra de 6.7.5 decide
   la mitad sola: un constructor que falla **devuelve un dato Y senala** la excepcion
   `UndefinedOperation`, o sea que lo que la norma prohibe es fallar en silencio y no fallar en
   voz alta. En R la forma en voz alta es una condicion tipada, y la forma valor queda a una
   llamada por `ra_nai()`.
3. **`p_col_condition` duplicada en QD** no es de este paquete, pero salio de la misma corrida y
   esta en el §209.

### §5.6. Estado al cerrar la 83

- **Fases 0-5 TERMINADAS y la via intervalar cerrada.** Esta sesion no toco `R/` de este paquete
  salvo prosa de documentacion: `DESCRIPTION`, `R/RobustArithmetic-package.R` y
  `R/interval-class.R`.
- **Cero commits** en los dos paquetes.

---

## §6. Sesion 08 de HERACLITUS — FASE 6: certificados de punto fijo por bola de norma

Sesion de ejecucion (Opus, esfuerzo Max), pedida por el autor con la formula «procede con maxima
robustez con su implementacion» despues de que el dictamen de encaje entre la via intervalar y la C-21
de HERACLITUS diera favorable. Pre-registro en `dev/PREREGISTRO_FASE_6.md`, escrito **antes** de la
primera linea de codigo y de la primera linea de tests, con **una enmienda fechada** que es un defecto
de diseño propio cazado por escribir los controles. **Cero commits.**

### §6.1. De donde sale la fase, y que problema resuelve

La C-21 de HERACLITUS tiene que certificar el punto fijo de la iteracion implicita del salto de rana
generalizado, que vive en `R^48` y `R^96`. Lo construido hasta la 83 es **univariado**: `ra_newton_step()`
PARA con `length(x) != 1` y en los 55 exports no hay una sola operacion de matrices.

**La fase no cierra esa brecha construyendo algebra lineal intervalar: la esquiva.** El certificado por
bola de norma es una desigualdad ESCALAR, y por lo tanto se apoya entero en el sustrato ya portoneado.
Lo que la hace suficiente para el problema que la motiva es un resultado que se verifico en papel y
esta asentado en la suite de HERACLITUS: por la formula de Daleckii-Krein,
`||dSoftAbs/dtheta||_F <= max|J_kl| * ||dH/dtheta||_F` con `J` las diferencias divididas de `sigma`, y
por el teorema del valor medio `max|J_kl| <= sup|sigma'| = 1`. **La descomposicion espectral desaparece
de la cota**, y con ella la necesidad de encerrar autovalores en intervalos.

### §6.2. La enmienda E-1, que es un defecto de diseño propio cazado por los controles

El diseño original tomaba DOS insumos: el residuo en el centro y una constante de Lipschitz. Al
escribir la fixtura de «confinamiento sin contraccion» que VI.3 exige poder distinguir, la cuenta no
cerro: la condicion `L*r + rho <= r` es `(1-L)*r >= rho`, que **con `rho > 0` fuerza `L < 1`**. Vale
decir que los dos certificados que el Bloque VI manda emitir por separado habrian sido el mismo
certificado con dos nombres.

Lo que faltaba es la puerta que el Bloque VI usa en 1-D sin nombrarla como puerta: **la evaluacion
DIRECTA de la imagen**. El nucleo toma ahora **tres** insumos, `rho`, `image_radius` y `lipschitz`, y
la fixtura que la enmienda hizo posible es `Phi(x) = x^2` sobre `[0; 0,8]`, cuya imagen `[0; 0,64]`
cabe adentro mientras `sup|Phi'| = 1,6` refuta la contraccion.

### §6.3. El hallazgo de la implementacion: la desigualdad NO se re-evalua en punto flotante

Los primeros controles fallaron sobre un codigo correcto, y el diagnostico es de metodo. Evaluar
`L*r + rho <= r` con el miembro izquierdo redondeado hacia arriba **rechaza casos que valen con
igualdad**: medido, `rho = 0,2`, `L = 0,5`, `r = 0,4`, donde los tres dobles satisfacen la desigualdad
EXACTAMENTE —`fl(0,4)/2 + fl(0,2)` es `fl(0,4)` sin resto— y dos sucesores la rompen.

**La reparacion es usar el teorema en vez de la aritmetica.** (T4) hace `r >= rho/(1-L)` **equivalente**
a `L*r + rho <= r`, de modo que comparar contra el radio minimo —numerador hacia arriba, denominador
hacia abajo— decide la ruta de Lipschitz **exactamente**. Y con eso la re-evaluacion de la desigualdad
queda como **codigo muerto**: si `r >= r*` la ruta ya decidio, y si `r < r*` la desigualdad exacta falla
igual. Se saco. Quedan **dos rutas, las dos exactas por construccion**: la imagen directa y el radio
minimo.

Es la §5.3 de la 83 en un tercer traje: el redondeo hacia afuera es el precio del diseño y no un
defecto, pero **donde un teorema da el veredicto exacto, el teorema manda sobre la cota**.

### §6.4. La superficie

`ra_ball_certificate()` con los dos veredictos separados, la ruta que decidio, el radio certificado, la
cota de error del centro (que **exige contraccion**: sin unicidad la distancia a «el» punto fijo no esta
definida), el rotulo de norma y la procedencia; `ra_certify_fixed_point()`, la puerta univariada que
**deriva** los tres insumos sobre la bola con `ra_enclose_expr()` y `stats::D` y cierra el circulo;
`ra_gershgorin()` (T6) y `ra_spectral_sum()` (T7). Mas todo lo que arrastra la clase, JUNTO: `format`,
`print`, `as.data.frame`, `summary` con su clase `ra_summary_certificate` y su propio `format`/`print`,
y la fixtura de impresion.

**Cuatro exportadas nuevas y seis metodos**; el NAMESPACE pasa de 55 a 59 exports.

### §6.5. Porton 6 — cruzado

- **P1**: 200 instancias de mapas afines en `R^n`, `n` de **1 a 8**, contra DOS referentes que no
  comparten aritmetica con el certificado: la solucion de LAPACK acotada por un residuo en MPFR a 300
  bits via la cota de Neumann, y —en un submuestreo— **la iteracion del propio `Phi` en MPFR**, que
  nunca resuelve un sistema. **Cero fallos**, y el peor cociente `distancia / cota` da **1,0000**: la
  cota es AJUSTADA y el porton corre exactamente sobre el borde. Que lo pase con el radio redondeado
  hacia arriba es lo que hay que ver; en dimension uno con `a > 0` la igualdad se alcanza de verdad.
- **P2**: los cuatro controles que deben rechazar disparan — la traslacion (sin punto fijo en ningun
  lado, `L = 1` exacto), el radio insuficiente, el `L` medido solo en el centro (que la puerta
  univariada SI rechaza porque mide sobre la bola), y la fixtura de confinamiento sin contraccion.
- **P3**: **500** matrices simetricas (genericas, diagonales, casi degeneradas, mal condicionadas) con
  **cero** autovalores fuera del encierro de Gershgorin, y **126 diagonales** donde la cota sale
  **ajustada**, que es el caso que separa un Gershgorin implementado de uno inventado. Weyl: **300**
  pares, cero fuera.
- **P4**: **16 801** casos donde la aritmetica dirigida rechaza y la ingenua acepta, y **cero** al
  reves. El redondeo entra, y entra en la direccion conservadora.

### §6.6. Estado al cerrar la fase 6

- **Fases 0 a 6 TERMINADAS, portones 0 a 6 cruzados.** El paquete gana un archivo,
  `R/ball-certificate.R`, con **cuatro exportadas y seis metodos**; el NAMESPACE pasa de 55 a 59
  exports.
- **Suite del paquete: PASS 920 · FAIL 0 · WARN 0 · SKIP 2 · ERROR 0.** Desde 835 en la 83: **85
  aserciones nuevas, ninguna vieja perdida.** Los dos SKIP son los de siempre.
- **`R CMD check` natural: Status: OK**, sin una sola NOTE. Ojo con la invocacion: sobre el DIRECTORIO
  fuente da `1 ERROR` por `Author`/`Maintainer` faltantes, porque esos campos los DERIVA `R CMD build`
  de `Authors@R` y un check sobre directorio no construye. Se corre `R CMD build` y despues el check
  sobre el tarball.
- **Cero commits** en los dos paquetes; espejo a Kingston no movido.
- **Lo que esta fase habilita, y todavia no corrio**: la C-21 de HERACLITUS, cuyo pre-registro y cuyo
  exportador de los tres escalares por `(eps, T)` candidato son la obra siguiente **del lado de
  HERACLITUS**, no de este paquete.
- **Y dos defectos que la fase encontro en HERACLITUS**, los dos en `pathrmhmc.jl` y los dos por
  derivar el algebra en papel antes de escribir codigo: `_sa_dsig` devolvia `alpha` veces la derivada
  en su rama de argumento chico, y `_matriz_J` salia ASIMETRICA en esa misma rama. Reparados alla, con
  bateria nueva en su suite (**949/949**) y con su chequeo bit-exacto en 0 fallos.

---

## §6. La reparacion de la salida: un renglon impreso es una afirmacion

Pedido por el autor a partir del `AVISO_QD_FORMAT_RA_IVL.md` que dejo la sesion 85 de
QuantDialectics. **El diagnostico del aviso era correcto y su reparacion propuesta no**, y las dos
cosas se establecieron midiendo, no discutiendo.

### §6.1. El criterio, que el aviso tenia mal

6.8.3 dice que la cadena debe contener al intervalo, y **6.6.2 dice que significa la cadena**: el
valor del literal `[l, u]` es el intervalo **matematico** `[l, u]`, o sea los decimales leidos
exactos. El aviso uso otro criterio —«la cadena vuelve a leerse como el mismo double»— y con ese
criterio recomendo la **representacion de ida y vuelta mas corta**. Medido con Rmpfr a 400 bits,
esa forma **falla 6.8.3 en tres de cinco casos**, incluido el ejemplo central del propio aviso:
para el double `0.1 + 5e-17` la cadena mas corta que vuelve es `0.10000000000000006`, cuyo valor
exacto queda **por debajo** del extremo. La forma parece contener y no contiene.

Y en la otra direccion: el «hacia afuera infla nueve ordenes de magnitud» del aviso era artefacto
de fijar **siete** cifras. Dirigido a las cifras que el numero tiene, el ancho impreso queda en
razon 1,00001 y **cuesta entre −2 y +1 caracteres**.

### §6.2. Las dos clases de numero impreso

La reparacion entera sale de separar dos cosas que se imprimian igual:

- **El numero que ACOTA un desconocido** —un extremo, un ancho, una cota de error, las premisas
  del certificado— se redondea en la direccion que deja la oracion verdadera, cueste las cifras
  que cueste.
- **El numero que IDENTIFICA el dato sobre el que se corrio** —el radio de la bola certificada—
  se reproduce: la cadena mas corta que vuelve al mismo double. El confinamiento de una bola no
  implica el de ninguna otra, ni mayor ni menor, asi que ahi redondear en cualquier direccion
  afirma algo que no se probo.

`format.ra_ivl` era el primer caso; la tarjeta de `format.ra_certificate` tenia **los dos**, y el
aviso no la habia mirado. Medido sobre el `@examples` que el paquete envia,
`ra_ball_certificate(0.2, 0.5)`: cota verdadera `0.40000000000000013`, renglon impreso **«the
centre is within 0.4 of it»**. `%.6g` redondea al mas cercano y ahi afirmaba una cota **mas
ajustada que la certificada**.

### §6.3. El motor, y de que depende su correccion

`R/decimal.R`. La garantia se apoya en dos cosas y en ninguna mas: que la conversion de decimal a
binario es **monotona** —lo es, porque es un redondeo— y que sumar o restar una unidad a la ultima
cifra **de la cadena** es exacto. Todo lo demas es busqueda de estrechez y no puede romper la
contencion.

Tres pruebas se admiten y ninguna otra. Si la conversion cae estrictamente de un lado, la
monotonia decide. Si cae **sobre** el extremo, hay dos salidas: la **rejilla** —`v` esta sobre la
rejilla de paso `10^p` si y solo si tiene a lo sumo `-p` bits fraccionarios, que es aritmetica y
no comparacion, y es lo que mantiene `-2.5` imprimiendose `-2.5`— y la **comparacion exacta**, que
lleva el significando decimal como suma exacta de dos doubles y escala por potencias de diez en
etapas con cota de error derivada, y **contesta solo donde la cota lo certifica**. Lo que no se
certifica se declina, y declinar mueve una cifra hacia afuera: nunca se lee un signo del error.

**Holgura declarada:** el encierro impreso queda contenido en `[ra_pred(lo), ra_succ(hi)]`.
Imprimir no cuesta mas que lo que cuesta una operacion de la aritmetica.

### §6.4. Lo medido

Contra Rmpfr a 400 bits, 9038 comprobaciones sobre adversariales (decimales exactos, subnormales,
potencias de dos, los dos extremos del rango, `1e23`, `2^53+1`) y aleatorios de todo el rango:

| propiedad | fallos |
| --- | --- |
| contencion de Nivel 1 (6.6.2 + 6.8.3) | **0** |
| holgura dentro de un paso de redondeo | **0** |
| optimalidad (mover la ultima cifra hacia adentro rompe la contencion) | **0** |

Con **control positivo**: el mismo porton corrido sobre `format()` de R —al mas cercano, siete
cifras— falla, que es lo que prueba que el porton mide lo que dice medir. Y un segundo control
positivo sobre el `%.6g` viejo de la tarjeta.

**La suite entera con TODOS los portones encendidos (`NOT_CRAN=true`, los de Rmpfr incluidos):
955 aserciones, 0 fallos, 0 errores, 0 avisos, 2 saltadas** —las dos, rutas inalcanzables porque
el backend SI esta instalado—. `R CMD check --as-cran`: **0 errores, 0 avisos, 1 NOTE**
(«New submission»).

**Rendimiento, declarado porque no es gratis:** del orden de un milisegundo por extremo
**distinto**, porque cada uno se prueba en vez de formatearse; los extremos repetidos se cobran una
sola vez. `format()` de mil intervalos tarda ~1,6 s —arranco en 12,5 s y se optimizo sacando el
motor de expresiones regulares del camino caliente y convirtiendo los candidatos desde sus digitos
en vez de desde su renderizado—. Quien tenga miles quiere `as.data.frame()`, que no prueba porque
no imprime, y eso quedo escrito en la pagina de `ra_show`.

### §6.5. Defectos propios que salieron en el camino

1. **`formatC(flag = "0")` rellena una cadena con espacios, no con ceros.** Metia `NA` en los
   digitos y la comparacion exacta se declinaba sin decirlo; costaba una cifra en `1e23`. Se
   escribio el relleno a mano.
2. **`paste0()` trata un argumento de largo cero como cadena vacia**, asi que `format()` de un
   vector vacio de intervalos devolvia **un** renglon de puntuacion en vez de ninguno. Defecto
   anterior a esta sesion. Reparado con guarda de largo.
3. **El acoplamiento de `format()` sobre el vector.** Un extremo de `1e-31` en una tarjeta de
   `ra_solve` arrastraba a **todos** los demas a `1.000000e+00`: siete cifras y notacion
   cientifica para el numero 1. Cada extremo se rinde ahora por su propio valor y la tarjeta de
   `x^3 - x` muestra las tres raices con la precision que cada una tiene.

### §6.6. Lo que no se hizo, y por que

- **La forma incierta `m?r` de 6.6.2 no se emite.** Es mas corta para un intervalo angosto —para
  `[pi, pi]`, 22 caracteres contra 40— y ningun especificador la selecciona. Nada depende de ella,
  y una forma a medio escribir es peor que ausente.
- **6.8.2 (`textToInterval`) sigue ausente.** El paquete produce literales validos; no los lee.
- **Cerrar 6.8.3 no da conformidad**: la clausula 1 exige ademas 6.8.2 y 7.3, y la 1788.1 no tiene
  grado parcial (§5 de estas notas). El argumento para reparar era de **correccion**, no de
  conformidad, y asi quedo escrito.
