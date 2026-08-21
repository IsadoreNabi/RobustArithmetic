## The printed line is an assertion, and this file is where it is checked
## against something outside itself. The oracle is Rmpfr: the decimal string is
## read exactly at four hundred bits and compared with the endpoint, which is
## the criterion of 6.6.2 and 6.8.3 and not the weaker round trip through a
## double. Where the oracle is unavailable a necessary condition still runs,
## because a gate that only runs on one machine is not a gate.

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

test_that("the necessary condition holds without the backend as well", {
  ## monotonicity of decimal-to-binary conversion: a decimal below the endpoint
  ## cannot convert to a double above it. This is weaker than the gate above
  ## and it runs everywhere, including on CRAN
  vs <- c(.ra_adversarial(), .ra_random_doubles(40L))
  vs <- vs[is.finite(vs) & vs != 0]
  lo <- vapply(vs, function(v) as.numeric(.ra_bound1(v, FALSE)), numeric(1L))
  hi <- vapply(vs, function(v) as.numeric(.ra_bound1(v, TRUE)), numeric(1L))
  expect_true(all(lo <= vs))
  expect_true(all(hi >= vs))
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
