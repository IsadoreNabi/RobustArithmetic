# PROMPT PARA LA PRÓXIMA INSTANCIA — RobustArithmetic, salida de texto (IEEE 1788.1 §6.8.3)

**Escrito el 2026-08-21.** Nivel de esfuerzo sugerido: **Max** si hay que reparar algo; **alto**
alcanza si la suite ya dio limpio y sólo queda commitear.

---

## ESTADO

**Dos trabajos, los dos terminados. Todo lo de abajo es registro, no agenda.**

### 1. La salida de texto (IEEE 1788.1 §6.8.3) — cerrado, commits `a89065d` y `5613aec`

Detalle completo más abajo y en el §6 de `NOTES-RobustArithmetic.md`.

### 2. El pretest de CRAN — cerrado

Llegó después: **1 ERROR en Debian, 1 ERROR en Windows (13 fallos)**. **No los causó la reparación
del §6**: el log de CRAN imprime `[2.718282, 7.389056]_com`, o sea el formato **viejo**. CRAN probó
el tarball anterior.

La causa era una sola y estaba **en el banco, no en el paquete**. El paquete envía centinelas
medidos y un ancla del entorno donde se midieron; en Windows la libm excedió la holgura declarada,
el portón degradó el nivel rápido y **el paquete lo dijo 197 veces**, que es S2 y S5 funcionando.
Lo que fallaba eran aserciones que codificaban la máquina del autor:

1. `test-safeguards.R:90` afirmaba `length(a$mismatch) == 0` — o sea, que la máquina que corre las
   pruebas **es** la máquina de los centinelas. Ahora afirma que un desajuste, donde lo haya,
   **nombra el campo**; el control positivo del ancla adulterada quedó.
2. Cuatro pruebas (las tres de propagación S3 y la CP-7 de la escalera) presuponían el nivel rápido
   en uso. Ahora lo **mantienen abierto mientras duran** y restauran el estado al salir: son sobre
   la contabilidad y sobre la escalera, no sobre la exactitud de ninguna libm.
3. `test-elementary.R:173` afirmaba `observed <= slack`, que es sobre **esta** máquina. Ahora lo
   afirma donde puede ser cierto y, donde no, afirma lo único que nunca puede fallar: **que el
   paquete se dio cuenta**.
4. Y `test-safeguards.R:78` no fallaba por lo que miraba: el portón sólo audita mientras el nivel
   rápido **no** está ya degradado. Faltaba salvar y limpiar `fast_degraded`.

**Verificado reproduciendo las dos condiciones de CRAN acá**, no conjeturando: ancla adulterada, y
`ra_measure_library_error` sustituida por una que devuelve `observed = slack + 1`.

| escenario | antes | ahora |
| --- | --- | --- |
| esta máquina | 0 fallos | **0** (164 ok) |
| ancla desajustada (Debian) | 1 fallo | **0** (166 ok) |
| libm rota + ancla desajustada (Windows) | 13 fallos | **0** (166 ok) |

La NOTE de ortografía no se toca: quedó explicada en `cran-comments.md`, que es donde va.
Registro en el **§7** de `NOTES-RobustArithmetic.md`.

---

## QUÉ SE HIZO, Y POR QUÉ

El pedido del autor fue: **reparar que `format()` de un intervalo imprima algo falso.** Venía de
`AVISO_QD_FORMAT_RA_IVL.md` (raíz del repo), que dejó la sesión 85 de QuantDialectics.

**El diagnóstico del aviso era correcto y su reparación propuesta no.** El aviso recomendaba la
representación de ida y vuelta más corta —la cadena mínima que `as.numeric()` devuelve idéntica—
y la llamaba «contiene por identidad». **No contiene.** La §6.8.3 pide que la cadena contenga al
intervalo y la **§6.6.2 define qué significa la cadena**: el valor del literal `[l, u]` es el
intervalo **matemático** `[l, u]`, los decimales leídos **exactos**. Medido con Rmpfr: la forma de
ida y vuelta falla en 3 de 5 casos, incluido el ejemplo central del propio aviso. Y el «hacia
afuera infla nueve órdenes de magnitud» era artefacto de fijar **siete** cifras: a las cifras que
el número tiene, la razón de anchos es 1,00001.

**La regla que salió de ahí, y que gobierna todo el archivo nuevo:** un número impreso o bien
**ACOTA** un desconocido —extremo, ancho, cota de error, premisa— y va redondeado en la dirección
que deja la oración verdadera; o bien **IDENTIFICA** el dato sobre el que se corrió —el radio de la
bola certificada— y va con la cadena más corta que vuelve al mismo double. Redondear al más
cercano no sirve para ninguna de las dos, y era lo que hacían las dos.

### Los archivos

| archivo | qué pasó |
| --- | --- |
| `R/decimal.R` | **NUEVO.** El motor entero. |
| `R/interval-class.R` | `format.ra_ivl` redondea hacia afuera; guarda de largo cero; `Widest:` hacia arriba; la página de `ra_show` reescrita. |
| `R/ball-certificate.R` | La tarjeta: cota de error y premisas hacia **arriba**, radio con **fidelidad**; el `%.17g` del `reason` pasó a la misma fidelidad. |
| `R/elementary.R` | El ancho del resumen, hacia arriba. |
| `R/RobustArithmetic-package.R` | La lista de conformidad: 6.8.3 **provista**, 6.8.2 ausente. |
| `tests/testthat/test-decimal.R` | **NUEVO.** El banco, con **dos controles positivos**. |
| `NOTES-RobustArithmetic.md` | §6 nuevo con todo el registro; el §5.5 viejo lleva su nota de superado. |
| `vignettes/robustarithmetic.Rmd` | El párrafo de conformidad. |
| `.Rbuildignore` | `^AVISO_.*\.md$`, que sacó una NOTE del check. |

