## Restaura las ocho entradas de la 80 en dev/apa_entries.rds (un guion de la
## 81 las piso al reformatearlas) y agrega las siete que el barrido de los seis
## archivos de la 79 necesita. La fuente de verdad de las ocho son los bloques
## YA APLICADOS en R/elementary.R y R/expression.R: cada entrada restaurada se
## VERIFICA verbatim contra esos archivos antes de guardar.

ocho <- list(
  moore = c(
    "Moore, R. E., Kearfott, R. B., & Cloud, M. J. (2009). Introduction to interval",
    "analysis. Society for Industrial and Applied Mathematics.",
    "https://doi.org/10.1137/1.9780898717716"),
  neumaier = c(
    "Neumaier, A. (1990). Interval methods for systems of equations. Cambridge",
    "University Press. https://doi.org/10.1017/CBO9780511526473"),
  ieee1788 = c(
    "Institute of Electrical and Electronics Engineers. (2018). IEEE standard for",
    "interval arithmetic (simplified) (IEEE Std 1788.1-2017).",
    "https://doi.org/10.1109/IEEESTD.2018.8277144"),
  gladman = c(
    "Gladman, B., Innocente, V., Mather, J., Ozaki, K., & Zimmermann, P. (2026).",
    "Accuracy of mathematical functions in single, double, double extended, and",
    "quadruple precision (edition of February 2026) [Technical report].",
    "https://members.loria.fr/PZimmermann/papers/accuracy.pdf"),
  muller = c(
    "Muller, J.-M., Brunie, N., de Dinechin, F., Jeannerod, C.-P., Joldes, M.,",
    "Lefevre, V., Melquiond, G., Revol, N., & Torres, S. (2018). Handbook of",
    "floating-point arithmetic (2nd ed.). Birkhauser.",
    "https://doi.org/10.1007/978-3-319-76526-6"),
  revol = c(
    "Revol, N., & Rouillier, F. (2005). Motivations for an arbitrary precision interval",
    "arithmetic and the MPFI library. Reliable Computing, 11(4), 275-290.",
    "https://doi.org/10.1007/s11155-005-6891-y"),
  rump2010 = c(
    "Rump, S. M. (2010). Verification methods: Rigorous results using floating-point",
    "arithmetic. Acta Numerica, 19, 287-449.",
    "https://doi.org/10.1017/S096249291000005X"),
  wickham = c(
    "Wickham, H. (2019). Advanced R (2nd ed.). Chapman & Hall/CRC.",
    "https://doi.org/10.1201/9781351201315")
)

## Verificacion contra los archivos aplicados: cada entrada, con el prefijo que
## fmt() le pone, tiene que aparecer literal en al menos uno de los dos.
aplicados <- c(readLines("R/elementary.R"), readLines("R/expression.R"))
texto <- paste(aplicados, collapse = "\n")
for (k in names(ocho)) {
  bloque <- paste0("#'   ", ocho[[k]], collapse = "\n")
  stopifnot(grepl(bloque, texto, fixed = TRUE))
}
cat("Las ocho entradas verificadas verbatim contra R/elementary.R y R/expression.R.\n")

wrap <- function(s) strwrap(s, width = 78L)
nuevas <- list(
  ieee1788_2015 = wrap(paste(
    "Institute of Electrical and Electronics Engineers. (2015). IEEE standard",
    "for interval arithmetic (IEEE Std 1788-2015).",
    "https://doi.org/10.1109/IEEESTD.2015.7140721")),
  ieee754 = wrap(paste(
    "Institute of Electrical and Electronics Engineers. (2019). IEEE standard",
    "for floating-point arithmetic (IEEE Std 754-2019).",
    "https://doi.org/10.1109/IEEESTD.2019.8766229")),
  rzbm = wrap(paste(
    "Rump, S. M., Zimmermann, P., Boldo, S., & Melquiond, G. (2009). Computing",
    "predecessor and successor in rounding to nearest. BIT Numerical Mathematics,",
    "49(2), 419-431. https://doi.org/10.1007/s10543-009-0218-z")),
  hansen = wrap(paste(
    "Hansen, E., & Walster, G. W. (2004). Global optimization using interval",
    "analysis (2nd ed.). Marcel Dekker.")),
  tucker = wrap(paste(
    "Tucker, W. (2011). Validated numerics: A short introduction to rigorous",
    "computations. Princeton University Press.")),
  fousse = wrap(paste(
    "Fousse, L., Hanrot, G., Lefevre, V., Pelissier, P., & Zimmermann, P. (2007).",
    "MPFR: A multiple-precision binary floating-point library with correct",
    "rounding. ACM Transactions on Mathematical Software, 33(2), Article 13.",
    "https://doi.org/10.1145/1236463.1236468")),
  maechler = wrap(paste(
    "Maechler, M. (2024). Rmpfr: R MPFR - multiple precision floating-point",
    "reliable (Version 1.1-2) [Software]. Comprehensive R Archive Network.",
    "https://doi.org/10.32614/CRAN.package.Rmpfr"))
)

entries <- c(ocho, nuevas)
saveRDS(entries, "dev/apa_entries.rds")
cat("dev/apa_entries.rds:", length(entries), "entradas (8 restauradas + 7 nuevas).\n")
