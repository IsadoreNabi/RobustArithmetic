# PRE-REGISTRO — Fase 5: el enchufe en QuantDialectics

**Escrito el 2026-08-20, sesión 82, ANTES de la primera línea de código de la fase y antes de
correr cualquiera de las predicciones que siguen.** Gobiernan `BLOQUE_V_ARITMETICA_INTERVALAR.md`
(V.9, V.10), `BLOQUE_VI_LECTURA_DE_MAPA.md` (VI.1-VI.5) y `PAUTAS_EJECUCION_OPUS.md` (fase 5).

La regla que este archivo sirve: **lo escrito antes no se reinterpreta al ver los números**. Toda
enmienda va abajo, fechada, con la razón, y a la vista.

---

## 0. Las constantes de las que cuelga todo, leídas y no elegidas

| símbolo | qué es | de dónde sale | valor en esta máquina |
| --- | --- | --- | --- |
| `du` | tolerancia con que se ubica una raíz | `formals(stats::uniroot)$tol`, leída al usarse | `.Machine$double.eps^0.25` = 1,220703e-4 |
| `floor` | piso de toda derivada evaluada en doble | heurística reconocida y declarada, `eps^(2/3)` | 3,666852e-11 |
| `h` | paso de la diferencia central del backend | leído del fuente de EmpiricalDynamics 0.1.10 | 1e-6 |

Ninguno de los tres se escribe a mano en el código de la fase: los tres ya se leen así en
`R/structure-discovery.R` desde C-47, y la fase 5 los reusa **sin re-derivarlos**.

## 1. Qué se construye, en una frase por pieza

1. **Sonda y plantado limpio de `RobustArithmetic` en QD** — `qd_probe_namespace()`, el patrón del
   backend ED; el paquete entra en `Suggests` y en el bucket GUARDED del registro de capacidades.
2. **Tercera medición**: el **enclosure intervalar de `f'` sobre la caja en la que la raíz está
   ubicada**, `X = [x_hat - du, x_hat + du]`, calculado por `ra_enclose_expr()` sobre la MISMA
   expresión de la derivada que la lectura analítica evalúa en doble. Portón oráculo extendido por
   CONTENCIÓN (V.9).
3. **`semantics = c("flow", "map")`**, default `"flow"`, campo del objeto y argumento de los dos
   constructores; palabras de estabilidad del mapa con la resolución HEREDADA.
4. **Certificado de confinamiento** (VI.3): invariancia (Brouwer) y contracción (Banach) por
   separado, con la frontera doctrinal escrita.
5. **Fixturas obligadas de VI.2** y todo lo que arrastra clase y tarjeta, JUNTO (§203.7).

## 2. La caja de la tercera medición, y por qué es ésa y no otra

La cantidad que las tres mediciones miden es **el autovalor del estado**, y el estado mismo sólo se
conoce a `du`. Así que la tercera medición no encierra `f'(x_hat)` (que sería encerrar el número
que la segunda ya calcula) sino **el rango de `f'` sobre la caja donde la raíz está**, que es la
cantidad de la que las otras dos son aproximaciones puntuales. La caja es `[x_hat +/- du]` con el
`du` de la tabla de arriba: **derivado, no elegido**, y es el mismo número del que C-47 cuelga la
resolución de primer orden `|f''|*du + floor`.

De ahí la predicción P2, que es la que hace que esta pieza no sea un adorno: **el radio del
enclosure es la versión rigurosa de esa resolución de primer orden**.

## 3. Predicciones falsables, todas pre-registradas

### P1 — Contención (el portón oráculo extendido)

Sobre todo estado de toda lectura con `resolution_basis = "derived"` en la que la ruta intervalar
corra: **el valor del backend (diferencia central) y el valor analítico (derivada en doble) caen
DENTRO del enclosure**. Predicción: **100 % de los estados, cero excepciones.**

- Falla si sale UNO. Un fallo **no se repara ensanchando el enclosure**: se investiga, como la
  cifra de `sin` de la 80.
- El criterio puede fallar por los dos lados: si el enclosure saliera tan ancho que la contención
  fuese trivial, P2 lo cazaría (un radio muy por encima de `|f''|*du` es un enclosure flojo).

