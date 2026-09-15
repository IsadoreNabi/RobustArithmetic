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

---

## §7. El pretest de CRAN: un banco que afirmaba la MAQUINA y no el codigo

Llego el 2026-08-21: **1 ERROR en Debian (R-devel, glibc 2.42) y 1 ERROR en Windows Server 2022**,
los dos desde la suite. **Los dos por la misma causa, y la causa estaba en el banco.**

**Primero, lo que NO fue:** no lo causo la reparacion del §6. Se ve en el propio log de CRAN, que
imprime `[2.718282, 7.389056]_com` — el formato **viejo**, al mas cercano y a siete cifras. CRAN
probo el tarball anterior. Los 14 fallos son anteriores.

### §7.1. Lo que paso, que es el paquete funcionando

Este paquete envia **centinelas medidos** —el error observado de la libreria matematica del sistema
sobre dieciseis funciones— y un **ancla** que registra el entorno donde se midieron. Las
salvaguardas existen justamente porque otra maquina puede no honrarlos. En Windows la libreria
**excedio la holgura declarada**, el porton degrado el nivel rapido, toda evaluacion escalo al
riguroso con aviso, y el paquete lo dijo **197 veces**. Eso no es un defecto: es S2 y S5 haciendo
exactamente lo suyo.

En Debian la libreria si honro la holgura; lo unico que difirio fue el ancla (R 4.7.0 contra 4.6.1,
glibc 2.42 contra 2.43).

### §7.2. Los tres defectos del banco

1. **`test-safeguards.R:90` afirmaba `length(a$mismatch) == 0`**, o sea **que la maquina que corre
   las pruebas ES la maquina donde se generaron los centinelas**. Solo puede pasar ahi. Y el nombre
   de la prueba —«the environment anchor is named and the comparison can fail»— no pedia eso.
   Ahora afirma lo que si es propiedad del paquete: que un desajuste, donde lo haya, **nombra el
   campo** del que habla. El control positivo del ancla adulterada se conservo.
2. **Cuatro pruebas presuponian que el nivel rapido estaba en uso** (las tres de propagacion de
   procedencia S3 y la CP-7 de la escalera). Con el nivel rapido degradado, todo vuelve `theorem` y
   no queda procedencia `measured` que propagar; y la escalera arranca ya en el peldano riguroso,
   asi que no hay de donde subir. Esas pruebas son sobre la **contabilidad** y sobre la **escalera**,
   no sobre la exactitud de ninguna libreria: ahora **mantienen abierto el nivel rapido mientras
   duran** y restauran el estado de sesion al salir. La degradacion se prueba aparte y sin condicion.
3. **`test-elementary.R:173` afirmaba `observed <= slack`**, que es una afirmacion sobre **esta**
   maquina y la holgura se midio en otra. Ahora la afirma donde puede ser cierta, y donde no,
   afirma lo que nunca puede fallar: **que el paquete se dio cuenta**. Una libreria que rompe la
   cota publicada y un paquete que no lo dice es el unico desenlace que esa prueba existe para
   prohibir.

Hermano del §6.5 y de la misma familia: **`test-safeguards.R:78` no fallaba por lo que miraba**. El
porton solo audita mientras el nivel rapido **no** esta ya degradado, asi que una sesion degradada
antes nunca llegaba al codigo que esa prueba interroga. Faltaba salvar y limpiar `fast_degraded`
junto con las dos banderas de auditoria.

### §7.3. Como se verifico, que es lo que hace que esto no sea una opinion

**Se reprodujeron las dos condiciones de CRAN en esta maquina**, no se conjeturaron: el ancla
adulterada para que reporte desajuste, y `ra_measure_library_error` sustituida por una que devuelve
`observed = slack + 1`, que degrada el nivel rapido de verdad por el camino de verdad.

| escenario | fallos antes | fallos ahora |
| --- | --- | --- |
| esta maquina, ancla coincidente | 0 | **0** (164 ok) |
| ancla desajustada (Debian en CRAN) | 1 | **0** (166 ok) |
| libm que rompe la holgura + ancla desajustada (Windows en CRAN) | 13 | **0** (166 ok) |

### §7.4. La NOTE de ortografia

`Boldo`, `Melquiond`, `Zimmermann` y `Sengupta` son apellidos citados; `cancellative` y `subclause`
son las palabras que usa la propia IEEE 1788.1 y cambiarlas volveria mas dificil cotejar la
declaracion de conformidad contra la norma, que es para lo que esta; `precisions` es el plural del
sustantivo. **No se toco la prosa**: quedo explicado en `cran-comments.md`, que es donde va.

### §7.5. Barrido de basura, y un cabo suelto que se cerro midiendo

**Restos de `testthat` versionados desde el commit inicial.** `tests/testthat/_problems/` y
`testthat-problems.rds` entraron en `037ff30` y venian viajando en el repositorio **y en el
tarball**: son la reproduccion de un fallo del 20/08 en `test-interval-class.R:228` que **ya no
existe** —esa prueba pasa—. Nada en `R/`, en `tests/`, en `man/` ni en los metadatos los
referenciaba: se comprobo antes de sacarlos. Quitados del control de versiones y del disco, con
regla en `.gitignore` **y** en `.Rbuildignore` para que un fallo futuro no los devuelva al tarball.
Verificado: `R CMD check --as-cran` sigue en 0 errores, 0 avisos, 1 NOTE, y `tar tzf` ya no los
encuentra adentro.

**El cabo suelto de la auditoria del 24/08.** Quedaba sin explicar por que el directorio
`tests/testthat` tenia fecha 15:13 del 21/08, once minutos despues del ultimo commit. **Era la
corrida de la suite completa lanzada desde esta misma sesion**, cuyo registro
(`~/ra_suite_allgates.log`) llevaba exactamente esa hora: `testthat` escribe y despues borra su
archivo de problemas al terminar en verde, y eso mueve la fecha del directorio sin dejar nada.
No hubo terceros. Se anota porque la explicacion no se supuso: se leyo de la fecha del registro.

