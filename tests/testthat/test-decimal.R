## The printed line is an assertion, and this file is where it is checked
## against something outside itself. One oracle is Rmpfr: the decimal string is
## read exactly at four hundred bits and compared with the endpoint, which is
## the criterion of 6.6.2 and 6.8.3 and not the weaker round trip through a
## double. Where Rmpfr is unavailable, an exact base-R referent reconstructs
## the binary endpoint and compares decimal integers digit by digit, because a
## gate that only runs on one machine is not a gate.

## the values a decimal renderer breaks on, gathered rather than sampled:
## exact decimals, values that only look like them, both ends of the exponent
## range, the subnormals, the powers of two, and the ties
.ra_adversarial <- function() {
  c(0.1, 0.2, 0.3, -0.1, 0.5, -2.5, 3.75, 1, 2, 10, 1e-3, 1e3,
    pi, -pi, sqrt(2), 1/3, 2/3, 0.1 + 5e-17, 1 - 2^-53,
    2^-23, 2^-52, 2^-1022, 2^-1073, 2^-1074, 5e-324,
    1e-300, 1e-30, 1e-8, 1e-5, 1e15, 1e16, 1e22, 1e23, 1e300,
    .Machine$double.xmax, -.Machine$double.xmax, .Machine$double.eps,
    123456789012345678, 9007199254740992, 9007199254740993,
    0.30000000000000004, 4.9999999999999991)
}

.ra_random_doubles <- function(n) {
  set.seed(20260821L)
  c(stats::runif(n, -1e6, 1e6),
    stats::rnorm(n) * 10^stats::runif(n, -300, 300),
    2^round(stats::runif(n, -1070, 1020)),
    (seq_len(n)) / 7,
    sqrt(seq_len(n)))
}

## Exact base-R referent for the tests that run without Rmpfr. A double is
## read from sprintf("%a") as N * 2^e, which is its exact hexadecimal form.
## For e < 0 this is N * 5^-e * 10^e; for e >= 0 it is the integer N * 2^e.
## The products use base-10^7 limbs and factors small enough that every
## intermediate integer stays below 2^53. Decimal bounds can then be compared
## digit by digit, without sending them through R's decimal parser and without
## calling anything from R/decimal.R.
.exact_base <- 10000000

.exact_big_from_double <- function(x) {
  out <- numeric(0)
  repeat {
    q <- floor(x / .exact_base)
    out <- c(out, x - q * .exact_base)
    x <- q
    if (x == 0) return(out)
  }
}

.exact_big_mul <- function(a, m) {
  carry <- 0
  for (i in seq_along(a)) {
    z <- a[i] * m + carry
    q <- floor(z / .exact_base)
    a[i] <- z - q * .exact_base
    carry <- q
  }
  while (carry > 0) {
    q <- floor(carry / .exact_base)
    a <- c(a, carry - q * .exact_base)
    carry <- q
  }
  a
}

.exact_big_pow_mul <- function(a, b, e, chunk) {
  while (e > 0L) {
    step <- min(e, chunk)
    a <- .exact_big_mul(a, b^step)
    e <- e - step
  }
  a
}

.exact_big_character <- function(a) {
  hi <- sprintf("%.0f", a[length(a)])
  if (length(a) == 1L) return(hi)
  paste0(hi, paste(sprintf("%07.0f", rev(a[-length(a)])), collapse = ""))
}

