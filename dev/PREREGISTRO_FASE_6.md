# PRE-REGISTRO — FASE 6: CERTIFICADOS DE PUNTO FIJO POR BOLA DE NORMA

**Escrito el 2026-08-20 (sesion 08 de HERACLITUS, Opus, esfuerzo Max), ANTES de la primera linea de
`R/ball-certificate.R` y antes de la primera linea de sus tests.** Continua la disciplina de
`PREREGISTRO_FASE_2.md` y `PREREGISTRO_FASE_5.md`: las enmiendas se escriben a la vista y fechadas,
nunca tapando lo anterior.

**De donde sale esta fase.** La C-21 de HERACLITUS necesita convertir una **envolvente de estabilidad
medida** —el largo de trayectoria que el 95 % de las trayectorias sostiene sin que el punto fijo del
integrador implicito aborte— en un **certificado**. La via intervalar tiene la doctrina entera para eso
(VI.3: confinamiento por Brouwer e invariancia/contraccion por Banach, certificados POR SEPARADO, con la
frontera doctrinal escrita), pero lo que hay construido es **univariado**: `ra_newton_step()` PARA con
`length(x) != 1` y en los 55 exports no hay una sola operacion de matrices. Los puntos fijos que la C-21
tiene que certificar viven en `R^48` y `R^96`.

**Lo que esta fase agrega, y lo que deliberadamente NO agrega.** Agrega el certificado por **bola de
norma**, que es una desigualdad ESCALAR y por lo tanto se apoya entero en el sustrato ya portoneado.
**No** agrega aritmetica matricial intervalar, ni factorizaciones, ni el operador de Krawczyk
multivariado: el metodo de esta fase es precisamente el que **evita** necesitarlos.

---

## 1. EL ALGEBRA, VERIFICADA EN PAPEL — CAPA ALGEBRAICA

Las tres capas de rigor se mantienen separadas y esta seccion es **enteramente algebraica**: lo que
sigue no depende de ninguna medicion, y si algo de aca esta mal, nada de las capas de abajo lo salva.

### 1.1. El teorema, con sus hipotesis explicitas

Sea `Phi: R^n -> R^n` continua, `B = { x : ||x - c|| <= r }` la bola cerrada de centro `c` y radio
`r > 0` en una norma cualquiera, y supongamos conocidas dos cotas SUPERIORES:

- **el residuo en el centro**, `rho >= ||Phi(c) - c||`;
- **una constante de Lipschitz sobre la bola**, `L >= sup_{x,y en B, x != y} ||Phi(x)-Phi(y)|| / ||x-y||`.

**(T1) Confinamiento.** Si `L*r + rho <= r`, entonces `Phi(B) subset B`.

*Demostracion.* Para `x` en `B`: `||Phi(x) - c|| <= ||Phi(x) - Phi(c)|| + ||Phi(c) - c|| <=
L*||x - c|| + rho <= L*r + rho <= r`. Cada paso es desigualdad triangular, definicion de `L`,
`||x-c|| <= r`, e hipotesis. QED.

**(T2) Existencia — Brouwer.** Si ademas `Phi` es continua, `B` es convexo, compacto y no vacio, de
modo que `Phi(B) subset B` implica por el teorema del punto fijo de Brouwer que **existe al menos un
`x*` en `B` con `Phi(x*) = x*`**.

**(T3) Unicidad y convergencia — Banach.** Si ademas `L < 1`, entonces `Phi` restringida a `B` es una
contraccion de un espacio metrico completo en si mismo, de modo que el punto fijo es **UNICO en `B`** y
la iteracion `x_{k+1} = Phi(x_k)` converge a el desde cualquier `x_0` en `B`, con
`||x_k - x*|| <= L^k * ||x_0 - x*||`.