**Y una copia de la wiki suelta.** `~/ra_wiki` era una copia sin git, **anterior** a la
actualizacion del 21/08 —imprimia todavia `# [4, 6]_com`— y por lo tanto una version deprecada en
paralelo de las paginas. Se verifico que es **identica al commit `353ca5e`** de la wiki antes de
borrarla: el contenido esta preservado en el historial y no se perdio nada. Las copias canonicas
son el repositorio de la wiki y `LIBRERIAS EN R/Robust Arithmetic/Wiki/`.

---

## §8. La lectura decimal de R no certifica de que lado cae un extremo

Las verificaciones de CRAN del 12/09/2026 encontraron el mismo defecto en tres
configuraciones sin doble largo de ochenta bits: `r-oldrel-macos-arm64`, `M1mac` y `noLD`.
El bloque de `test-decimal.R` que debia correr sin Rmpfr fallo porque el extremo inferior
impreso, vuelto a leer con `as.numeric()`, podia quedar por encima del double que pretendia
acotar. La prueba exponia un defecto real del motor: en esas configuraciones tambien podia
imprimirse un intervalo que no contenia al intervalo del objeto.

### §8.1. La causa y la premisa falsa de §6.3

La conversion que hace R de una cadena decimal no es un redondeo correctamente dirigido ni
un referente exacto. En R 4.6.1, `R_strtod5()` acumula el significando con
`ans = 10*ans + d` y aplica la potencia de diez mediante productos sucesivos, todo en
`LDOUBLE`. En arm64 de macOS y en una compilacion con `--disable-long-double`, `LDOUBLE` es
el mismo doble binario de 53 bits; cada acumulacion y cada producto puede redondear. Con
doble largo de ochenta bits el error es menor, pero tampoco hay una garantia de redondeo
correcto que permita deducir el lado del decimal exacto.

Por eso era falsa la frase de §6.3 segun la cual la conversion era monotona «porque es un
redondeo». Que el valor binario producido por el lector caiga por encima de un extremo no
prueba que el decimal matematico este por encima. El barrido adversarial del codigo anterior,
que desplaza 64 dobles toda lectura no exacta, encontro sobre 282 valores 126 fallos de
contencion en el modo ascendente y 129 en el descendente; encontro ademas 278 fallos de
holgura y 3 errores en cada modo. En la compilacion real sin doble largo, la medicion de
partida registrada por el encargo daba cuatro fallos en `test-decimal.R`.

### §8.2. La certificacion que la sustituye

`.ra_safe()` ya no consulta `.ra_value()`. La igualdad se decide por pertenencia exacta a la
rejilla decimal; fuera de ella, `.ra_cmp_dec()` solo devuelve un lado cuando el significando
decimal exacto y la cota derivada del escalamiento lo certifican. `.ra_bound1()` aplica la
misma comparacion al doble adyacente antes de aceptar la holgura, amplía la busqueda hasta
dieciocho cifras cuando hace falta y se detiene con un defecto interno si no puede probar a
la vez contencion y estrechez. La ruta que identifica un dato, `.ra_exact1()`, no cambia:
ahi el valor producido por el lector de R es precisamente la identidad que se quiere
reproducir.

Los significandos de hasta diecinueve cifras se forman sin leerlos de una vez. Se leen por
separado las primeras quince cifras y las cuatro restantes, que son enteros exactos en todo
doble binario; despues se recupera por resta decimal exacta el residuo de la combinacion
aritmetica. Asi, toda lectura de cadena que participa en la prueba de una cota es la de un
entero sin punto ni exponente de a lo sumo quince cifras.

El porton que corre en CRAN tambien dejo de volver a leer la cota con `as.numeric()`. Su
referente de R base toma el `%a` hexadecimal exacto del double, lo convierte a un entero por
una potencia de dos y, cuando el exponente es negativo, a un entero por una potencia de cinco
acompañado de una potencia de diez. Los enteros se llevan en miembros de base `10^7`, con
productos cuyas entradas quedan por debajo de `2^53`, y la comparacion final es cifra por
cifra. El referente comprueba tanto contencion como holgura de un paso y tiene un control
positivo: reconoce que el decimal exacto `0.1` queda por debajo del double de R llamado
`0.1`, por lo que aquel seria un extremo superior falso.

### §8.3. Lo medido despues de la reparacion

En el R del sistema, todos los portones de `test-decimal.R`, incluidos los de Rmpfr a 400
bits, terminaron con **0 fallos y 0 errores**. En el R 4.6.1 compilado sin doble largo, la
misma corrida con Rmpfr y la corrida que reproduce CRAN sin Rmpfr terminaron ambas con
**0 fallos y 0 errores**. El lector adversarial de 64 dobles termino, en los dos sentidos,
con **0 fallos de contencion, 0 fallos de holgura y 0 errores**. Como comprobacion separada
del instrumento nuevo, su reconstruccion decimal del double y el signo de sus comparaciones
coincidieron con Rmpfr en **442 valores**, sin una discrepancia.

### §8.4. El costo

Se calento primero el camino de impresion y se midieron cinco corridas de `format()` sobre
los mismos mil intervalos aleatorios, con semilla `20260913`, en esta maquina. Antes del
cambio los tiempos fueron 1,206, 1,147, 1,171, 1,157 y 1,251 segundos, con mediana de
**1,171 s**; despues fueron 1,774, 1,833, 1,852, 1,653 y 1,805 segundos, con mediana de
**1,805 s**. El costo observado subio un 54 %, porque ahora cada candidato que decide un
lado lleva una prueba en lugar de una lectura aproximada. La pagina de `ra_show` se actualizo
con la mediana, la semilla, el calentamiento, las cinco repeticiones, la cantidad de extremos
distintos y el procesador; su declaracion general sigue siendo del orden de un milisegundo
por extremo distinto y de segundos para miles de intervalos.

---

## §9. El ancla distingue el entorno generador antes de afirmar una discrepancia de ruta