### De qué depende la corrección (y de qué NO)

Sólo de dos cosas, y ninguna puede fallar en una plataforma sana:

1. que la conversión de decimal a binario sea **monótona** (lo es: es un redondeo);
2. que sumar o restar una unidad a la última cifra **de la cadena** sea exacto (lo es: se hace
   sobre los dígitos, no sobre un double).

Todo lo demás —la comparación exacta con doble-double, el escalado por etapas con cota de error
derivada, el test de rejilla— sirve para la **estrechez**, y **lo que no se certifica se declina**
moviendo una cifra hacia afuera. Nunca se lee un signo del término de error.

**Garantía declarada:** el encierro impreso está contenido en `[ra_pred(lo), ra_succ(hi)]`.

---

## LO MEDIDO

Contra Rmpfr a 400 bits, sobre adversariales (decimales exactos, subnormales, potencias de dos,
`1e23`, `2^53+1`, los dos extremos del rango) y aleatorios de todo el rango:

| propiedad | comprobaciones | fallos |
| --- | --- | --- |
| contención de Nivel 1 (§6.6.2 + §6.8.3) | 9038 | **0** |
| holgura dentro de un paso de redondeo | 9038 | **0** |
| optimalidad (mover la última cifra hacia adentro rompe la contención) | 9038 | **0** |

Con control positivo en las dos direcciones: el mismo portón **falla** sobre `format()` de R y
sobre el `%.6g` viejo de la tarjeta.

- `R CMD check --as-cran`: **0 errores, 0 avisos, 1 NOTE** («New submission»).
- Suite en modo normal: **592 aserciones, 0 fallos.**
- Suite con **todos** los portones: **955 aserciones, 0 fallos, 0 errores, 2 saltadas.**

---

## LO QUE CAMBIÓ EN LA SALIDA, PARA QUE NO TE ASUSTE

```
ra_interval(-2.5, 3.75)   [-2.5, 3.75]_com                              (igual que antes)
ra_interval(1, 2)         [1, 2]_com                                    (igual que antes)
ra_interval(0.1, 0.2)     [0.1, 0.20000000000000002]_com
ra_interval(pi, pi)       [3.141592653589793, 3.1415926535897932]_com
```

Los largos distintos entre extremos **no son un defecto**: el double más cercano a `0,1` está por
**encima** del decimal `0,1`, así que `0.1` es cota inferior verdadera; el más cercano a `0,2`
también está por encima, así que `0.2` **no** es cota superior y hay que ir a la siguiente. Y un
degenerado imprime dos decimales distintos porque un degenerado de doubles **no es un real**: es
todo lo que redondea a uno.

**Costo en tiempo, declarado:** del orden de un milisegundo por extremo **distinto**, porque cada
uno se prueba. `format()` de mil intervalos tarda ~1,6 s (arrancó en 12,5 s y se optimizó). Quien
necesite miles quiere `as.data.frame()`, que no prueba porque no imprime.

---

## EL CIERRE

1. Suite con todos los portones en verde (arriba).
2. **Commit** — regla del autor: se commitea al terminar TODO y **no se pregunta**. Sin atribuir a
   Claude; autor único José Mauricio. Repo `github.com/IsadoreNabi/RobustArithmetic`, rama `main`.
   Mensaje sugerido: *"Outward-rounded text output: printed enclosures now contain the interval
   (IEEE 1788.1 §6.8.3)"*.
3. **Avisarle a QuantDialectics.** QD consume este paquete y su salida impresa cambió. El canal es
   dejar un `AVISO_ROBUSTARITHMETIC_*.md` en la raíz de `~/QuantDialectics`. Lo que QD necesita
   saber está en la memoria `backend_robustarithmetic_estado.md`, sección del 2026-08-21. **La
   tarjeta de QD no lee el texto impreso**, así que no hay nada roto allá; es aviso, no reparación.

## LO QUE NO SE HIZO, A PROPÓSITO

- **La forma incierta `m?r` de §6.6.2 no se emite.** Es más corta para un intervalo angosto —para
  `[pi,pi]`, 22 caracteres contra 40— y ningún especificador la selecciona. Está declarado en la
  página de `ra_interval_to_text()` y en §6.6 de las notas. Si se agrega alguna vez, la
  construcción certificada es: truncar hacia abajo la cota inferior y hacia arriba la superior a
  `d` decimales, tomar `A` y `B` en unidades de `10^-d`, y `m = (A+B)/2`, `r = (B-A)/2` con `B`
  corrido uno si `A+B` es impar.
- **§6.8.2 (`textToInterval`) sigue ausente.** Se producen literales válidos; no se leen.
- **Cerrar §6.8.3 no da conformidad**: la cláusula 1 exige además 6.8.2 y 7.3, y la 1788.1 no tiene
  grado parcial. El argumento para reparar era de **corrección**, no de conformidad.
- **`AVISO_QD_FORMAT_RA_IVL.md` sigue en la raíz.** Es el mensaje de la otra sesión, ya respondido y
  absorbido en §6; no lo borré porque no es mío. Ya está en `.Rbuildignore`.
