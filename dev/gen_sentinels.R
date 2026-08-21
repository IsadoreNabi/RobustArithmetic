## Genera R/sysdata.rda: los centinelas de carga de la salvaguarda S1 y el ancla
## de entorno de la salvaguarda S4 (disenadas en la sesion 80, fallo del autor
## C-54 = opcion (c), construidas en la 81).
##
## Cada centinela es un punto donde el error de la libm es grande y conocido:
##   (a) las 16 entradas de peor caso publicadas para GNU libc 2.43 en la
##       Tabla 4 de Gladman, Innocente, Mather, Ozaki y Zimmermann (edicion de
##       febrero de 2026), copiadas en hexadecimal exacto de la tabla;
##   (b) los puntos de discrepancia de ruta: el de `sin` que la sesion 80 aislo
##       (0x1.b981319337b63p-26) quedo como constante; los de `exp` y `cos` NO
##       quedaron registrados como constantes en la 80, asi que este guion los
##       RE-ENCUENTRA con una busqueda sembrada (semilla fija, misma tecnica de
##       muestreo que ra_measure_library_error) y los fija aca. Es data-driven:
##       el punto elegido es el argmax del error observado de la ruta en uso.
##
## Para cada punto se precomputa el valor correctamente redondeado y su par de
## dobles encuadrantes con MPFR a 500 bits, verificado por una SEGUNDA via
## independiente: otra precision (800 bits) para todos, y serie de Taylor para
## el punto de discrepancia de `sin`, donde la serie es barata y converge en
## tres terminos.
##
## Correr desde la raiz del paquete:  Rscript dev/gen_sentinels.R

stopifnot(file.exists("DESCRIPTION"))
suppressMessages({
  library(Rmpfr)
  pkgload::load_all(quiet = TRUE)
})

hex <- function(s) {
  v <- as.numeric(s)
  stopifnot(is.finite(v))
  v
}

## --- (a) Tabla 4, columna GNU libc 2.43, las 16 funciones de la tabla v1 ---
worst <- list(
  acos  = hex("0x1.dffffb3488a4p-1"),
  asin  = hex("-0x1.0000045b2c904p-3"),
  atan  = hex("0x1.f9004c4fef9eap-4"),
  cos   = hex("-0x1.7120161c92674p+0"),
  cosh  = hex("-0x1.633c654fee2bap+9"),
  exp   = hex("-0x1.49f33ad2c1c58p+9"),
  expm1 = hex("0x1.63e063d87938p-2"),
  log   = hex("0x1.1211bef8f68e9p+0"),
  log10 = hex("0x1.de02157073b31p-1"),
  log1p = hex("-0x1.2bf183e0344b2p-2"),
  log2  = hex("0x1.1406d79e1b574p+0"),
  sin   = hex("-0x1.f8b791cafcdefp+4"),
  sinh  = hex("-0x1.633c654fee2bap+9"),
  sqrt  = hex("0x1.fffffffffffffp-1"),
  tan   = hex("-0x1.317cd745dd37cp+9"),
  tanh  = hex("-0x1.e11025010ba1cp-3")
)
stopifnot(setequal(names(worst), ra_operator_table("functions")$fun))

## --- (b) los puntos de discrepancia de ruta ---
## El de `sin`, aislado por la 80 y verificado alli fuera de R (programa en C,
## MPFR y serie): la ruta ordinaria devuelve el argumento mismo, un ulp arriba
## del correctamente redondeado.
route_pts <- list(sin = hex("0x1.b981319337b63p-26"))