Las verificaciones de CRAN en `r-oldrel-macos-arm64` y `r-oldrel-macos-x86_64`, con R 4.5.2
sobre macOS Ventura, encontraron dos afirmaciones que seguían describiendo la máquina donde se
generaron los centinelas. En el punto `2.5698953698477605e-08`, la ruta ordinaria de `sin` en
esas máquinas devuelve el valor correctamente redondeado, mientras que las pruebas exigían que
fuera distinto. La tabla, su par encuadrante y la contención eran correctos; el defecto estaba
en haber convertido una observación del entorno generador en una propiedad incondicional del
paquete.

### §9.1. El segundo defecto estaba en la identificación del entorno

`.ra_compare_anchor()` comparaba la biblioteca de C sólo cuando `getconf GNU_LIBC_VERSION`
respondía. Si el ejecutable no podía identificarla, como ocurre fuera de sistemas con glibc,
la comparación no agregaba ninguna discrepancia. El ancla tampoco registraba el identificador
de plataforma. Por eso un R de la misma versión sobre macOS arm64 podía producir un vector de
discrepancias vacío aunque no hubiera evidencia de que su ruta matemática fuera la del
generador: la ausencia de identificación se estaba leyendo como coincidencia.

La medición de partida consignada en el encargo reprodujo el defecto en cinco escenarios. El
entorno local dio 0 fallos; `oldrel`, 3; `release_nolibm`, 3 con 0 campos discrepantes;
`other_arch`, 3 también con 0 campos discrepantes; y el control positivo `guard`, 3. El
resultado agregado fue `ORACLE_ENV FAIL`.

### §9.2. La reparación separa la matemática de la afirmación de máquina

El dato regenerado agrega `platform = R.version$platform`, cuyo valor en el entorno generador
es `x86_64-redhat-linux-gnu`. La comparación nombra de manera literal los campos `r_version`,
`jit_level`, `libm` y `platform`; una biblioteca de C o un identificador de plataforma que no
pueda identificarse, tanto en el proceso como en el ancla, cuenta como discrepancia. Esta regla
conserva el papel explicativo del ancla: el control efectivo de la ruta sigue siendo la tabla de
centinelas y no una cadena de versión.

En `test-elementary.R` y `test-safeguards.R` sólo se condicionaron las dos afirmaciones de que
la ruta ordinaria difiere del valor correctamente redondeado. El valor multiprecisión, la
adyacencia del par de dobles, la identidad del punto, la integridad de la tabla y la contención
del encierro siguen siendo incondicionales. La referencia multiprecisión llama a `base::sin()`
para permanecer separada de la sustitución con la que el oráculo emula la ruta ordinaria. Un
control negativo adicional hace fallar `getconf` y exige que la respuesta nombre `libm`; de
este modo, volver a interpretar una biblioteca no identificable como coincidencia rompe la
suite.

`dev/gen_sentinels.R` regeneró `R/sysdata.rda`, y la tabla medida permaneció idéntica: 19 filas,
7 columnas y huella MD5 `6a7b920afcf878efb52a2b6d68220610`. La documentación de
`ra_environment_anchor()` enumera los cuatro campos comparados y declara que lo no identificable
es una discrepancia; la regeneración de Roxygen modificó solamente
`man/ra_environment_anchor.Rd`.

### §9.3. Lo medido después de la reparación

El oráculo de entornos terminó con 0 fallos en `home`, `oldrel`, `release_nolibm` y
`other_arch`. Los tres escenarios no locales registraron una discrepancia cada uno. El control
positivo conservó el ancla coincidente, sustituyó la ruta por una correctamente redondeada y
produjo 2 fallos, de modo que las dos afirmaciones de máquina siguen mordiendo donde tienen
razón de ser; el resultado agregado fue `ORACLE_ENV PASS`.

Los dos archivos de prueba tocados terminaron con `TOUCHED FAILED 0 ERRORS 0`. La suite completa
que reproduce CRAN en R 4.6.1 sin doble largo y sin Rmpfr confirmó `long.double FALSE` y terminó
con `SUITE FAILED 0 ERRORS 0`. El dato regenerado respondió `ANCHOR_ARCH TRUE`. No se cambiaron
la tabla de centinelas, las holguras, el nivel rápido ni la degradación.

---

## §10. La procedencia del veredicto sale de las evaluaciones que lo sostienen

La tarjeta de `ra_solve()` degradaba todos los veredictos cuando Rmpfr no estaba disponible.
`.ra_finish_paving()` iniciaba `verified` con la mera presencia del paquete y, al ensamblar el
resultado, reemplazaba la procedencia de cada certificado por `measured` si el paquete faltaba.
La premisa era falsa: en el nivel rápido, `+`, `-`, `*`, `/` y las potencias enteras ya producen
encierros cuya procedencia es `theorem`; son las funciones elementales las que producen
`measured`, porque dependen de la holgura medida de la biblioteca matemática.

La reparación conserva en cada caja la procedencia de la evaluación que permite excluirla o
mantenerla, y conserva el más débil al partir, inflar o fusionar cajas. El pase con Rmpfr no
cambió: vuelve a establecer rigurosamente cada certificado de unicidad y cada exclusión, y sólo
entonces les asigna `theorem`. Sin ese pase, el campo `verified` se deriva de la procedencia que
llevan los veredictos ensamblados; por eso vale `TRUE` cuando todos son teorema y `FALSE` cuando
alguno depende de una evaluación medida. La tarjeta declara la procedencia más débil del
empedrado, el resumen formula la misma condición y `as.data.frame()` deja de imponer
`measured` a toda abstención.

Antes de la reparación, el oráculo de procedencia sin Rmpfr terminó en `ORACLE_PROV FAIL`: los
casos `poly`, `cubic` y `rational` salieron `prov=measured` y `verified=FALSE`, mientras `sin` y
`mixed` conservaron correctamente esa procedencia medida. En el R del sistema con Rmpfr, los
cinco casos terminaron en `ORACLE_PROV PASS`, todos con `prov=theorem` y `verified=TRUE`.