**(T4) La cota de error del centro, que es lo que se publica.** Si `L < 1`, tomando `x_0 = c` y pasando
al limite en `||c - x*|| <= ||c - Phi(c)|| + ||Phi(c) - x*|| <= rho + L*||c - x*||`, sale
**`||c - x*|| <= rho / (1 - L)`**. Vale decir que **el radio minimo certificable es
`r* = rho / (1 - L)`**, y que con `r >= r*` la hipotesis de (T1) se cumple sola: `L*r + rho <= r`
equivale a `r*(1-L) >= rho`, que es `r >= r*`.

**(T5) La cota a posteriori.** Con `L < 1` y dos iterados consecutivos,
`||x_k - x*|| <= L/(1-L) * ||x_k - x_{k-1}||`. Se ofrece porque es la forma en que un llamador que ya
itero mide su propio error sin volver a evaluar `Phi`.

### 1.2. Lo que el certificado NO dice, y se declara como no-objetivo

- **Una negativa NO es ausencia.** Las hipotesis de (T1)-(T3) son **suficientes y no necesarias**: hay
  mapas con punto fijo en `B` que este certificado rechaza. El caso limpio, que va como fixtura: una
  **rotacion** `Phi(x) = R x` en `R^2` tiene punto fijo en el origen y mapea toda bola centrada en el
  origen en si misma, pero su constante de Lipschitz es exactamente 1 y (T1) falla para todo centro
  distinto del origen. **Esta fase no tiene palabra de «ausencia demostrada»**, a diferencia del paving
  de la fase 4, que si la tiene porque tiene test de exclusion. Las palabras de esta fase son **dos**:
  certificado (y cual de los dos) o no certificado.
- **No se afirma nada sobre la cuenca de atraccion fuera de `B`**, ni sobre orbitas de periodo mayor,
  ni sobre lo que pasa cuando `L >= 1` (VI.3: el confinamiento certifica encierro; que pasa adentro no
  se afirma, y sin contraccion adentro puede haber ciclos o caos).
- **La norma es responsabilidad del llamador.** `rho` y `L` tienen que estar medidos en **la misma**
  norma; el objeto guarda el rotulo que el llamador declara y la documentacion lo dice en su primera
  linea. Mezclar normas en silencio seria un modo de falla invisible, que es exactamente lo que las
  salvaguardas de la 81 existen para no tener.
- **`L` tiene que ser cota sobre la BOLA ENTERA**, no en el centro. Un llamador que acote la derivada
  solo en `c` obtiene un certificado vacio y no lo sabria. La responsabilidad queda declarada en la
  pagina y en la tarjeta; y para el caso univariado, donde el paquete SI puede derivarla el mismo, se
  ofrece la puerta que la deriva y cierra el circulo.

### 1.3. El redondeo dirigido, que es donde una demostracion se pierde en la aritmetica

Las tres desigualdades se evaluan de modo que un veredicto afirmativo sea **demostrable**, o sea con
cada operacion redondeada en la direccion que hace la conclusion mas dificil:

| cantidad | como se evalua | por que |
| --- | --- | --- |
| `L*r + rho <= r` | miembro izquierdo con `sup(L)`, `sup(rho)` y **redondeo hacia arriba**; miembro derecho con `r` hacia abajo | si la version pesimista pasa, la verdadera pasa |
| `L < 1` | `sup(L) < 1`, comparacion exacta | un `L` que toca 1 no contrae |
| `r* = rho/(1-L)` | `sup(rho)` hacia arriba dividido por `(1 - sup(L))` **hacia abajo** | denominador mas chico ⇒ cociente mas grande ⇒ radio conservador |
| `L/(1-L) * d` | idem, con `d` la distancia entre iterados hacia arriba | idem |

**El `1 - sup(L)` hacia abajo tiene una trampa que se nombra**: si `sup(L)` esta a un ulp de 1, el
denominador puede redondear a cero y el cociente a infinito. Eso **no es un fallo**: es la respuesta
correcta —el certificado no se emite— y el objeto lo dice con la palabra, nunca con un `NA`.

### 1.4. Los dos ensambladores auxiliares, con su teorema

