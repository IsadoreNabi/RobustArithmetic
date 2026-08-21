# Las referencias del paquete, en APA 7 — lista canónica

**Fuente de la norma**: `~/Descargas/APA 7_0-.pdf` (Publication Manual, 7a ed.), capítulo 10.
Plantillas usadas: §10.1 artículos de revista, §10.2 libros, **§10.4 informes y literatura
gris** (las normas IEEE y el reporte de exactitud caen acá), **§10.10 software** (Rmpfr).

**Regla de esta lista**: cada entrada se escribe UNA vez acá y se copia literal a los bloques
`@references` de Roxygen. Un `@references` que no coincida con esta lista es un defecto.

## Tres decisiones de forma, declaradas

1. **Título en *sentence case*** (sólo la primera palabra, la primera después de dos puntos, y
   los nombres propios), que es lo que APA 7 pide para artículos, libros e informes — no
   *title case*, que es lo que la versión anterior de estos bloques usaba.
2. **Los localizadores NO van en la referencia.** APA 7 los pone en la cita («Tabla 3, columna
   GNU libc 2.43»), no en la lista de referencias. En Roxygen, donde no hay cita parentética,
   el localizador va en la prosa del `@details` o del `@section`, y la referencia queda limpia.
3. **Nombres sin acento, y es una cesión declarada.** `R/` es ASCII puro con portón que lo
   mide, y `\u` no funciona dentro de un comentario de Roxygen. Lefevre, Pelissier, Birkhauser
   y Melquiond van sin diacríticos. Es lo que hacen los paquetes de CRAN con fuentes ASCII;
   queda dicho acá para que no se lea como descuido.

---

## Artículos de revista (§10.1)

    Fousse, L., Hanrot, G., Lefevre, V., Pelissier, P., & Zimmermann, P. (2007). MPFR: A
      multiple-precision binary floating-point library with correct rounding. ACM
      Transactions on Mathematical Software, 33(2), Article 13.
      https://doi.org/10.1145/1236463.1236468

    Johansson, F. (2017). Arb: Efficient arbitrary-precision midpoint-radius interval
      arithmetic. IEEE Transactions on Computers, 66(8), 1281-1292.
      https://doi.org/10.1109/TC.2017.2690633

    Revol, N., & Rouillier, F. (2005). Motivations for an arbitrary precision interval
      arithmetic and the MPFI library. Reliable Computing, 11(4), 275-290.
      https://doi.org/10.1007/s11155-005-6891-y

    Rump, S. M. (2010). Verification methods: Rigorous results using floating-point
      arithmetic. Acta Numerica, 19, 287-449. https://doi.org/10.1017/S096249291000005X

    Rump, S. M., Zimmermann, P., Boldo, S., & Melquiond, G. (2009). Computing predecessor and
      successor in rounding to nearest. BIT Numerical Mathematics, 49(2), 419-431.
      https://doi.org/10.1007/s10543-009-0218-z

## Libros (§10.2)

    Hansen, E., & Walster, G. W. (2004). Global optimization using interval analysis (2nd
      ed.). Marcel Dekker.

    Moore, R. E., Kearfott, R. B., & Cloud, M. J. (2009). Introduction to interval analysis.
      Society for Industrial and Applied Mathematics.
      https://doi.org/10.1137/1.9780898717716

    Muller, J.-M., Brunie, N., de Dinechin, F., Jeannerod, C.-P., Joldes, M., Lefevre, V.,
      Melquiond, G., Revol, N., & Torres, S. (2018). Handbook of floating-point arithmetic
      (2nd ed.). Birkhauser. https://doi.org/10.1007/978-3-319-76526-6

    Neumaier, A. (1990). Interval methods for systems of equations. Cambridge University
      Press. https://doi.org/10.1017/CBO9780511526473

    Tucker, W. (2011). Validated numerics: A short introduction to rigorous computations.
      Princeton University Press.

    Wickham, H. (2019). Advanced R (2nd ed.). Chapman & Hall/CRC.
      https://doi.org/10.1201/9781351201315

## Informes y literatura gris (§10.4) — acá caen las normas IEEE

APA 7 §10.4 trata las normas técnicas como informes de autor colectivo: **cuando el editor es
el mismo que el autor, el editor se omite de la fuente**. Por eso «IEEE» aparece una sola vez.

    Gladman, B., Innocente, V., Mather, J., Ozaki, K., & Zimmermann, P. (2026). Accuracy of
      mathematical functions in single, double, double extended, and quadruple precision
      (edicion de febrero de 2026) [Informe tecnico].
      https://members.loria.fr/PZimmermann/papers/accuracy.pdf

    Institute of Electrical and Electronics Engineers. (2015). IEEE standard for interval
      arithmetic (IEEE Std 1788-2015).
      https://doi.org/10.1109/IEEESTD.2015.7140721

    Institute of Electrical and Electronics Engineers. (2018). IEEE standard for interval
      arithmetic (simplified) (IEEE Std 1788.1-2017).
      https://doi.org/10.1109/IEEESTD.2018.8277144

    Institute of Electrical and Electronics Engineers. (2019). IEEE standard for
      floating-point arithmetic (IEEE Std 754-2019).
      https://doi.org/10.1109/IEEESTD.2019.8766229

## Software (§10.10)

El manual dice que R mismo, por ser un programa estadístico de uso común, **no necesita
referencia**; un paquete de distribución limitada como Rmpfr, sí. El título del software va en
cursiva y lleva el número de versión y el corchete descriptivo.

    Maechler, M. (2024). Rmpfr: R MPFR - multiple precision floating-point reliable (Version
      1.1-2) [Software]. Comprehensive R Archive Network.
      https://doi.org/10.32614/CRAN.package.Rmpfr

---

## Dónde va cada una (mapa de aplicación)

| archivo | referencias que le corresponden |
| --- | --- |
| `R/rounding.R` | Rump et al. (2009); IEEE (2019); Rump (2010) |
| `R/interval-class.R` | IEEE (2018) |
| `R/arithmetic.R` | IEEE (2018); Hansen & Walster (2004); Neumaier (1990) |
| `R/mpfr-bridge.R` | Fousse et al. (2007); Revol & Rouillier (2005); Maechler (2024) |
| `R/operator-table.R` | Gladman et al. (2026); IEEE (2019); Moore et al. (2009) |
| `R/conditions.R` | Wickham (2019); Maechler (2024); Fousse et al. (2007) |
| `R/elementary.R` | Moore et al. (2009); IEEE (2018); Gladman et al. (2026); Neumaier (1990); Muller et al. (2018); Revol & Rouillier (2005); Rump (2010); Wickham (2019) |
| `R/expression.R` | Moore et al. (2009); Neumaier (1990) |
| `R/RobustArithmetic-package.R` | IEEE (2015); Rump et al. (2009); Rump (2010); Neumaier (1990); Hansen & Walster (2004); Moore et al. (2009); Tucker (2011) |

*(Fila del archivo de paquete agregada en la sesion 81: no estaba en el mapa de la 80 y su
bloque `@references` — el panorama del paquete — tambien entra al barrido.)*

## Lo que falta hacer con esta lista

**Aplicada a `R/elementary.R` y `R/expression.R` en la sesion 80, y a los seis archivos de
la 79 mas `RobustArithmetic-package.R` en la sesion 81** (guion `dev/apply_apa7.R`, entradas
completadas por `dev/restore_apa_entries.R`). Los localizadores que vivian dentro de las
referencias se movieron a la prosa de cada bloque. Todo archivo nuevo nace ya conforme.
