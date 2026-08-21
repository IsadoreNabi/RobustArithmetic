## GATE 1 -- the kernel against multiprecision arithmetic.
##
## The kernel claims two things about every operation. The first is containment:
## the exact result of the operation, on any pair of points drawn from the
## argument intervals, lies inside the interval returned. The second is
## tightness: the interval returned is no wider than the optimal one by more
## than the outward steps the design allows. The first is the guarantee and is
## asserted absolutely; the second is a quality claim and is reported with its
## figure rather than hidden behind a pass.
##
## The referent is MPFR at 300 bits, which is external to everything the kernel
## does: it shares no code, no rounding convention and no representation. Two
## hundred and forty-seven bits above binary64 is enough that the exact result
## of one operation on two binary64 arguments is represented without error for
## the three operations that are exact in a wide enough format, and to well
## beyond any width this comparison can see for the one that is not.

## Count the representable doubles between two values, capped, so that a
## tightness claim is a count and not an approximation of one.
steps_between <- function(from, to, cap = 8L) {
  n <- integer(length(from))
  z <- from
  for (k in seq_len(cap)) {
    moving <- is.finite(z) & is.finite(to) & z < to
    if (!any(moving)) break
    z[moving] <- ra_next_up_bits(z[moving])
    n[moving] <- n[moving] + 1L
  }
  n
}

## Random endpoints spanning many magnitudes and both signs, plus deliberate
## awkward cases: zero endpoints, intervals straddling zero, and point
## intervals, which are where an endpoint formula written by cases goes wrong.
random_intervals <- function(n, seed) {
  set.seed(seed)
  mag <- 2^runif(n, -40, 40)
  a <- mag * sample(c(-1, 1), n, replace = TRUE) * runif(n)
  b <- mag * sample(c(-1, 1), n, replace = TRUE) * runif(n)
  lo <- pmin(a, b)
  hi <- pmax(a, b)
  k <- max(1L, n %/% 20L)
  lo[seq_len(k)] <- 0
  hi[k + seq_len(k)] <- 0
  lo[2 * k + seq_len(k)] <- hi[2 * k + seq_len(k)]
  i <- 3 * k + seq_len(k)
  lo[i] <- -abs(hi[i])
  ## The injections above can invert a pair; the interval is whichever way
  ## round the two endpoints came out, which is also how the awkward cases end
  ## up straddling zero rather than sitting beside it.
  a <- pmin(lo, hi)
  b <- pmax(lo, hi)
  ra_interval(a, b)
}

## One point drawn from each interval, as a double, guaranteed to be inside.
point_in <- function(x, seed) {
  set.seed(seed)
  t <- runif(length(x))
  p <- x$lo + t * (x$hi - x$lo)
  p <- pmin(pmax(p, x$lo), x$hi)
  p[!is.finite(p)] <- x$lo[!is.finite(p)]
  p
}

test_that("GATE 1: every operation of the kernel encloses the exact result", {
  skip_on_cran()
  skip_if_not(ra_has_mpfr(), "the gate needs Rmpfr")
  n <- 100000L
  prec <- 300L

  x <- random_intervals(n, 101L)
  y <- random_intervals(n, 202L)
  px <- point_in(x, 303L)
  py <- point_in(y, 404L)
  mx <- Rmpfr::mpfr(px, prec)
  my <- Rmpfr::mpfr(py, prec)

  ops <- list(
    add = list(ivl = function(a, b) a + b, pt = function(a, b) a + b),
    sub = list(ivl = function(a, b) a - b, pt = function(a, b) a - b),
    mul = list(ivl = function(a, b) a * b, pt = function(a, b) a * b),
    div = list(ivl = function(a, b) a / b, pt = function(a, b) a / b)
  )

  for (nm in names(ops)) {
    res <- ops[[nm]]$ivl(x, y)
    exact <- ops[[nm]]$pt(mx, my)
    usable <- !ra_is_empty(res) & !ra_is_nai(res)
    if (identical(nm, "div")) usable <- usable & py != 0
    expect_true(any(usable), info = nm)

    lo <- Rmpfr::mpfr(ra_inf(res)[usable], prec)
    hi <- Rmpfr::mpfr(ra_sup(res)[usable], prec)
    e <- exact[usable]
    ## Containment, asserted absolutely. This is the guarantee.
    expect_true(all(lo <= e), info = paste(nm, "lower"))
    expect_true(all(e <= hi), info = paste(nm, "upper"))
  }
})