.exact_binary_decimal <- function(v) {
  if (v == 0) return(list(sign = 0L, D = "0", p = 0L))
  h <- sprintf("%a", abs(v))
  m <- regmatches(h, regexec(
    "^0x([0-9a-f])(?:[.]([0-9a-f]+))?p([+-][0-9]+)$", h,
    perl = TRUE))[[1L]]
  stopifnot(length(m) == 4L)
  frac <- if (is.na(m[3L]) || !nzchar(m[3L])) "" else m[3L]
  hd <- strsplit(paste0(m[2L], frac), "", fixed = TRUE)[[1L]]
  value <- match(hd, c(as.character(0:9), letters[1:6])) - 1L
  N <- 0
  for (d in value) N <- N * 16 + d
  e <- as.integer(m[4L]) - 4L * nchar(frac)
  a <- .exact_big_from_double(N)
  if (e >= 0L) {
    a <- .exact_big_pow_mul(a, 2, e, 20L)
    p <- 0L
  } else {
    a <- .exact_big_pow_mul(a, 5, -e, 10L)
    p <- e
  }
  D <- .exact_big_character(a)
  while (nchar(D) > 1L && substr(D, nchar(D), nchar(D)) == "0") {
    D <- substr(D, 1L, nchar(D) - 1L)
    p <- p + 1L
  }
  list(sign = if (v < 0) -1L else 1L, D = D, p = p)
}

.exact_parse_decimal <- function(s) {
  m <- regmatches(s, regexec(
    "^(-?)([0-9]+)(?:[.]([0-9]+))?(?:e([+-][0-9]+))?$", s,
    perl = TRUE))[[1L]]
  stopifnot(length(m) == 5L)
  frac <- if (is.na(m[4L]) || !nzchar(m[4L])) "" else m[4L]
  exponent <- if (is.na(m[5L]) || !nzchar(m[5L])) 0L else as.integer(m[5L])
  D <- sub("^0+(?=[0-9])", "", paste0(m[3L], frac), perl = TRUE)
  list(sign = if (D == "0") 0L else if (m[2L] == "-") -1L else 1L,
       D = D, p = exponent - nchar(frac))
}

.exact_cmp_magnitude <- function(a, b) {
  ea <- nchar(a$D) + a$p
  eb <- nchar(b$D) + b$p
  if (ea != eb) return(if (ea < eb) -1L else 1L)
  n <- max(nchar(a$D), nchar(b$D))
  da <- utf8ToInt(paste0(a$D, strrep("0", n - nchar(a$D))))
  db <- utf8ToInt(paste0(b$D, strrep("0", n - nchar(b$D))))
  i <- which(da != db)
  if (!length(i)) return(0L)
  if (da[i[1L]] < db[i[1L]]) -1L else 1L
}

.exact_cmp_decimal_double <- function(s, v) {
  a <- .exact_parse_decimal(s)
  b <- .exact_binary_decimal(v)
  if (a$sign != b$sign) return(if (a$sign < b$sign) -1L else 1L)
  if (a$sign == 0L) return(0L)
  cmp <- .exact_cmp_magnitude(a, b)
  if (a$sign > 0L) cmp else -cmp
}

test_that("a printed bound is on the side of its endpoint that it claims", {
  skip_on_cran()
  skip_if_not_installed("Rmpfr")
  vs <- c(.ra_adversarial(), .ra_random_doubles(150L))
  vs <- vs[is.finite(vs) & vs != 0]
  bad <- character(0)
  for (v in vs) for (up in c(TRUE, FALSE)) {
    s <- .ra_bound1(v, up)
    e <- Rmpfr::mpfr(s, 400L)
    x <- Rmpfr::mpfr(v, 400L)
    if (!as.logical(if (up) e >= x else e <= x)) {
      bad <- c(bad, sprintf("%.17g up=%s -> %s", v, up, s))
    }
  }
  expect_identical(bad, character(0))
})

test_that("POSITIVE CONTROL: rounding to nearest must fail the same gate", {
  skip_on_cran()
  skip_if_not_installed("Rmpfr")
  ## if the check above can pass for a renderer that does NOT round outward,
  ## then it is not measuring what it says it measures
  vs <- c(pi, 1/3, 0.1, 0.2, sqrt(2), 0.1 + 5e-17)
  caught <- 0L
  for (v in vs) for (up in c(TRUE, FALSE)) {
    s <- format(v)                      # the R default: nearest, seven digits
    e <- Rmpfr::mpfr(s, 400L)
    x <- Rmpfr::mpfr(v, 400L)
    if (!as.logical(if (up) e >= x else e <= x)) caught <- caught + 1L
  }
  expect_gt(caught, 0L)
})

