# Fase 0, punto 2 (segunda mitad): CERRAR la tabla de operadores por clausura
# bajo diferenciacion.
#
# El criterio de admision de un simbolo a la tabla de la v1 tiene cuatro
# condiciones, todas verificables aca y ninguna elegida a dedo:
#
#   C1  stats::D lo deriva (medido en dev/measure_statsD.R).
#   C2  su derivada, y la derivada de su derivada, y asi hasta punto fijo, se
#       escriben con simbolos que tambien estan en la tabla -- la tabla es
#       CERRADA bajo diferenciacion. Sin esto, la forma del valor medio de la
#       fase 3 se sale de la tabla en el primer paso.
#   C3  existe un error maximo conocido en ulps para la libm de ESTA maquina
#       (glibc 2.43) en el reporte de Gladman, Innocente, Mather, Ozaki y
#       Zimmermann, edicion de febrero de 2026, Tabla 3 -- sin ese numero no hay
#       holgura declarable para el nivel rapido.
#   C4  MPFR la provee correctamente redondeada, para que exista nivel riguroso
#       y escalada.
#
# Este script calcula C1 y C2. C3 esta transcripto de la Tabla 3 del reporte y
# C4 se mide contra el Rmpfr instalado.

candidatos <- c("exp", "log", "sin", "cos", "tan", "sinh", "cosh", "tanh",
                "sqrt", "expm1", "log1p", "log2", "log10", "asin", "acos",
                "atan", "gamma", "lgamma", "digamma", "trigamma", "psigamma",
                "pnorm", "dnorm")
operadores <- c("+", "-", "*", "/", "^", "(")

# --- C3: Tabla 3 del reporte, columna GNU libc 2.43, doble precision ---
ulp_glibc243 <- c(exp = 0.511, log = 0.520, sin = 0.516, cos = 0.516,
                  tan = 0.619, sinh = 1.93, cosh = 1.93, tanh = 2.21,
                  sqrt = 0.500, expm1 = 0.913, log1p = 0.899, log2 = 0.548,
                  log10 = 1.62, asin = 0.516, acos = 0.523, atan = 0.523,
                  pow = 0.523)

## --- simbolos llamados en una expresion ---
called <- function(e, acc = character(0)) {
  if (is.call(e)) {
    acc <- c(acc, as.character(e[[1L]]))
    for (i in seq_along(e)[-1L]) acc <- called(e[[i]], acc)
  }
  acc
}

## --- clausura bajo diferenciacion desde un conjunto semilla ---
closure_of <- function(seed) {
  seen <- character(0)
  todo <- lapply(seed, function(f) call(f, quote(x)))
  syms <- character(0)
  guard <- 0L
  while (length(todo) && guard < 200L) {
    guard <- guard + 1L
    e <- todo[[1L]]; todo <- todo[-1L]
    key <- paste(deparse(e), collapse = "")
    if (key %in% seen) next
    seen <- c(seen, key)
    d <- tryCatch(stats::D(e, "x"), error = function(err) NULL)
    if (is.null(d)) { syms <- c(syms, paste0("<no-derivable:", key, ">")); next }
    syms <- c(syms, called(d))
    # seguir derivando cada llamada de funcion que aparezca en la derivada
    subcalls <- function(z, acc = list()) {
      if (is.call(z)) {
        h <- as.character(z[[1L]])
        if (h %in% candidatos) acc <- c(acc, list(z))
        for (i in seq_along(z)[-1L]) acc <- subcalls(z[[i]], acc)
      }
      acc
    }
    for (s in subcalls(d)) todo <- c(todo, list(s))
  }
  sort(unique(syms))
}

cat("=== clausura bajo diferenciacion, simbolo por simbolo ===\n")
fuera <- list()
for (f in candidatos) {
  cl <- closure_of(f)
  extra <- setdiff(cl, c(candidatos, operadores))
  fuera[[f]] <- extra
  cat(sprintf("%-9s clausura: %-58s | fuera de candidatos: %s\n",
              f, paste(cl, collapse = " "),
              if (length(extra)) paste(extra, collapse = " ") else "-"))
}

cat("\n=== C1 y C2 conjuntas: quien entra a la v1 ===\n")
tabla_v1 <- character(0)
for (f in candidatos) {
  c1 <- !is.null(tryCatch(stats::D(call(f, quote(x)), "x"), error = function(e) NULL))
  cl <- closure_of(f)
  c2 <- !any(grepl("^<no-derivable", cl))
  c3 <- f %in% names(ulp_glibc243)
  cat(sprintf("%-9s C1=%-5s C2=%-5s C3=%-5s\n", f, c1, c2, c3))
  if (c1 && c2 && c3) tabla_v1 <- c(tabla_v1, f)
}
cat("\ntabla v1 (C1 & C2 & C3):", paste(tabla_v1, collapse = " "), "\n")
cat("excluidas:", paste(setdiff(candidatos, tabla_v1), collapse = " "), "\n")

cat("\n=== la clausura del CONJUNTO tabla_v1 es el propio conjunto? ===\n")
cl_all <- closure_of(tabla_v1)
cat("simbolos que aparecen en las derivadas:", paste(cl_all, collapse = " "), "\n")
resto <- setdiff(cl_all, c(tabla_v1, operadores))
cat("fuera de la tabla v1 + operadores:",
    if (length(resto)) paste(resto, collapse = " ") else "NINGUNO -- la tabla es CERRADA",
    "\n")

## --- C4: MPFR provee cada una? ---
cat("\n=== C4: el Rmpfr instalado provee la funcion ===\n")
if (requireNamespace("Rmpfr", quietly = TRUE)) {
  x <- Rmpfr::mpfr("0.3", 120L)
  for (f in tabla_v1) {
    ok <- tryCatch({
      v <- do.call(f, list(x))
      methods::is(v, "mpfr")
    }, error = function(e) FALSE)
    cat(sprintf("%-9s MPFR=%s\n", f, ok))
  }
} else {
  cat("Rmpfr AUSENTE -- C4 no medible\n")
}

cat("\n=== holguras: slack(f) = ceiling(2*e(f) + 1) ===\n")
for (f in c(tabla_v1, "pow")) {
  e <- ulp_glibc243[[f]]
  cat(sprintf("%-9s e=%-6s slack=%d ulps\n", f, format(e), ceiling(2 * e + 1)))
}
cat("CIERRE-TABLA-FIN\n")