test_that("GATE 1: the width is within two steps of the optimum in at least 99 percent", {
  skip_on_cran()
  skip_if_not(ra_has_mpfr(), "the gate needs Rmpfr")
  n <- 100000L
  prec <- 300L

  x <- random_intervals(n, 111L)
  y <- random_intervals(n, 222L)

  ## The optimal enclosure, computed in multiprecision from the same endpoint
  ## formulas and then rounded outward once, which is the tightest pair of
  ## doubles that contains the exact range.
  mxl <- Rmpfr::mpfr(ra_inf(x), prec)
  mxh <- Rmpfr::mpfr(ra_sup(x), prec)
  myl <- Rmpfr::mpfr(ra_inf(y), prec)
  myh <- Rmpfr::mpfr(ra_sup(y), prec)

  optimum <- list(
    add = list(lo = mxl + myl, hi = mxh + myh),
    sub = list(lo = mxl - myh, hi = mxh - myl),
    mul = NULL,
    div = NULL
  )
  pmin4 <- function(a, b, c, d) pmin(pmin(a, b), pmin(c, d))
  pmax4 <- function(a, b, c, d) pmax(pmax(a, b), pmax(c, d))
  optimum$mul <- list(
    lo = pmin4(mxl * myl, mxl * myh, mxh * myl, mxh * myh),
    hi = pmax4(mxl * myl, mxl * myh, mxh * myl, mxh * myh)
  )
  straddles <- ra_inf(y) <= 0 & ra_sup(y) >= 0
  safe <- !straddles
  optimum$div <- list(
    lo = pmin4(mxl[safe] / myl[safe], mxl[safe] / myh[safe],
               mxh[safe] / myl[safe], mxh[safe] / myh[safe]),
    hi = pmax4(mxl[safe] / myl[safe], mxl[safe] / myh[safe],
               mxh[safe] / myl[safe], mxh[safe] / myh[safe])
  )

  results <- list(add = x + y, sub = x - y, mul = x * y, div = x / y)
  keep <- list(add = rep(TRUE, n), sub = rep(TRUE, n), mul = rep(TRUE, n),
               div = safe)

  report <- list()
  for (nm in names(results)) {
    k <- keep[[nm]]
    res <- results[[nm]][k]
    opt_lo <- ra_to_double(optimum[[nm]]$lo, "down")
    opt_hi <- ra_to_double(optimum[[nm]]$hi, "up")
    ok <- is.finite(opt_lo) & is.finite(opt_hi) &
      is.finite(ra_inf(res)) & is.finite(ra_sup(res))
    ## The optimum must itself be enclosed: the kernel is never tighter than
    ## the tightest valid pair of doubles. This is a second containment claim
    ## and it is asserted absolutely.
    expect_true(all(ra_inf(res)[ok] <= opt_lo[ok]), info = paste(nm, "opt lo"))
    expect_true(all(ra_sup(res)[ok] >= opt_hi[ok]), info = paste(nm, "opt hi"))

    excess <- steps_between(ra_inf(res)[ok], opt_lo[ok]) +
      steps_between(opt_hi[ok], ra_sup(res)[ok])
    report[[nm]] <- c(n = sum(ok), mean = mean(excess),
                      q99 = unname(stats::quantile(excess, 0.99)),
                      max = max(excess))
    expect_lte(unname(stats::quantile(excess, 0.99)), 2)
  }

  ## Reported, not masked: the figure is printed so that a later run can be
  ## compared against it rather than against the threshold alone.
  tab <- do.call(rbind, report)
  cat("\nGATE 1 excess width in steps (lower + upper), by operation:\n")
  print(round(tab, 4L))
})

test_that("GATE 1: the derived operations enclose as well", {
  skip_on_cran()
  skip_if_not(ra_has_mpfr(), "the gate needs Rmpfr")
  n <- 30000L
  prec <- 300L
  x <- random_intervals(n, 555L)
  px <- point_in(x, 666L)
  mx <- Rmpfr::mpfr(px, prec)

  checks <- list(
    sqr = list(ivl = ra_sqr, pt = function(a) a^2),
    abs = list(ivl = ra_abs, pt = abs),
    neg = list(ivl = ra_neg, pt = function(a) -a),
    pow2 = list(ivl = function(a) ra_pown(a, 2L), pt = function(a) a^2),
    pow3 = list(ivl = function(a) ra_pown(a, 3L), pt = function(a) a^3),
    pow5 = list(ivl = function(a) ra_pown(a, 5L), pt = function(a) a^5)
  )
  for (nm in names(checks)) {
    res <- checks[[nm]]$ivl(x)
    e <- checks[[nm]]$pt(mx)
    ok <- !ra_is_empty(res) & !ra_is_nai(res) &
      is.finite(ra_inf(res)) & is.finite(ra_sup(res))
    expect_true(all(Rmpfr::mpfr(ra_inf(res)[ok], prec) <= e[ok]),
                info = paste(nm, "lower"))
    expect_true(all(e[ok] <= Rmpfr::mpfr(ra_sup(res)[ok], prec)),
                info = paste(nm, "upper"))
  }
})

test_that("POSITIVE CONTROL: an inward step must break the containment gate", {
  ## The gate above passes because the kernel rounds outward. If it rounded
  ## inward instead, or not at all, the gate must fail; otherwise the gate is
  ## measuring nothing. Here the outward step is replaced by an inward one on a
  ## sum whose exact value is known not to be representable.
  skip_on_cran()
  skip_if_not(ra_has_mpfr(), "the gate needs Rmpfr")
  set.seed(77L)
  a <- runif(5000L)
  b <- runif(5000L)
  inward_lo <- ra_succ(a + b)
  inward_hi <- ra_pred(a + b)
  exact <- Rmpfr::mpfr(a, 300L) + Rmpfr::mpfr(b, 300L)
  violated <- sum(Rmpfr::mpfr(inward_lo, 300L) > exact) +
    sum(exact > Rmpfr::mpfr(inward_hi, 300L))
  expect_gt(violated, 0L)

  ## And the real kernel must not violate it on the same data.
  res <- ra_interval(a, a) + ra_interval(b, b)
  expect_true(all(Rmpfr::mpfr(ra_inf(res), 300L) <= exact))
  expect_true(all(exact <= Rmpfr::mpfr(ra_sup(res), 300L)))
})