Los necesita todo llamador que tenga que acotar `||G^{-1}||` o el espectro de una matriz simetrica sin
poder factorizarla en intervalos.

**(T6) Gershgorin.** Si `A` es simetrica real de orden `m`, todo autovalor cae en la union de los
discos `[a_ii - R_i, a_ii + R_i]` con `R_i = sum_{j != i} |a_ij|`. Con entradas intervalares se toma
`sup` de los radios e `inf`/`sup` de las diagonales, y el resultado es un **superconjunto** del
espectro: puede ensanchar, no puede perder un autovalor. Referente: Horn y Johnson (2013), Teorema
6.1.1.

**(T7) Weyl.** Para `A`, `B` simetricas del mismo orden,
`lambda_min(A+B) >= lambda_min(A) + lambda_min(B)` y `lambda_max(A+B) <= lambda_max(A) + lambda_max(B)`.
Sirve para juntar un sumando cuyo espectro se conoce en forma cerrada con otro que solo se acota.
Referente: Horn y Johnson (2013), Teorema 4.3.1.

**Por que estos dos y no una descomposicion espectral intervalar.** Porque el problema que motiva la
fase se deja acotar sin ella. En el integrador riemanniano de HERACLITUS la metrica es
`G = K + bloqdiag SoftAbs(tau * H_V)`, con `K` constante en la posicion y de espectro cerrado; (T7) da
`lambda_min(G) >= lambda_min(K) + 1/alpha` porque el SoftAbs tiene piso `1/alpha` por construccion, y
de ahi `||G^{-1}||_2 <= 1 / lambda_min(G)` sin factorizar nada. Y la derivada de la metrica se acota
por la **formula de Daleckii-Krein**: `dF/dtheta = Q [ J .* (Q' (dA/dtheta) Q) ] Q'`, con
`J_kl = (sigma_k - sigma_l)/(lambda_k - lambda_l)`, de donde
`||dF/dtheta||_F = ||J .* (Q'(dA/dtheta)Q)||_F <= max|J_kl| * ||dA/dtheta||_F`, y por el teorema del
valor medio `max|J_kl| <= sup|sigma'| = 1` para el SoftAbs. **La descomposicion espectral desaparece de
la cota.** Esa ultima desigualdad esta asentada en la suite de HERACLITUS (bateria `pathrmhmc`, Q3);
aca no se usa ni se re-deriva: se nombra para que quede escrito por que esta fase alcanza.

---

## 2. LA SUPERFICIE

- **`ra_ball_certificate(rho, lipschitz, radius = NULL, norm = "unspecified")`** — el nucleo. `rho` y
  `lipschitz` son `ra_ivl` (o numericos, que se promueven). Con `radius = NULL` devuelve el radio
  minimo certificable `r*`; con `radius` dado, verifica ese radio. Objeto `ra_certificate` con los dos
  veredictos **por separado** (`confined`, `contraction`), el radio certificado, la cota de error del
  centro, `L` y `rho` usados, la norma declarada y la procedencia.
- **`ra_certify_fixed_point(e, center, radius, var = "x", env = list(), level, precision)`** — la
  puerta univariada que **deriva** `rho` y `L` ella misma: `rho` por evaluacion intervalar de
  `|Phi(c) - c|` y `L` por evaluacion intervalar de `|Phi'|` sobre la bola, con `stats::D` y
  `ra_enclose_expr()`. Cierra el circulo en 1-D y le da al porton un referente que no depende de
  numeros que ponga el llamador.
- **`ra_gershgorin(A)`** — (T6). Acepta matriz numerica o par de matrices `lo`/`hi`; devuelve el
  encierro del espectro y, opcionalmente, los discos.
- **`ra_spectral_sum(a, b)`** — (T7), sobre encierros de `lambda_min`/`lambda_max`.
- Y **todo lo que arrastra una clase, JUNTO** (§203.7 de QD): `format`, `print`, `as.data.frame`,
  `summary` con su clase `ra_summary_certificate` y su propio `format`/`print`, y la fixtura de
  impresion cuyo nombre empieza con el nombre de la clase.

