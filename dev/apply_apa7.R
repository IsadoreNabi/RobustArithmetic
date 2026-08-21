## Aplica la lista canonica de dev/REFERENCIAS_APA7.md a los bloques @references.
## Se corre una vez por archivo y queda como registro de que el barrido fue mecanico
## y no a mano, que es lo que hace que sea auditable.
apa <- readRDS("dev/apa_entries.rds")
fmt <- function(key) paste0("#'   ", apa[[key]], collapse = "\n")

apply_to <- function(path, spec) {
  ln <- readLines(path)
  starts <- grep("^#' @references$", ln)
  stopifnot(length(starts) == length(spec))
  for (i in rev(seq_along(starts))) {
    s <- starts[i]
    j <- s + 1L
    while (j <= length(ln) && !grepl("^#. @", ln[j])) j <- j + 1L
    ln <- append(ln[-((s + 1L):(j - 1L))],
                 unlist(strsplit(paste(vapply(spec[[i]], fmt, character(1)), collapse = "\n#'\n"), "\n")),
                 after = s)
  }
  writeLines(ln, path)
  cat(path, ": ", length(starts), " bloques reescritos\n", sep = "")
}

## Sesion 80: los dos archivos de la fase 2/3. YA APLICADO; no volver a correr
## (los bloques ya estan en forma canonica y re-aplicar es idempotente pero
## inutil). Queda como registro.
if (FALSE) {
  apply_to("R/elementary.R", list(
    c("moore", "ieee1788", "gladman"),
    c("neumaier"),
    c("gladman"),
    c("muller"),
    c("revol", "rump2010"),
    c("wickham")))

  apply_to("R/expression.R", list(
    c("moore"),
    c("moore", "neumaier"),
    c("moore", "neumaier")))
}

## Sesion 81: los seis archivos de la 79, mas el archivo de paquete (no estaba
## en el mapa de REFERENCIAS_APA7.md y se agrega ahi; sus referencias son las
## del panorama). Los localizadores que estaban dentro de las referencias se
## mueven a la prosa A MANO despues de este barrido, bloque por bloque, porque
## el guion solo reescribe la lista.
apply_to("R/rounding.R", list(
  c("rzbm"),
  c("rzbm", "ieee754"),
  c("rzbm", "ieee754"),
  c("rump2010")))

apply_to("R/interval-class.R", list(
  c("ieee1788"),
  c("ieee1788"),
  c("ieee1788"),
  c("neumaier"),
  c("ieee1788"),
  c("wickham"),
  c("ieee1788")))

apply_to("R/arithmetic.R", list(
  c("ieee1788", "moore"),
  c("ieee1788"),
  c("hansen", "neumaier"),
  c("ieee1788", "moore"),
  c("ieee1788")))

apply_to("R/mpfr-bridge.R", list(
  c("maechler"),
  c("revol"),
  c("fousse"),
  c("revol")))

apply_to("R/operator-table.R", list(
  c("gladman", "ieee754"),
  c("gladman"),
  c("moore")))

apply_to("R/conditions.R", list(
  c("wickham"),
  c("maechler", "fousse")))

apply_to("R/RobustArithmetic-package.R", list(
  c("ieee1788_2015", "rzbm", "rump2010", "neumaier", "hansen", "moore",
    "tucker")))
