## Oracle O_CR_RMPFR: correct rounding of the INSTALLED package on the machine
## where it runs, against a reference computed on that same machine with Rmpfr.
## Meant for real platforms (Windows, macOS arm64 and x86_64, sanitizer and
## valgrind builds), where the MPFR references of unit U0 are not available.
##
## Reference: y = asNumeric(f(mpfr(x, 200))). MPFR rounds the 200-bit value
## correctly, and mpfr_get_d rounds it to binary64 correctly, subnormals
## included. Double rounding cannot move the result: the known worst cases of
## binary64 elementary functions repeat fewer than 130 bits after the round bit,
## so a 200-bit correctly rounded value never lies on a binary64 midpoint unless
## the exact result is itself representable, in which case both roundings agree.
##
## Sample, reproducible with set.seed(seed): per function, one third uniform bit
## patterns, one third uniform on [-8, 8), one third within 32 ulps of k*pi/2
## with |k| <= 2^20, plus the special values.
## Also reports, without judging, how far the platform route of R (base
## functions) is from the reference: that is a measurement of the platform.
##
## Usage: Rscript O_CR_RMPFR.R [library dir] [n per function] [seed]
## Last line "O_CR_RMPFR PASS" and exit 0 only if every function has zero
## mismatches and every function was measured.
args <- commandArgs(TRUE)
if (length(args) >= 1 && nzchar(args[1])) .libPaths(c(args[1], .libPaths()))
n <- if (length(args) >= 2) as.integer(args[2]) else 60000L
seed <- if (length(args) >= 3) as.integer(args[3]) else 20260914L
if (!requireNamespace("Rmpfr", quietly = TRUE)) { cat("O_CR_RMPFR FAIL no Rmpfr\n"); quit(status = 1) }
suppressPackageStartupMessages(library(RobustArithmetic))
ns <- asNamespace("RobustArithmetic")
cat("O_CR_RMPFR package", as.character(packageVersion("RobustArithmetic")),
    "R", R.version$platform, R.version.string, "\n")
if (!exists(".ra_cr", envir = ns, inherits = FALSE)) { cat("O_CR_RMPFR FAIL no .ra_cr\n"); quit(status = 1) }
cr <- get(".ra_cr", envir = ns)
## NA and NaN are distinct outcomes of the evaluator contract and are compared
## separately; numbers compare by value with the sign of zero.
same <- function(a, b) {
  nan_a <- is.nan(a); nan_b <- is.nan(b)
  na_a <- is.na(a) & !nan_a; na_b <- is.na(b) & !nan_b
  num_a <- !is.na(a); num_b <- !is.na(b)
  (nan_a & nan_b) | (na_a & na_b) |
    (num_a & num_b & a == b & (a != 0 | (1 / a) == (1 / b))) %in% TRUE
}
set.seed(seed)
third <- n %/% 3L
bits <- matrix(as.raw(sample.int(256L, 8L * third, replace = TRUE) - 1L), nrow = 8L)
x1 <- readBin(as.vector(bits), "double", n = third, size = 8, endian = "little")
x2 <- -8 + 16 * stats::runif(third)
k <- sample(-2^20:2^20, third, replace = TRUE)
pi_half <- Rmpfr::asNumeric(Rmpfr::mpfr(k, 300) * Rmpfr::Const("pi", 300) / 2)
d <- sample(-32:32, third, replace = TRUE)
x3 <- pi_half * (1 + d * 2^-53)
x <- c(x1, x2, x3, 0, -0, Inf, -Inf, NaN, 1, -1, 5e-324, .Machine$double.xmax)
funs <- c("exp", "log", "sin", "cos", "tan", "sinh", "cosh", "tanh", "sqrt",
          "expm1", "log1p", "log2", "log10", "asin", "acos", "atan")
bad <- 0L; measured <- 0L
shape_ok <- function(v) is.double(v) && is.null(attributes(v)) && length(v) == length(x)
for (f in funs) {
  ref <- suppressWarnings(Rmpfr::asNumeric(match.fun(f)(Rmpfr::mpfr(x, 200))))
  got <- cr(f, x)
  base <- suppressWarnings(match.fun(f)(x))
  if (!shape_ok(got) || !shape_ok(ref)) {
    bad <- bad + 1L
    cat(sprintf("RMPFR fun=%-5s n=%d SHAPE evaluator=%s/%d reference=%s/%d BAD\n", f, length(x),
                typeof(got), length(got), typeof(ref), length(ref)))
    next
  }
  eq <- same(got, ref)
  compared <- sum(!is.na(eq))
  mism <- which(!eq)
  plat <- if (shape_ok(base)) sum(!same(base, ref)) else NA_integer_
  if (compared != length(x)) bad <- bad + 1L
  measured <- measured + 1L
  if (length(mism)) bad <- bad + 1L
  cat(sprintf("RMPFR fun=%-5s n=%d compared=%d mismatch=%d first=%s platform_route_mismatch=%d\n",
              f, length(x), compared, length(mism),
              if (length(mism)) sprintf("%a", x[mism[1]]) else "none", plat))
}
ok <- bad == 0L && measured == length(funs)
cat(if (ok) "O_CR_RMPFR PASS\n" else sprintf("O_CR_RMPFR FAIL bad=%d\n", bad))
quit(status = if (ok) 0L else 1L)