test_that("the widening is bounded by one rounding step of the arithmetic", {
  skip_on_cran()
  skip_if_not_installed("Rmpfr")
  vs <- c(.ra_adversarial(), .ra_random_doubles(150L))
  vs <- vs[is.finite(vs) & vs != 0]
  bad <- character(0)
  for (v in vs) for (up in c(TRUE, FALSE)) {
    s <- .ra_bound1(v, up)
    e <- Rmpfr::mpfr(s, 400L)
    tgt <- Rmpfr::mpfr(if (up) ra_succ(ra_succ(v)) else ra_pred(ra_pred(v)), 400L)
    if (!as.logical(if (up) e <= tgt else e >= tgt)) {
      bad <- c(bad, sprintf("%.17g up=%s -> %s", v, up, s))
    }
  }
  expect_identical(bad, character(0))
})

test_that("no shorter digit at the same length would have done", {
  skip_on_cran()
  skip_if_not_installed("Rmpfr")
  ## the bound is not merely true: moving its last digit one step toward the
  ## endpoint must break the containment, or a digit of the enclosure was
  ## thrown away for nothing
  step_in <- function(s, v, up) {
    m <- regmatches(s, regexec("^(-?)([0-9]*)[.]?([0-9]*)(?:e([+-][0-9]+))?$", s))[[1L]]
    neg <- m[2L] == "-"
    D <- paste0(m[3L], m[4L])
    ex <- if (nzchar(m[5L])) as.integer(m[5L]) else 0L
    .ra_render(neg, .ra_digits_bump(D, !xor(up, neg)), ex - nchar(m[4L]))
  }
  vs <- c(.ra_adversarial(), .ra_random_doubles(60L))
  vs <- vs[is.finite(vs) & vs != 0]
  slack <- character(0)
  for (v in vs) for (up in c(TRUE, FALSE)) {
    s2 <- step_in(.ra_bound1(v, up), v, up)
    e <- Rmpfr::mpfr(s2, 400L)
    x <- Rmpfr::mpfr(v, 400L)
    if (as.logical(if (up) e >= x else e <= x)) {
      slack <- c(slack, sprintf("%.17g up=%s -> %s", v, up, s2))
    }
  }
  expect_identical(slack, character(0))
})

test_that("printed bounds contain tightly against an exact base-R referent", {
  vs <- c(.ra_adversarial(), .ra_random_doubles(40L))
  vs <- vs[is.finite(vs) & vs != 0]
  bad <- character(0)
  for (v in vs) for (up in c(TRUE, FALSE)) {
    s <- .ra_bound1(v, up)
    cmp <- .exact_cmp_decimal_double(s, v)
    target <- if (up) ra_succ(v) else ra_pred(v)
    wide <- is.finite(target) && {
      cmp_target <- .exact_cmp_decimal_double(s, target)
      if (up) cmp_target > 0L else cmp_target < 0L
    }
    if ((if (up) cmp < 0L else cmp > 0L) || wide) {
      bad <- c(bad, sprintf("%.17g up=%s -> %s", v, up, s))
    }
  }
  expect_identical(bad, character(0))
})

test_that("POSITIVE CONTROL: the exact base-R referent detects a wrong side", {
  ## The binary64 datum called 0.1 lies strictly above the exact decimal 0.1,
  ## so that decimal is a false upper endpoint and the referent must reject it.
  expect_identical(.exact_cmp_decimal_double("0.1", 0.1), -1L)
})