**Condiciones tipadas nuevas** (lexico del paquete, ingles con glosa): `ra_bad_argument` ya existe y
cubre radio no positivo y longitudes incompatibles. No se inventan clases nuevas si las que hay
alcanzan.

---

## 3. LAS PREDICCIONES, CON SU NUMERO ESCRITO DE ANTEMANO

### P1 — El certificado contiene el punto fijo verdadero, y la cota de error no miente

Sobre **mapas afines** `Phi(x) = A x + b` en `R^n` con `||A||_inf < 1`, cuyo punto fijo es
`x* = (I - A)^{-1} b` y se computa **en MPFR a 300 bits** (referente externo que no comparte
aritmetica con el certificado): en las **200** instancias sorteadas (`n` de 1 a 8, entradas de
magnitudes dispares, semilla declarada), se predice

1. `||x* - c||_inf <= cota de error publicada` en **las 200**, sin una sola excepcion; y
2. el radio minimo `r*` cumple `L*r* + rho <= r*` re-evaluado, o sea que el radio que el objeto
   publica **se certifica a si mismo**.

**Un fallo de (1) es un fallo del teorema o de su aritmetica y detiene la fase entera.**

### P2 — El control que DEBE fallar, en sus tres formas

1. **La traslacion `Phi(x) = x + v`, que no tiene punto fijo en ningun lado**: `L = 1` exacto, de modo
   que ni confinamiento ni contraccion se emiten. Se predice **ningun certificado**, y por la razon
   correcta (`L` no menor que 1), no por una cuenta que dio `NA`.
2. **Radio insuficiente**: con `L < 1` y `radius` estrictamente menor que `r*`, se predice
   **confinamiento NO emitido**; y con `radius = r*`, emitido.
3. **`L` medido solo en el centro**: se construye a proposito un `L` que vale en `c` y no en la bola
   (mapa con derivada creciente), y se predice que el certificado **se emite igual** — porque el
   paquete no puede saberlo — **y que la puerta univariada, que deriva `L` sobre la bola, NO lo
   emite**. Es la demostracion de que la responsabilidad declarada en §1.2 es real y de que la puerta
   que cierra el circulo la levanta.

### P3 — Gershgorin y Weyl contra `eigen()`

Sobre **500** matrices simetricas sorteadas (`m` de 2 a 12, incluidas diagonales, casi degeneradas y
mal condicionadas): se predice que **todos** los autovalores de `eigen()` caen dentro del encierro de
`ra_gershgorin()`, sin excepcion; y que en las diagonales el encierro es **exacto** (los discos tienen
radio cero), que es el caso donde la cota es ajustada y por lo tanto el que distingue un Gershgorin
implementado de uno inventado. Para (T7), sobre **300** pares: `lambda_min(A+B) >= ra_spectral_sum()`
inferior en los 300.

### P4 — La aritmetica dirigida cambia el veredicto en el borde, y se mide

Se predice que existe al menos un caso construido donde el veredicto **con redondeo hacia afuera
difiere** del veredicto con aritmetica de doble ingenua, y que la diferencia va siempre en la direccion
conservadora: el certificado dirigido rechaza donde el ingenuo acepta, **nunca al reves**. Si no
apareciera ningun caso, la prediccion falla y hay que investigar si el redondeo esta entrando de veras.

---

## 4. EL PORTON 6

**Se cruza si y solo si**: P1 en las 200 sin excepcion; los tres controles de P2 disparan; P3 en las
500 y las 300 sin excepcion; P4 con su caso exhibido; la suite del paquete en verde con la cifra nueva
**explicada contra 835** (cada asercion nueva contada, ninguna vieja perdida); `R CMD check` natural
`Status: OK`; `R/` ASCII puro; APA 7 en el archivo nuevo; cero commits.