### P2 — El enclosure re-deriva la resolución de C-47

Sobre los **43 estados del barrido canónico C-48** (tres formas normales, `b = -1`,
`r` de -1 a 1 de a 0,25):

- **P2a.** Donde `f''(x_hat) != 0`: `| rad(E) / (|f''(x_hat)| * du) - 1 | <= 1e-9`.
  La igualdad es exacta y no aproximada en las tres formas, y la derivación es ésta: las tres
  derivadas son polinomios de grado <= 2 en el estado, y para `x^2` sobre `[c-d, c+d]` el ancho del
  rango es `4cd` exactamente, de modo que el término de segundo orden se cancela y
  `rad = |f''|*du` sin resto. Un cociente lejos de 1 quiere decir que la extensión natural está
  sobreestimando donde no debería, y eso es un defecto de la vía, no una cifra que se anota.
- **P2b.** Donde `f''(x_hat) = 0` (la resolución de primer orden se anula): `rad(E) <= floor`,
  o sea `<= 3,666852e-11`. Es lo que dice que el piso declarado **no está de adorno**: hay estados
  donde el término de primer orden es cero y el rigor todavía tiene un radio que dar
  (predicho: del orden de `1,5 * du^2 = 5,6e-14`, tres órdenes por debajo del piso).

### P3 — Las fixturas obligadas de VI.2, las tres que la sonda 5 encontró

Los autovalores **-2,000440**, **-2,000962** y **-2,000311**, que la lectura de flujo llama
`stable` (correcto en su semántica), **DEBEN salir bajo mapa con la palabra de la duplicación de
período** — `unstable (flip)` — y los dos que la sonda 5 encontró en (-2, -1,9] **DEBEN seguir
`stable` bajo mapa**, porque `|1 + f'| < 1` ahí.

Nota de honestidad escrita antes de medir: **el censo de la población B crecerá en esta sesión**,
porque las fixturas nuevas agregan autovalores al corpus. La cifra 153 de la sonda 5 no se
re-predice; lo que se predice son los tres valores nombrados y su palabra.

### P4 — El borde exacto -2 cae en abstención, con resolución y sin ella

Los **3 estados del borde exacto** del barrido A — silla `r = 1` en `x_hat = 1`, horquilla `r = 1`
en `x_hat = +/-1`, los tres con `f' = -2` exacto — **DEBEN caer en abstención** bajo mapa:

- **P4a.** Sin resolución ninguna (lectura armada de partes, comparación exacta): `|1 + f'| = 1`
  exactamente, y la palabra es la del borde de duplicación de período, nunca `stable` ni
  `unstable`.
- **P4b.** Con la resolución derivada: la misma palabra, porque una resolución sólo puede ensanchar
  la abstención, jamás angostarla.

### P5 — El barrido C-48 entero bajo mapa contra el álgebra

Los 43 estados, con `|1 + f'|` calculado a mano en las tres formas normales
(`f' = -2x`, `f' = r - 2x`, `f' = r - 3x^2`): **cero desacuerdos** entre la palabra del paquete y
la palabra del álgebra, bajo la misma regla de resolución.

### P6 — El default no cambia nada

Con `semantics = "flow"`:

- **Ningún veredicto cambia** y **ningún campo existente cambia de valor**.
- La suite vieja queda entera: **ninguna aserción se pierde** (la cifra sólo puede subir desde
  89 078).
- Lo que la tarjeta SÍ gana, y se declara acá para que no se lea después como un cambio no
  anunciado: **el renglón que nombra la semántica** (VI.5 lo exige siempre, también bajo flujo) y,
  donde la ruta intervalar corrió, los renglones de la tercera medición y su procedencia.

### P7 — El certificado de confinamiento, con sus controles externos

- **P7a (positivo, con referente externo).** `f(x) = 0.5*x*(1 - x)` sobre `[0.8, 1.2]`:
  `g = x + f`, `g([0.8,1.2]) = [0.88, 1.08]` por álgebra a mano, contenido en la caja
  (**invariancia**), y `g'([0.8,1.2]) = [0.3, 0.7]` con `|g'| <= 0.7 < 1` (**contracción**). El
  certificado debe dar las DOS y concluir punto fijo único con convergencia de toda órbita de la
  caja.