test_that("numbers that are decimals exactly are printed exactly", {
  ## the price of the repair is paid only where something is owed
  expect_identical(format(ra_interval(-2.5, 3.75)), "[-2.5, 3.75]_com")
  expect_identical(format(ra_interval(1, 2)), "[1, 2]_com")
  expect_identical(format(ra_interval(0, 0.5)), "[0, 0.5]_com")
  expect_identical(format(ra_interval(-1e3, 1e3)), "[-1000, 1000]_com")
  expect_identical(.ra_bound1(2^-23, TRUE), .ra_bound1(2^-23, FALSE))
})

test_that("a degenerate interval of doubles does not print as a real number", {
  ## [1, 1] on the page would claim the exact value of pi is 1 decimal wide
  s <- format(ra_interval(pi, pi))
  parts <- regmatches(s, regexec("^\\[([^,]+), ([^]]+)\\]", s))[[1L]]
  expect_false(identical(parts[2L], parts[3L]))
})

test_that("the specials survive the renderer untouched", {
  expect_match(format(ra_empty()), "empty", fixed = TRUE)
  expect_identical(format(ra_nai()), "[nai]")
  expect_identical(format(ra_entire()), "[-Inf, Inf]_dac")
  expect_identical(format(ra_interval(0, 0)), "[0, 0]_com")
  expect_identical(length(format(ra_interval(numeric(0), numeric(0)))), 0L)
})

test_that("ra_interval_to_text emits a literal of 6.6 and refuses what it cannot do", {
  expect_identical(ra_interval_to_text(ra_entire()), "[-inf, inf]_dac")
  expect_identical(ra_interval_to_text(ra_entire(), cs = "bare"), "[-inf, inf]")
  expect_identical(ra_interval_to_text(ra_interval(-2.5, 3.75)), "[-2.5, 3.75]_com")
  expect_identical(ra_interval_to_text(ra_nai()), "[nai]")
  expect_identical(ra_interval_to_text(ra_empty()), "[empty]_trv")
  ## no asterisk on a literal, whatever the provenance
  m <- ra_set_dec(ra_interval(1, 2), "trv")
  expect_false(grepl("*", ra_interval_to_text(m), fixed = TRUE))
  expect_error(ra_interval_to_text(ra_interval(1, 2), cs = "uncertain"),
               class = "ra_bad_argument")
})

test_that("the card never states a bound tighter than the one it earned", {
  skip_if_not_installed("Rmpfr")
  cert <- ra_ball_certificate(0.2, 0.5, norm = "sup")
  txt <- paste(format(cert), collapse = " ")
  eb <- regmatches(txt, regexec("within ([^ ]+) of it", txt))[[1L]][2L]
  expect_true(as.logical(Rmpfr::mpfr(eb, 400L) >= Rmpfr::mpfr(cert$error_bound, 400L)))
  rho <- regmatches(txt, regexec("rho ([^,]+),", txt))[[1L]][2L]
  expect_true(as.logical(Rmpfr::mpfr(rho, 400L) >= Rmpfr::mpfr(cert$rho, 400L)))
})

test_that("POSITIVE CONTROL: the card as it was written must fail that gate", {
  skip_if_not_installed("Rmpfr")
  ## %.6g on an error bound is what the card used to do, and this is the value
  ## on which it stated something false
  cert <- ra_ball_certificate(0.2, 0.5, norm = "sup")
  old <- sprintf("%.6g", cert$error_bound)
  expect_false(as.logical(Rmpfr::mpfr(old, 400L) >= Rmpfr::mpfr(cert$error_bound, 400L)))
})

test_that("the radius reproduces the ball rather than bounding it", {
  ## confinement of one ball implies confinement of no other, so this number is
  ## the datum and must read back identical
  for (r in c(0.4, 1/3, 0.10000000000000003, 0.7)) {
    cert <- ra_ball_certificate(0.05, 0.5, radius = r)
    expect_true(cert$confined)
    line <- grep("confinement : certified", format(cert), value = TRUE)
    expect_identical(as.numeric(sub(".*radius ", "", line)), cert$radius)
  }
})