Después de la reparación, el mismo oráculo sin Rmpfr terminó en `ORACLE_PROV PASS`: `poly`,
`cubic` y `rational` salieron `prov=theorem` y `verified=TRUE`, y `sin` y `mixed` permanecieron
`prov=measured` y `verified=FALSE`. Con Rmpfr, los cinco casos volvieron a terminar en
`ORACLE_PROV PASS`, todos como teorema. Las pruebas del resolvedor y sus portones terminaron con
`NEWTON FAILED 0 ERRORS 0`; la suite completa que reproduce CRAN en R 4.6.1 sin doble largo y
sin Rmpfr confirmó `long.double FALSE` y terminó con `SUITE FAILED 0 ERRORS 0`.

---

## §11. La preparación del reenvío 0.1.1 y sus verificaciones finales

La versión de `DESCRIPTION` pasó de 0.1.0 a **0.1.1** sin modificar ningún otro campo. `NEWS.md`
contiene una entrada por cada reparación aceptada en §8, §9 y §10 y declara sus consecuencias
visibles: la detención de `format()` cuando una cota no puede probarse, el costo medido de la
certificación decimal, el mensaje que aparece al adjuntar el paquete con `library()` o `require()`
en los sistemas cuyo `getconf` no identifica la biblioteca de C, el campo nuevo `platform` y las
etiquetas nuevas de la tarjeta y el resumen de `ra_solve()`. Los comentarios para CRAN identifican
el archivo fuente 0.1.1, declaran los entornos de prueba y responden por separado a
`r-oldrel-macos-arm64`, `r-oldrel-macos-x86_64`, `M1mac` y `noLD`.

### §11.1. Los tres chequeos naturales dentro del recinto

Los tres chequeos construyeron de manera independiente el archivo fuente 0.1.1 y ejecutaron
`R CMD check --as-cran`. Los registros identifican Fedora Linux 44 y R 4.6.1 en todos los casos;
la compilación del sistema usa la plataforma `x86_64-redhat-linux-gnu`, mientras que la compilación
sin doble largo usa `x86_64-pc-linux-gnu`.

| configuración | paquetes sugeridos | resultado |
| --- | --- | --- |
| R del sistema | obligatorios y disponibles | `Status: OK` |
| R sin doble largo, con Rmpfr en su biblioteca auxiliar | obligatorios y disponibles | `Status: OK` |
| R sin doble largo, sin Rmpfr | no obligatorios | `Status: OK` |

En el primer intento, los tres registros habían terminado con `Status: 1 NOTE` porque el recinto
no podía consultar por red una hora externa. La adjudicación enmendó únicamente esa causa mediante
`_R_CHECK_SYSTEM_CLOCK_=false`: la comparación remota del reloj quedó apagada, mientras que la
instalación, los ejemplos, las pruebas, la reconstrucción de las viñetas y las versiones PDF y HTML
del manual se ejecutaron y quedaron en estado `OK` en los tres registros. No se rebajó el resultado
exigido ni se aceptó la nota como si fuera éxito.

### §11.2. La repetición fuera del recinto y con red

La adjudicación repitió los tres chequeos sobre el mismo árbol, con una construcción independiente
para cada uno, acceso a red y sin definir `_R_CHECK_SYSTEM_CLOCK_`. Las comprobaciones remotas de
entrada permanecieron apagadas para conservar la misma matriz; la verificación remota del reloj sí
se ejecutó. Los tres resultados volvieron a ser `Status: OK`.

| configuración | comprobaciones remotas de entrada | resultado | segundos |
| --- | --- | --- | ---: |
| R del sistema, sugeridos obligatorios | apagadas | `Status: OK` | 48 |
| R sin doble largo, con Rmpfr | apagadas | `Status: OK` | 40 |
| R sin doble largo, sin Rmpfr y con sugeridos no obligatorios | apagadas | `Status: OK` | 36 |
| R del sistema, sugeridos obligatorios | encendidas | `Status: 1 NOTE` | 59 |

El cuarto chequeo encendió también las comprobaciones remotas de entrada. Su única nota fue la de
factibilidad de CRAN: `Days since last update: 1`. El intervalo de un día se explica porque 0.1.1
corrige las fallas que las verificaciones de CRAN informaron el 2026-09-12; no apareció ninguna
nota sobre el contenido, la instalación, las pruebas, las viñetas ni los manuales del paquete.

### §11.3. La suite, el archivo fuente y el límite de esta unidad

La suite completa con todos los portones se ejecutó en el R del sistema, con `NOT_CRAN=true`, y
terminó con `SUITE_ALLGATES FAILED 0 ERRORS 0`. La corrección posterior modifica solamente
`NEWS.md`, `cran-comments.md` y esta sección: el primero entra en el archivo fuente, pero ninguno
es leído por la suite. Por eso los tres chequeos naturales se repiten sobre el texto final y la
suite no se vuelve a correr; un control separado comprueba que ningún archivo leído por ella o por
la construcción, salvo `NEWS.md`, haya cambiado desde la adjudicación.

El control de metadatos devuelve `VERSION_OK` y confirma el encabezado
`# RobustArithmetic 0.1.1`. El archivo fuente construido contiene una copia de `NEWS.md` y ningún
directorio `_problems`, archivo `testthat-problems` ni resto `.Rcheck`; el resultado literal es
`NEWS_IN 1 DEBRIS 0`. El control de los comentarios encuentra las cuatro configuraciones y devuelve
`FLAVORS 4`.

### §11.4. La exactitud de los dos textos publicables

La descripción del motor decimal distingue ahora sus dos piezas. El motor decide el lado mediante
el significando decimal exacto y una cota de error derivada del escalado, y declina cuando esa cota
no certifica el resultado; la aritmética entera exacta pertenece al referente independiente de las
pruebas, que reconstruye el doble binario desde su representación hexadecimal. `NEWS.md` registra
además que la mediana de mil intervalos pasó de 1,171 a 1,805 segundos, un 54 %, y que `format()` se
detiene con un error si no puede probar contención y estrechez de un paso.