- **P7b (confinamiento SIN contracción — la frontera doctrinal).** `f(x) = -2x` sobre `[-1, 1]`:
  `g(x) = -x`, `g([-1,1]) = [-1,1]` (**invariancia demostrada**) y `|g'| = 1`, que **no** es
  `< 1`. El certificado debe decir «confinada» y **nada más**. Referente externo a la cadena: la
  órbita `0.5 -> -0.5 -> 0.5 -> ...` no converge nunca, y está adentro de la caja.
- **P7c (contracción SIN invariancia — no concluye nada).** `f(x) = -0.5*x + 10` sobre `[-1, 1]`:
  `g(x) = 0.5x + 10`, `|g'| = 0.5 < 1` pero `g([-1,1]) = [9.5, 10.5]`, que **no** está adentro. El
  certificado NO debe concluir existencia ni unicidad: Banach pide las dos hipótesis, y el punto
  fijo verdadero (x = 20) está fuera de la caja.
- **P7d (ni una ni otra).** `f(x) = x` sobre `[-1, 1]`: `g(x) = 2x`, `g([-1,1]) = [-2,2]`. Ninguna
  de las dos palabras.

## 4. Los controles positivos, y que van ANTES de cada pieza

Un control positivo que no dispara es un arnés roto. Los de esta fase, escritos antes que su pieza:

1. **Contención**: forzar la caja del enclosure a ancho CERO (`du = 0`) DEBE hacer que el valor del
   backend quede afuera en al menos un estado del barrido — si no queda afuera, la contención que
   P1 asiente no estaba midiendo nada.
2. **Semántica**: leer un autovalor de -2,0004 bajo flujo DEBE dar `stable` y bajo mapa DEBE dar la
   palabra del flip. Las dos ramas en el mismo test, porque lo que se prueba es que **difieren**.
3. **Resolución heredada**: poner la resolución del mapa a 0 adrede DEBE convertir en veredicto los
   tres bordes exactos de P4, que con la resolución verdadera están en abstención.
4. **Confinamiento**: P7b, P7c y P7d son los tres controles negativos de P7a, cada uno con su
   referente externo escrito arriba.
5. **Plantado**: sin `RobustArithmetic` en la biblioteca, la lectura DEBE seguir corriendo con dos
   mediciones y la tarjeta DEBE nombrar qué se pierde — nunca callar la ausencia.

## 5. Lo que esta fase NO hace (no-objetivos declarados, VI.4)

Órbitas de período mayor que 1, exponentes de Lyapunov, diagramas de órbita, herramientas de caos.
Quedan fuera de alcance, y la frontera es la frase de VI.3: **el confinamiento certifica encierro;
qué pasa adentro no se afirma.** Si alguna vez entran, entran con su propio bloque de diseño y su
propio referente.

## 6. Enmiendas

### E-1 (2026-08-20, sesión 82) — **P2b queda FALLADA, y la falla es mía, no de la vía**

Medido sobre los 43 estados: **P2a pasa** (peor `|ratio - 1|` = 3,638e-12, contra un umbral de
1e-9) y **P2b falla en los 9 estados de la horquilla con `x_hat = 0`**, donde el radio medido es
**2,235e-8** y el umbral que escribí era el piso, 3,667e-11.

**El diagnóstico, y no se aflojó el criterio.** La fórmula que pre-registré era correcta —el radio
donde `f''` se anula es `1,5 * du^2`— y **la aritmética con que la evalué no**: escribí 5,6e-14
donde `1,5 * du^2 = 1,5 * (1,220703e-4)^2 = 2,235e-8`, seis órdenes de magnitud abajo. El umbral
`rad <= floor` salió de ese número mal sacado. **El texto de arriba no se toca**: P2b se declara
fallada y ésta es la razón.