## Los de `exp` y `cos`: busqueda sembrada del argmax del error de la ruta en
## uso. La malla es log-uniforme en magnitud dentro del dominio, ambos signos,
## la misma familia de muestreo del medidor exportado.
find_route_point <- function(fun, n = 20000L, seed = 81L) {
  set.seed(seed)
  ex <- stats::runif(n, min = -40, max = if (fun == "exp") 9 else 40)
  x <- sample(c(-1, 1), n, replace = TRUE) * 2^ex
  y <- do.call(fun, list(x))                    # la ruta ordinaria, en lote
  z <- do.call(fun, list(mpfr(x, 300L)))
  err <- asNumeric(abs(mpfr(y, 300L) - z) / 2^(-52 + floor(log2(abs(z)))))
  i <- which.max(err)
  cat(sprintf("  %s: argmax err = %.4f ulp en x = %a\n", fun, err[i], x[i]))
  ## El arnes DEBE encontrar discrepancia real (CP-1 del pre-registro): si la
  ## ruta fuera perfecta en toda la malla, o el medidor esta roto o hubo un
  ## cambio de entorno que hay que investigar, no taparse.
  stopifnot(err[i] > 0.5)
  x[i]
}
cat("Buscando los puntos de discrepancia de exp y cos (semilla 81):\n")
route_pts$exp <- find_route_point("exp")
route_pts$cos <- find_route_point("cos")

## --- el par encuadrante y el correctamente redondeado, por dos vias ---
## dn/up son los dos dobles que encierran el valor VERDADERO (irracional en
## los 19 puntos, asi que dn < up siempre); cr es el redondeado a nearest,
## que es lo que una libm correctamente redondeada devolveria.
enclose_at <- function(fun, x, bits) {
  z <- do.call(fun, list(mpfr(x, bits)))
  c(ra_to_double(z, "down"), ra_to_double(z, "up"),
    asNumeric(roundMpfr(z, 53L)))
}

rows <- list()
for (fun in names(worst)) {
  xs <- c(worst[[fun]], route_pts[[fun]])
  role <- c("published_worst_case", if (!is.null(route_pts[[fun]])) "route_discrepancy")
  for (k in seq_along(xs)) {
    p500 <- enclose_at(fun, xs[k], 500L)
    p800 <- enclose_at(fun, xs[k], 800L)
    stopifnot(identical(p500, p800))            # segunda via: otra precision
    stopifnot(p500[1] < p500[2], p500[3] %in% p500[1:2])
    rows[[length(rows) + 1L]] <- data.frame(
      fun = fun, x = xs[k], dn = p500[1], up = p500[2], cr = p500[3],
      role = role[k], slack = ra_slack(fun), stringsAsFactors = FALSE)
  }
}
.ra_sentinels <- do.call(rbind, rows)
row.names(.ra_sentinels) <- NULL

## Tercera via para el punto de discrepancia de `sin`: serie de Taylor a 500
## bits. En |x| ~ 2^-25 tres terminos dejan el resto por debajo de 2^-150 del
## valor, muy adentro del redondeo a 53 bits.
xs <- mpfr(route_pts$sin, 500L)
serie <- xs - xs^3 / 6 + xs^5 / 120
stopifnot(identical(ra_to_double(serie, "down"),
                    .ra_sentinels$dn[.ra_sentinels$fun == "sin" &
                                     .ra_sentinels$role == "route_discrepancy"]))

## Y el hallazgo de la 80 tiene que seguir vivo EN el dato: en ese punto la
## ruta ordinaria de R devuelve un doble DISTINTO del correctamente
## redondeado. Si esto deja de valer, el entorno cambio y los centinelas
## deben regenerarse, no heredarse.
i <- which(.ra_sentinels$fun == "sin" & .ra_sentinels$role == "route_discrepancy")
stopifnot(sin(.ra_sentinels$x[i]) != .ra_sentinels$cr[i])

## --- S4: el ancla de entorno, nombrada ---
glibc <- tryCatch(system2("getconf", "GNU_LIBC_VERSION", stdout = TRUE),
                  error = function(e) NA_character_)
.ra_anchor <- list(
  libm = glibc,
  r_version = paste(R.version$major, R.version$minor, sep = "."),
  jit_level = compiler::enableJIT(-1L),
  rmpfr = as.character(utils::packageVersion("Rmpfr")),
  source = paste("Gladman, Innocente, Mather, Ozaki & Zimmermann (2026),",
                 "Table 4, column GNU libc 2.43"),
  generated = format(Sys.Date())
)

print(.ra_sentinels)
str(.ra_anchor)
save(.ra_sentinels, .ra_anchor, file = "R/sysdata.rda", compress = "xz")
cat("R/sysdata.rda escrito:", nrow(.ra_sentinels), "centinelas.\n")