El texto del ancla atribuye a las pruebas, y no a las salvaguardas, las afirmaciones condicionadas
sobre la ruta de `sin()`. También declara que `ra_environment_anchor()` devuelve `platform` y que,
en macOS y Windows, donde `getconf` no identifica la biblioteca de C, el mensaje de ancla distinta
aparece al adjuntar el paquete con `library()` o `require()`. La salida de `ra_solve()` queda
nombrada con sus rótulos literales: `verdict provenance` en la tarjeta y
`Theorem provenance for every verdict` en el resumen.

No se modificaron el código, las pruebas, la documentación de funciones, los datos, el espacio de
nombres, la licencia ni ningún campo restante de `DESCRIPTION`. Esta unidad tampoco ejecutó
operaciones de git ni envió o publicó el paquete; deja en disco el archivo fuente y los tres
registros para su comprobación antes del reenvío.

---

## §12. El rechazo de Windows completa la matriz de degradación del nivel rápido

El pretest de CRAN del 2026-09-14 aceptó el contenido del paquete en Debian con una única nota de
factibilidad, `Days since last update: 2`, pero Windows Server 2022, con R-devel 4.7.0 ucrt, terminó
la suite en `[ FAIL 1 | WARN 186 | SKIP 26 | PASS 625 ]`. El único error apareció en
`test-newton.R`, en la prueba de procedencia de los veredictos rápidos: `.ra_fast_gate()` lanzó la
condición `ra_fast_level_unsafe` cuando la propia prueba había simulado que Rmpfr no estaba
disponible.

### §12.1. El mecanismo observado y la causa de método

Los centinelas de carga pasaron en Windows, pero la auditoría del primer uso rápido midió las rutas
de seno y coseno por encima de sus holguras. Esa medición degradó el nivel rápido para el resto de
la sesión. Mientras Rmpfr seguía visible, cada operación elemental escaló al nivel riguroso y emitió
la advertencia prevista; luego la prueba de procedencia ocultó Rmpfr para distinguir los veredictos
aritméticos de los elementales, pero dejó vigente la degradación de la sesión. La compuerta aplicó
entonces C-54(c): sin un nivel riguroso al cual escalar, rehusó devolver un encierro. El error no
estaba en la compuerta ni en la regla de degradación, sino en una prueba sobre la contabilidad de
procedencia que había heredado un hecho contingente de la máquina.

La matriz de verificación del reenvío ya combinaba el R del sistema, un R compilado sin doble largo
y la presencia o ausencia de Rmpfr, pero no incluía una biblioteca matemática que activara la
degradación. Por eso el defecto nuevo pasó todas las verificaciones locales. Al agregar ese eje, la
medición de partida reprodujo el error de Windows en `windows_sys`, `loaddeg_sys` y
`windows_nold_mpfr`, y reveló catorce errores en `loaddeg_nold_nompfr`, una configuración sin doble
largo, sin Rmpfr y con el nivel rápido degradado desde la carga. La causa de método fue, por tanto,
una matriz incompleta: verificaba la disponibilidad de niveles, pero no el estado de la compuerta
que decide si esos niveles pueden usarse.

### §12.2. Un único ayudante separa las propiedades del código del estado de la máquina

`tests/testthat/helper-fast-level.R` introduce `hold_fast_level_open()`. El ayudante guarda
`fast_degraded`, `fast_audited` y `fast_audit`; abre el nivel rápido fijando, respectivamente,
`FALSE`, `TRUE` y `NULL`; y devuelve una función que restaura exactamente los tres valores al salir
de la prueba. Marcar la auditoría como ya realizada es tan necesario como limpiar la degradación:
si sólo se limpiara esta última, el primer uso podría volver a degradar el nivel durante la misma
prueba. Los sitios que antes mantenían abierto el nivel mediante asignaciones propias —la escalera
de `test-elementary.R` y las dos pruebas S3 de `test-safeguards.R`— usan también el ayudante. Las
asignaciones manuales que permanecen en `test-safeguards.R` no son una segunda forma de abrir el
nivel: una fuerza la degradación para probar S5 y la otra limpia la sesión para probar que S2
ejecuta y conserva la auditoría.

Las catorce pruebas que fallaban bajo degradación mantienen ahora abierto el nivel rápido durante
su propio bloque. Ninguna afirma que el error de la biblioteca matemática esté dentro de la
holgura: las propiedades y sus referentes son los siguientes.