**Y lo que el porton NO admite como cierre**: que P1 pase con `n = 1` solamente. El objeto de esta fase
es el caso vectorial; una bateria que solo ejercita la dimension uno mediria otra cosa.

---

## 5. LO QUE ESTA FASE NO AUTORIZA

- No autoriza tocar `R/` de QuantDialectics. QD no consume nada de esta fase todavia.
- No autoriza aflojar ninguna de las cifras de los portones 0 a 5.
- No autoriza publicar un veredicto de HERACLITUS: la C-21 rediseñada se corre despues, con su propio
  pre-registro, y **la envolvente medida sigue siendo su contra-vara**.
- No autoriza commits.

---

## ENMIENDA E-1, 2026-08-20, ESCRITA ANTES DE LA PRIMERA LINEA DE CODIGO

**Lo que la encontro fue escribir los controles.** Al redactar la fixtura de «confinamiento sin
contraccion» que VI.3 exige poder distinguir, la cuenta no cierra: por la via de Lipschitz sola, la
condicion de (T1) es `L*r + rho <= r`, o sea `(1 - L)*r >= rho`. Con `rho > 0` eso **fuerza `L < 1`**,
que es exactamente la hipotesis de (T3). Vale decir que **el confinamiento implicaria la contraccion
salvo en la esquina degenerada `rho = 0` con `L = 1`**, y los dos certificados que el Bloque VI manda
emitir POR SEPARADO serian el mismo certificado con dos nombres.

**Por que el Bloque VI si los separa, y que es lo que faltaba.** En la lectura de mapa de QD el
confinamiento se establece **evaluando la imagen directamente** —`g([a,b]) subset [a,b]`—, no acotandola
por la desigualdad triangular. La evaluacion directa es genuinamente mas debil que la contraccion: una
imagen puede caber adentro de la caja con derivada mayor que uno. Lo que faltaba en §2 era **la puerta
para esa evaluacion directa**, que en dimension `n` es un tercer insumo escalar y no una matriz.

**La reparacion, y queda como diseño.** El nucleo toma **tres** insumos y no dos:

- `rho >= ||Phi(c) - c||`, el residuo en el centro, que es lo unico que (T4) necesita;
- `image_radius >= sup_{x en B} ||Phi(x) - c||`, **la via directa**, opcional;
- `lipschitz >= L` sobre la bola, **la via de Lipschitz**, opcional.

y las reglas quedan asi, cada una nombrando su teorema:

1. **Confinamiento** se certifica si `image_radius <= r` (via directa), **o** si `L*r + rho <= r` (via
   triangular de (T1)). La que decidio viaja en el objeto: un llamador tiene que poder saber si su
   certificado se apoya en una evaluacion o en una cota.
2. **Contraccion** se certifica si hay `L`, `L < 1` **y** el confinamiento esta certificado: Banach pide
   las dos cosas, y emitir unicidad sin invariancia seria afirmar mas de lo que el teorema da.
3. **`r* = rho/(1-L)`** existe solo por la via de Lipschitz. Un llamador que solo tiene `image_radius`
   tiene que proponer su `r`, y el objeto lo dice en vez de inventarle un radio minimo.

**La fixtura que la enmienda hace posible, y es la que faltaba**: `Phi(x) = x^2` sobre la bola de centro
`0,4` y radio `0,4`, o sea `[0; 0,8]`. Su imagen es `[0; 0,64]`, contenida — **confinamiento por
evaluacion directa** — mientras que `sup|Phi'| = 1,6` sobre la bola — **contraccion refutada**. Hay
punto fijo adentro (el origen) y la unicidad no se afirma. Es VI.3 en su forma vectorial: el
confinamiento certifica encierro, que pasa adentro no se afirma.

**P2 gana una cuarta forma**: se predice que esa fixtura da `confined = TRUE` y `contraction = FALSE`, y
que la tarjeta lo dice con las dos palabras. Si el confinamiento saliera `FALSE`, la via directa no
esta entrando; si la contraccion saliera `TRUE`, se esta afirmando unicidad sin teorema.
