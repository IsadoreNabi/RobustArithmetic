## Mueve a la prosa los localizadores que vivian dentro de los bloques
## @references (regla 2 de dev/REFERENCIAS_APA7.md: APA 7 pone el localizador
## en la cita, no en la lista; en Roxygen va en la prosa). Mecanico y anclado
## a la estructura: para el bloque @references numero k de cada archivo, la
## oracion se inserta como parrafo final de la seccion que PRECEDE al
## "@section Dependencies:" mas cercano por arriba, que es donde el argumento
## del localizador vive. Se corre UNA vez; correrlo dos veces duplicaria los
## parrafos, y el control de abajo lo impide.

sentences <- list(
  "R/rounding.R" = list(
    `1` = paste("The validity and exactness claims are Theorems 2.1 and 2.2 of",
                "Rump et al. (2009), whose proofs are machine-checked in Coq."),
    `2` = paste("The comparison point in the floating-point standard is the",
                "nextUp operation of IEEE Std 754-2019, clause 5.3.1."),
    `3` = paste("The comparison point in the floating-point standard is the",
                "nextDown operation of IEEE Std 754-2019, clause 5.3.1.")),
  "R/interval-class.R" = list(
    `1` = paste("The definition of an interval is subclause 4.2 of IEEE Std",
                "1788.1-2017; the decorations are its subclause 5.2, the",
                "permitted combinations 5.4, and the initial decoration 5.5.1."),
    `2` = paste("The definitions are subclauses 4.5.1 and 5.3 of IEEE Std",
                "1788.1-2017."),
    `3` = paste("The operations follow subclauses 4.5.7 and 5.5.2 of IEEE Std",
                "1788.1-2017."),
    `4` = paste("The definitions of the midpoint, radius, magnitude and",
                "mignitude are section 1.6 of Neumaier (1990)."),
    `5` = paste("The text representation follows subclause 6.9 of IEEE Std",
                "1788.1-2017."),
    `6` = paste("Chapter 13 of Wickham (2019) treats S3 vector classes and the",
                "methods they must carry."),
    `7` = paste("The permitted combinations and the repairing operation are",
                "subclauses 5.4 and 5.5.2 of IEEE Std 1788.1-2017.")),
  "R/arithmetic.R" = list(
    `1` = paste("The operations are subclause 4.5.2 and Table 4.1 of IEEE Std",
                "1788.1-2017; chapters 2 and 4 of Moore et al. (2009) are the",
                "textbook treatment."),
    `2` = paste("Table 4.1 of IEEE Std 1788.1-2017 gives the division its",
                "domain: the plane minus the axis where the divisor vanishes."),
    `3` = paste("The case table implemented here is equations (9.2.3) and",
                "(9.2.4) in section 9.2 of Hansen and Walster (2004); the",
                "comparison with the Krawczyk operator is section 5.1 of",
                "Neumaier (1990)."),
    `4` = paste("The entries for the square, the absolute value and the",
                "integer power are in Table 4.1 of IEEE Std 1788.1-2017;",
                "chapter 5 of Moore et al. (2009) treats the dependency these",
                "forms avoid."),
    `5` = paste("The classification and its decoration rule are subclauses",
                "4.5.4 and 5.7.1 of IEEE Std 1788.1-2017.")),
  "R/operator-table.R" = list(
    `1` = paste("The error figures are Table 3, column GNU libc 2.43, of",
                "Gladman et al. (2026), which is the report the documentation",
                "of the GNU C Library refers to for its accuracy figures; the",
                "correct rounding of the square root is clause 5.4.1 of IEEE",
                "Std 754-2019."),
    `2` = "The published figures are Table 3 of Gladman et al. (2026).",
    `3` = paste("Chapter 5 of Moore et al. (2009) treats interval extensions",
                "of expressions and the role of the derivative in the",
                "centered form.")),
  "R/conditions.R" = list(
    `1` = paste("Chapter 8 of Wickham (2019) treats the condition system and",
                "the classing of conditions for selective handling."))
)

## Corrida unica: dos de las oraciones comparten sus primeros cuarenta
## caracteres (nextUp/nextDown), asi que un guardian por prefijo dispara en
## falso; el guardian es un centinela de archivo.
stopifnot(!file.exists("dev/.locators_moved"))

for (path in names(sentences)) {
  ln <- readLines(path)
  refs <- grep("^#' @references$", ln)
  deps <- grep("^#' @section Dependencies:$", ln)
  spec <- sentences[[path]]
  ## de atras hacia adelante para que los numeros de linea no se corran
  for (k in rev(as.integer(names(spec)))) {
    s <- spec[[as.character(k)]]
    d <- max(deps[deps < refs[k]])
    body <- paste0("#'   ", strwrap(s, width = 74L))
    ln <- append(ln, c("#'", body), after = d - 1L)
    refs <- grep("^#' @references$", ln)
    deps <- grep("^#' @section Dependencies:$", ln)
  }
  writeLines(ln, path)
  cat(path, ":", length(spec), "localizadores movidos a la prosa\n")
}
writeLines(format(Sys.Date()), "dev/.locators_moved")