| archivo y prueba | propiedad afirmada | independencia de la holgura de la máquina |
| --- | --- | --- |
| `test-elementary.R`, CP-3 | La clase de `cosh` conserva el mínimo interior de uno y evita el encierro obtenido al tratarla como creciente. | El mínimo es exacto y las demás comparaciones usan la misma ruta ordinaria a ambos lados; no se contrasta su error con un valor multiprecisión ni con la holgura. |
| `test-elementary.R`, CP-4 | El encierro de `sin` incluye el máximo interior exacto y no se reduce a las evaluaciones de los extremos. | El control decisivo es el máximo exacto de uno; el barrido auxiliar usa la misma evaluación ordinaria y no asevera su exactitud. |
| `test-elementary.R`, CP-5 | Un intervalo que cruza un polo de `tan` produce el intervalo entero con decoración trivial, mientras uno alejado conserva decoración común. | El cruce del polo, la decoración y la inversión de signos son propiedades estructurales; no se mide el error en unidades de último lugar. |
| `test-elementary.R`, CP-6 | Los dominios parciales o vacíos de `log` y `asin` producen intervalos y decoraciones válidos, nunca un valor indeterminado silencioso. | Las afirmaciones conciernen al dominio, infinitos, ausencia de valores faltantes y decoraciones; `log(2)` se compara por la misma ruta ordinaria. |
| `test-elementary.R`, argumento acotado de `com` | La decoración común exige un argumento acotado aunque el recorrido de la función sea acotado. | La prueba interroga la decoración y los extremos estructurales de `atan`; no juzga la exactitud de la biblioteca. |
| `test-elementary.R`, extremos exactos | Los extremos matemáticos conocidos de `sin`, `cosh` y `sqrt` no consumen holgura. | Las ramas examinadas devuelven exactamente `-1`, `0` o `1`; no dependen de una evaluación aproximada de la biblioteca. |
| `test-elementary.R`, intervalo puntual | Cada evaluación ordinaria queda dentro del encierro y éste gasta exactamente los pasos declarados. | El referente es la propia evaluación ordinaria y los límites se construyen con antecesores y sucesores; se prueba la aplicación de la holgura, no que ésta cubra el error matemático. |
| `test-elementary.R`, tamaño del lote | La evaluación vectorial y la evaluación elemento por elemento producen el mismo extremo inferior. | Ambos lados usan la misma biblioteca y la misma ruta del paquete; la igualdad no presupone que el resultado sea correctamente redondeado. |
| `test-elementary.R`, vacío y no intervalo | Los objetos vacío y no intervalo conservan su identidad y decoración a través de la capa elemental. | Son reglas de propagación de estados y no realizan una afirmación sobre el error de una función matemática. |
| `test-elementary.R`, vectorización | La capa elemental conserva longitud, contención por su propia ruta y la posición vacía. | La contención auxiliar usa `exp(1)` de la misma ruta ordinaria; longitud y propagación son discretas y ninguna afirmación compara contra la holgura. |
| `test-elementary.R`, frontera periódica | La pérdida de resolución de una caja periódica sigue la granularidad del formato y aún existe un testigo más estrecho que el recorrido completo. | Se comparan exponentes, anchuras y el testigo construido por la propia maquinaria; no se asevera una cota de error de la biblioteca. |
| `test-expression.R`, potencia general | Una potencia no entera exige base positiva y debilita la decoración fuera de su dominio, mientras la potencia entera conserva la ruta ajustada. | Las cotas usadas son los valores exactos `0`, `1`, `2` y `16`, junto con decoraciones; no interviene una medición de la biblioteca. |
| `test-newton.R`, paso de Hansen-Sengupta | Un paso sobre `exp(x)-2` produce un intervalo interior que contiene la raíz representada por `log(2)`. | La raíz de referencia y las evaluaciones del encierro usan la ruta ordinaria del mismo proceso; se prueban clase, contracción y contención, no el cumplimiento de la holgura frente a un referente externo. |
| `test-newton.R`, procedencia de veredictos | La aritmética conserva procedencia de teorema y las funciones elementales conservan procedencia medida, también en tarjetas, resúmenes, ausencias y abstenciones. | Las afirmaciones son etiquetas lógicas derivadas de las operaciones ejecutadas; los valores numéricos sólo hacen recorrer las ramas y no se comparan con una verdad multiprecisión. |

La degradación real continúa probándose por separado y sin ninguna condición: S5 fuerza el estado
degradado y exige advertencia con escalamiento cuando Rmpfr está disponible o rechazo tipado cuando
no lo está; S2 fuerza una sesión limpia y comprueba que el primer uso audite, guarde el resultado y
no vuelva a medirlo. De este modo, mantener abierto el nivel en las pruebas de su maquinaria no
debilita las salvaguardas que deciden cuándo cerrarlo en una sesión real.

### §12.3. El arnés permanente y la medición posterior

`dev/check_scenarios.sh` construye un archivo fuente independiente, instala el paquete en
bibliotecas bajo un directorio de salida nuevo y ejecuta la suite instalada como la ejecuta CRAN.
Sus archivos de apoyo viven en `dev/scenarios/`. La matriz contiene ocho escenarios: sistema sano,
ancla distinta, auditoría de sesión al estilo de Windows y degradación desde la carga en el R del
sistema; y las cuatro contrapartes necesarias en el R sin doble largo, con Rmpfr para la condición
sana y la de Windows, y sin Rmpfr para el ancla distinta y la degradación de carga. Una sonda
separada comprueba en cada corrida la biblioteca instalada, la presencia de Rmpfr, el estado de
degradación, la discrepancia del ancla y si el resolvedor devolvió o rehusó un resultado. El arnés
cuenta además los ocho escenarios y no puede terminar en `SCENARIOS PASS` si alguno no corrió.

Después de la reparación, los ocho escenarios terminaron con cero fallos y veredicto `OK`. Los
seis escenarios con Rmpfr conservaron 26 saltos; los dos escenarios sin Rmpfr conservaron 42. Las
advertencias de `windows_sys`, `loaddeg_sys` y `windows_nold_mpfr` bajaron de 186 a 50 porque las
pruebas de la maquinaria rápida ya no atraviesan una compuerta degradada; las advertencias restantes
corresponden a llamadas que sí ejercitan el comportamiento degradado. La comparación bloque por
bloque confirmó `O2 PASS inadmissible=0 admitted=0`: ninguna prueba falló, se saltó ni ejecutó menos
expectativas que su referencia.

El arnés permanente terminó en `SCENARIOS PASS` sobre el árbol reparado. Como control negativo, el
mismo arnés terminó en `SCENARIOS FAIL`, con salida uno, sobre la copia intacta de `d26cd6e`, y nombró
cuatro veces `test-newton.R:112`; por tanto, el arnés no sólo atraviesa la matriz sino que muerde el
defecto que motivó esta unidad. La suite completa con todos los portones terminó en
`SUITE_ALLGATES FAILED 0 ERRORS 0 SKIPPED 2`, con la misma cantidad de saltos que la medición de
partida. No se modificaron la compuerta, las salvaguardas, los centinelas, las holguras, el ancla, el
código del paquete ni su documentación de referencia.

---

## §13. La copia sellada de CORE-MATH incorpora el referente correctamente redondeado

El paquete incorpora las implementaciones binarias de doble precisión de CORE-MATH para
`exp`, `log`, `sin`, `cos`, `tan`, `sinh`, `cosh`, `tanh`, `expm1`, `log1p`, `log2`,
`log10`, `asin`, `acos` y `atan`, tomadas del commit sellado
`1ab68b70b90f807fd2bc9cf20ec295d49ae09592`. La raíz cuadrada se evalúa con la operación de
hardware. Esta unidad sólo incorpora y verifica ese núcleo: el nivel rápido continúa usando la
biblioteca matemática del sistema, y no cambiaron sus holguras, sus centinelas, el ancla ni las
reglas de degradación.

