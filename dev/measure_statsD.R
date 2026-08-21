# Fase 0, punto 2 de las pautas: medir el stats::D INSTALADO por el camino que el
# autor usa -- D(expression(...), "x") sobre cada candidato -- y cerrar por
# enumeracion la tabla de operadores del constructor de expresiones (V.7).
#
# No se lee el fuente de R ni se confia en la pagina de ayuda: se llama a la
# funcion instalada y se anota que contesta.

cands_un <- c("exp", "log", "sin", "cos", "tan", "sinh", "cosh", "tanh",
              "sqrt", "abs", "sign", "asin", "acos", "atan", "asinh", "acosh",
              "atanh", "expm1", "log1p", "log2", "log10", "gamma", "lgamma",
              "digamma", "trigamma", "psigamma", "besselJ", "floor", "ceiling",
              "round", "trunc", "max", "min", "pnorm", "dnorm", "plogis",
              "dlogis", "exp2")
cands_bin <- c("+", "-", "*", "/", "^", "%%", "%/%")

probe <- function(txt) {
  out <- tryCatch({
    d <- stats::D(parse(text = txt)[[1L]], "x")
    list(ok = TRUE, val = paste(deparse(d), collapse = " "))
  }, error = function(e) list(ok = FALSE, val = conditionMessage(e)))
  out
}

cat("=== UNARIAS: D(f(x), \"x\") ===\n")
res_un <- lapply(cands_un, function(f) probe(sprintf("%s(x)", f)))
names(res_un) <- cands_un
for (f in cands_un) {
  r <- res_un[[f]]
  cat(sprintf("%-10s %-3s %s\n", f, if (r$ok) "SI" else "NO", r$val))
}

cat("\n=== BINARIAS: D(x <op> y, \"x\") ===\n")
res_bin <- lapply(cands_bin, function(o) probe(sprintf("x %s y", o)))
names(res_bin) <- cands_bin
for (o in cands_bin) {
  r <- res_bin[[o]]
  cat(sprintf("%-6s %-3s %s\n", o, if (r$ok) "SI" else "NO", r$val))
}

cat("\n=== UNARIO: D(-x, \"x\") y D(+x, \"x\") ===\n")
for (txt in c("-x", "+x")) {
  r <- probe(txt)
  cat(sprintf("%-4s %-3s %s\n", txt, if (r$ok) "SI" else "NO", r$val))
}

cat("\n=== POTENCIAS: exponente constante, variable y base variable ===\n")
for (txt in c("x^2", "x^0.5", "x^(-3)", "x^y", "2^x", "exp(1)^x")) {
  r <- probe(txt)
  cat(sprintf("%-10s %-3s %s\n", txt, if (r$ok) "SI" else "NO", r$val))
}

cat("\n=== log de dos argumentos (base) ===\n")
for (txt in c("log(x, 2)", "log(x, base = 2)")) {
  r <- probe(txt)
  cat(sprintf("%-16s %-3s %s\n", txt, if (r$ok) "SI" else "NO", r$val))
}

cat("\n=== resumen para la tabla cerrada ===\n")
ok_un <- cands_un[vapply(res_un, function(r) r$ok, logical(1L))]
ok_bin <- cands_bin[vapply(res_bin, function(r) r$ok, logical(1L))]
cat("unarias derivables:", paste(ok_un, collapse = " "), "\n")
cat("binarias derivables:", paste(ok_bin, collapse = " "), "\n")
cat("unarias NO derivables:",
    paste(setdiff(cands_un, ok_un), collapse = " "), "\n")
cat("binarias NO derivables:",
    paste(setdiff(cands_bin, ok_bin), collapse = " "), "\n")
cat("R:", R.version.string, "\n")
cat("MEDICION-STATSD-FIN\n")