**Y la falla trae una cosa de fondo, que es lo que P2b iba a medir aunque no como yo creía.** El
radio riguroso es `|f''|*du + O(|f'''|*du^2)`, y donde la curvatura se anula el segundo término es
todo lo que hay: **2,235e-8, que son 609 veces el piso declarado de 3,667e-11**. O sea: **la
resolución de primer orden de C-47 (`|f''|*du + floor`) NO es conservadora en un estado donde la
curvatura se anula** — el piso está pensado como piso de la evaluación en doble y no cubre el
término de segundo orden de la ubicación de la raíz.

Qué se hace con eso, y qué NO:

- **No se toca C-47.** Su resolución está canonizada y el veredicto bajo `semantics = "flow"` sigue
  saliendo de ella: P6 manda.
- **Se presenta al lado**, que es el patrón C-25 y lo que V.9 pide de esta pieza: la tercera
  medición trae su propio radio y **la tarjeta nombra dónde las dos resoluciones se separan**.
- El estado alcanzable donde las dos partirían —un `|f'|` entre 3,667e-11 y 2,235e-8 en un estado
  de curvatura nula— **no existe en las fixturas de hoy** (el barrido C-48 usa `|r| >= 0,25`), y
  queda dicho acá para que el autor lo vea con su número al lado y no como una sospecha.

### E-2 (2026-08-20, sesión 82) — **P7b queda FALLADA, y la causa es la §3.4 otra vez**

`f(x) = -2x` sobre `[-1, 1]` **no certifica invariancia**, y no por un defecto de la
implementación: `g([-1,1])` sale `[-1,0000000000000007, 1,0000000000000007]`. La imagen
verdadera es `[-1, 1]` **exactamente**, y un encierro que redondea hacia AFUERA por construcción
la sobrepasa por un ulp. Subdividir no lo arregla y no puede: medido en 1, 2, 4, 16 y 64
subcajas, el resultado es el mismo hasta el último bit. **Es la lección de la §3.4 de la 81 en
otro traje: una verificación sobre una caja cuyo borde el objeto toca exactamente choca con el
piso de redondeo, y ninguna precisión lo baja.**

Qué se hizo, y qué NO:

- **No se aflojó el criterio de invariancia.** La contención sigue siendo `imagen ⊆ ventana` sin
  holgura ninguna. El caso se informa como **no demostrado**, que es lo que es, y el manual dice
  que una ventana cuya imagen toca su propio borde es el caso que ningún refinamiento alcanza.
- **Se agregó lo que la falla mostró que faltaba, y es de fondo**: (1) **subdivisión** de la
  ventana por una escalera declarada `{1, 2, ..., 256}` —medido: `g = x - x^3` sobre
  `[-1,2; 1,2]`, imagen verdadera `[-0,528; 0,528]`, una caja da `[-2,928; 2,928]` y no
  certifica nada, cuatro cajas certifican, ocho llegan a la imagen verdadera—; y (2) la
  **refutación puntual**, que es rigurosa en la dirección contraria: un punto de la ventana cuya
  imagen se encierra afuera resuelve la invariancia en negativo para siempre. Con eso cada
  condición tiene **tres** estados y no dos, y el del medio es el informe honesto de un
  presupuesto.
- **El ejemplo doctrinal de «confinada sin contraer» se reemplazó por uno que el instrumento
  puede probar**, con referente externo más fuerte: la logística `mu = 3,2` leída como mapa
  (`f = 2,2 Z - 3,2 Z^2`) sobre `[0,45; 0,81]` — invariancia **demostrada** con 8 subcajas,
  contracción **refutada** (`lambda = 1,984`), y adentro vive la órbita de período 2
  `{0,5130445; 0,7994555}`, que no converge nunca y está en cualquier tratamiento estándar de la
  duplicación de período. `g(x) = -x` queda igual como ejemplo en la prosa de la frontera, que es
  donde vale, y como fixtura del caso «sin veredicto».

Los otros tres se cumplieron como estaban escritos: **P7a** invariancia y contracción demostradas
con una sola caja (`lambda = 0,7`); **P7c** contracción demostrada e invariancia **refutada**
(imagen `[9,5; 10,5]`), sin concluir nada; **P7d** las dos refutadas.