La causa de la incorporación es la ruta heterogénea que quedó medida en Windows. Ocho de las
dieciséis funciones usadas por el paquete no llegan a la biblioteca matemática de la biblioteca
universal de C, sino que R las lleva compiladas desde `libmingwex`; esa ruta usa instrucciones x87,
no tiene cifras públicas de exactitud binaria de doble precisión y produjo errores de seno y
coseno mayores que la holgura declarada. Llevar un núcleo correctamente redondeado dentro del
paquete elimina esa dependencia de plataforma en la capa que la unidad siguiente conectará.

### §13.1. La copia y sus modificaciones locales

`dev/core-math/UPSTREAM` fija el repositorio, el commit, la fecha del archivo y las sumas SHA-256
del archivo comprimido y de su licencia. `dev/core-math/FILES` relaciona cada una de las dieciocho
fuentes y cabeceras copiadas, más la copia de la licencia, con su ruta dentro del archivo sellado.
`dev/core-math/import.sh` rehúsa una fuente cuya suma no coincida y reconstruye esos diecinueve
archivos en un directorio nuevo. `inst/COPYRIGHTS` registra para cada archivo su origen, titular y
modificaciones, y reproduce íntegramente la licencia MIT.

Las modificaciones locales pertenecen a las cuatro clases autorizadas. En los quince fuentes se
quitó el bloque que silenciaba pragmas desconocidas y se sustituyó `STDC FENV_ACCESS` por un
comentario inerte. Las declaraciones `_BitInt(128)` de seno, coseno, tangente y las tres cabeceras
`dint.h` se marcaron con `__extension__`, de modo que C17 no las diagnostique y C23 conserve el
mismo tipo. Los archivos y las inclusiones se aplanaron con nombres `coremath_*`, las guardas de
las tres cabeceras se aislaron por función y los símbolos públicos `cr_*` pasaron al espacio
`ra_cr_*`. No se modificaron algoritmos, constantes ni ramas matemáticas, y
`CORE_MATH_SUPPORT_ERRNO` permanece sin definir.

El código propio registra una única rutina de llamada, impide la búsqueda dinámica de símbolos y
expone dentro del espacio de nombres de R el evaluador `.ra_cr(fun, x)`. El evaluador acepta dobles
e enteros, descarta atributos, conserva por separado valores ausentes y valores indeterminados, y
rehúsa nombres de función o entradas ajenos al contrato. Ningún símbolo definido por la biblioteca
compartida queda fuera de `R_init_RobustArithmetic` y del prefijo `ra_`.

### §13.2. Los casos embebidos provienen del referente independiente

`tests/testthat/core-math-cases.csv` contiene 128 entradas por función y 2.048 en total, como
patrones hexadecimales exactos de IEEE 754. Para cada función de CORE-MATH se tomaron cien
posiciones equiespaciadas del conjunto de casos difíciles y veintiocho posiciones equiespaciadas
de la muestra construida con semilla 20260914. Para `sqrt`, que no tiene conjunto de casos
difíciles en CORE-MATH, se tomaron 128 posiciones equiespaciadas de esa muestra. Tanto las entradas
como las salidas se leyeron de las referencias calculadas con MPFR 4.2.2; ninguna salida esperada
se obtuvo del código bajo prueba. La comparación conserva el signo de cero y es exacta en bits,
con la única excepción declarada de que no atribuye significado al contenido interno de un valor
indeterminado.

### §13.3. Lo medido sobre la integración

La reconstrucción desde el archivo sellado terminó con diecinueve archivos reproducidos y cero
discrepancias. Las diecisiete unidades de compilación terminaron con cero avisos y cero fallos bajo
GCC en C17 y C23, y bajo Clang 21 para Linux x86_64 y macOS arm64. Las tres construcciones del
oráculo de redondeo, la configuración de fábrica, `-march=x86-64-v3` y `-O0`, compararon en cada
caso 73.131.510 entradas distribuidas entre los 32 conjuntos de referencia y terminaron con cero
conjuntos discrepantes; las tres conservaron además la tabla de símbolos limpia. La construcción
de R 4.6.1 sin doble largo repitió las 73.131.510 comparaciones y también terminó con cero conjuntos
discrepantes. El contrato del evaluador pasó sus 104 comprobaciones, y el control de procedencia de
los casos confirmó las 128 filas de cada función y al menos cien casos difíciles por función, o
las 128 entradas de muestra exigidas para la raíz cuadrada.

La suite completa con todos los portones terminó en
`SUITE_ALLGATES FAILED 0 ERRORS 0 SKIPPED 2`; la variante de R sin doble largo y sin Rmpfr terminó
en `SUITE_NOLD FAILED 0 ERRORS 0`. El arnés permanente de ocho escenarios conservó
`SCENARIOS PASS`.

Dos de los tres chequeos naturales terminaron en `Status: OK`: R sin doble largo con Rmpfr y R sin
doble largo sin paquetes sugeridos. El chequeo con el R del sistema terminó en `Status: 1 NOTE`.
Su único diagnóstico enumeró `-Werror=format-security`, las definiciones de fortalecimiento de
Fedora, `-march=x86-64`, `-mno-omit-leaf-frame-pointer` y `-mtls-dialect=gnu2`; son componentes
literales de `R CMD config CFLAGS` en esta instalación y no banderas agregadas por el paquete. Una
copia temporal con `CFLAGS` vacío en `Makevars` confirmó que intentar neutralizarlas desde el
paquete agrega una advertencia por sustituir la configuración del usuario y no elimina la nota.
La repetición diagnóstica que declaró como conocidas las banderas devueltas por
`R CMD config CFLAGS`, sólo para el chequeo del R del sistema, terminó en `Status: OK`. Por eso la
integración queda implementada y sus pruebas funcionales quedan en verde, pero el oráculo de los
tres chequeos no satisface su resultado esperado hasta que su comando reconozca las banderas
propias del R anfitrión sin ocultar ninguna bandera que agregue el paquete.

---

## §14. El nivel rápido usa el núcleo correctamente redondeado que viaja con el paquete

El nivel rápido evalúa ahora las dieciséis funciones por la ruta incluida en el paquete: las
quince funciones binarias de doble precisión de CORE-MATH tomadas del commit sellado
`1ab68b70b90f807fd2bc9cf20ec295d49ae09592`, y la raíz cuadrada de hardware. El evaluador
interno `.ra_cr()` reemplaza en `.ra_eval_pts()` la evaluación ordinaria de R, también para los
argumentos no finitos que no pasan al nivel multiprecisión. `ra_measure_library_error()` conserva
su nombre, firma y referente independiente, pero mide esa misma ruta incluida contra MPFR; la
verificación de monotonía conserva deliberadamente las funciones de R, porque comprueba las clases
matemáticas de forma y no la exactitud de la ruta rápida.

Las dos magnitudes materiales salen de fuentes anteriores al resultado. CORE-MATH declara redondeo
correcto, que fija una cota de medio paso de último lugar para sus quince funciones, y el estándar
IEEE 754 exige la misma propiedad a la raíz cuadrada. Sobre `e = 0,5` se aplica literalmente la
fórmula pre-registrada `ceiling(2e + 1)`, cuyo resultado es una holgura de dos vecinos binarios para
las dieciséis. La procedencia permanece `measured`: las pruebas difíciles y las comparaciones bit a
bit sostienen la afirmación de redondeo correcto, pero esta integración no establece un teorema
función por función.

La primera conexión reveló una distinción entre el número declarado de vecinos y la cantidad que
puede consumir la fórmula aritmética de antecesor o sucesor. Repetirla dos veces dentro de las dos
binadas que rodean el umbral subnormal llegó a mover cuatro vecinos exactos, porque cada aplicación
puede adelantarse uno en esa franja; `O_FASTEXACT` encontró entonces 17 conjuntos fuera del
presupuesto. El ensanchador cuenta ahora cada aplicación por su costo máximo demostrado: uno fuera
de la franja y dos dentro de ella, y se detiene si otra aplicación excedería el presupuesto. No se
cambió la fórmula de la holgura ni las primitivas generales de redondeo.

Antes de esta unidad, `O_FASTEXACT` fallaba en 31 de los 32 conjuntos, `O_TABLE` producía cinco
señalamientos y había medido hasta 1,987 pasos de error en la ruta de la plataforma, mientras
`O_DOCS` encontraba 16 afirmaciones que todavía describían esa ruta. Después de la reparación,
`O_FASTEXACT` terminó con cero violaciones en los 32 conjuntos; `O_TABLE` confirmó medio paso como
cota declarada, holgura dos para las dieciséis, monotonía concordante y un máximo observado de
0,499999; `O_DOCS` terminó con cero hallazgos. `O_CR3` volvió a comparar 73.131.510 entradas en cada
una de sus tres compilaciones y conservó cero conjuntos discrepantes. La tabla, la ayuda, la
viñeta, el título, la descripción y las pruebas afectadas nombran la ruta incluida y su fuente en
presente, sin trasladar a la exposición pública la cronología de la sustitución.

---

## §15. Las salvaguardas verifican la ruta incluida y comunican el estado de la sesión

El nivel rápido verifica al cargar el paquete el evaluador que efectivamente usa. La tabla
incorporada contiene 128 centinelas, ocho por cada una de las dieciséis funciones: los de las
quince funciones de CORE-MATH proceden de los casos difíciles del archivo sellado del commit
`1ab68b70`, mientras los de la raíz cuadrada proceden de la muestra binaria sellada. El guion
`dev/gen_sentinels.R` selecciona las entradas de manera determinista, calcula los valores esperados
con Rmpfr a 200 bits y los convierte una sola vez a doble precisión; nunca obtiene una salida
esperada de `.ra_cr()`. `ra_check_sentinels()` compara luego ambos patrones binarios bit a bit.

La degradación es un estado de la sesión. `.onLoad()` borra y reconstruye ese estado, de modo que
su ejecución repetida vuelve a verificar desde cero. `ra_fast_level_status()` expone si el nivel
está degradado, el motivo, la comprobación de centinelas y la auditoría del primer uso. Con Rmpfr,
el primer resultado afectado emite una única condición `ra_fast_level_unsafe` y se recalcula por la
ruta rigurosa con procedencia `theorem`; sin Rmpfr, cada evaluación afectada rehúsa mediante un
error de la misma clase. Una sesión sana permanece silenciosa tanto al cargar el espacio de nombres
como al adjuntar el paquete.

El arnés permanente construye e instala el paquete y combina dos controles que no se sustituyen.
La sonda recorre el estado público y las dieciséis funciones en procesos nuevos; la suite instalada
se ejecuta además en los estados sano y degradado durante la carga, tanto con el R del sistema y
Rmpfr como con el R sin doble largo y sin Rmpfr. Los escenarios que dejan roto el evaluador son
controles de la sonda y no de una suite que debe afirmar redondeo correcto. Dos escenarios
adicionales cargan el espacio de nombres sin adjuntar el paquete, para conservar la comprobación de
que el aviso aparece una sola vez también mediante `::`.

La retirada completa del ancla de entorno eliminó el único uso funcional de `compiler`. Por eso
`DESCRIPTION` declara ahora solamente `stats` en `Imports`; conservar `compiler` mediante una llamada
ceremonial habría ocultado una dependencia obsoleta sin responsabilidad en el mecanismo vigente. No
cambian la holgura, la procedencia, el nivel riguroso, el evaluador `.ra_cr()`, la copia de CORE-MATH
ni sus referencias independientes.

La verificación de cierre exige que pasen los controles de salvaguardas, centinelas, documentación,
exactitud rápida, tres compilaciones, límites del cambio, las dos suites y los escenarios; que los
tres chequeos naturales terminen en `Status: OK`; que ninguna prueba ni archivo de `R/` lea
`RA_SCENARIO`; y que esta sección exista una sola vez. Los oráculos adicionales del arnés comprueban
por separado que los seis escenarios de raíz están presentes, que las cuatro suites instaladas
terminan sin fallos y que ningún bloque ejecutado del manifiesto sellado se pierde bajo degradación.
