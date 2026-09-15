## GATE 2 -- the elementary layer against multiprecision evaluation.
##
## The fast level of an elementary function is an included correctly rounded
## binary64 evaluation widened by a slack declared from its half-unit bound and
## never tuned. Two things have to be true of it, and they are different claims
## tested differently.
##
## The first is containment at a point: the correctly rounded value of the
## function must lie inside the enclosure of the point interval. That tests the
## slack and nothing else.
##
## The second is containment over a box: the value at every point of the box
## must lie inside the enclosure of the box. That tests the shape table and the
## search for interior extrema, which the point test cannot reach, and it is
## where reading only the endpoints of a periodic function would be caught.
##
## The third figure is a measurement: how much of the declared slack the
## included route actually spends. A gate that passes without saying by how
## much cannot tell a slack that is snug from one that is absurd, so the margin
## is computed and printed. It is never used to change the slack; the
## pre-registration in dev/PREREGISTRO_FASE_2.md forbids that, and a point
## outside is a finding to investigate rather than a number to enlarge.
##
## The referent is MPFR at 300 bits, external to the fast level in code, in
## rounding convention and in representation.

gate2_bits <- 300L

## Points spread over exponent bands inside the domain of the function, with the
## awkward cases injected by name: the ends of the domain, zero, the powers of
## two, and the multiples of a quarter period for the trigonometric ones.
gate2_points <- function(fun, n, seed) {
  set.seed(seed)
  d <- .ra_domains[[fun]]
  lo <- if (is.finite(d$lo)) d$lo else -Inf
  hi <- if (is.finite(d$hi)) d$hi else Inf

  if (is.finite(lo) && is.finite(hi)) {
    ## a bounded domain: uniform, plus clustering at both ends
    x <- c(runif(n * 0.8, lo, hi),
           lo + (hi - lo) * 2^-runif(n * 0.1, 0, 50),
           hi - (hi - lo) * 2^-runif(n * 0.1, 0, 50))
  } else if (is.finite(lo)) {
    ## a half line: exponent bands above the finite end
    x <- lo + 2^runif(n, -60, 60)
  } else {
    ## the whole line: exponent bands, both signs
    x <- 2^runif(n, -60, 60) * sample(c(-1, 1), n, replace = TRUE)
  }

  extra <- c(0, 1, -1, 0.5, -0.5, 2^-1074, 2^-1022, 2^-52, 2^52,
             pi / 2, -pi / 2, pi, -pi, 3 * pi / 2, 2 * pi, -2 * pi,
             pi / 4, 1e6, 1e15)
  if (is.finite(lo)) extra <- c(extra, lo, ra_succ(lo), lo + 1e-12)
  if (is.finite(hi)) extra <- c(extra, hi, ra_pred(hi), hi - 1e-12)
  x <- c(x, extra)
  keep <- x >= lo & x <= hi & is.finite(x)
  x <- x[keep]
  ## the domain ends themselves are kept only when the domain contains them
  if (d$lo_open) x <- x[x != d$lo]
  if (d$hi_open) x <- x[x != d$hi]
  x
}

## The correctly rounded value, and the size of one unit in the last place of
## it, both from the referent.
gate2_reference <- function(fun, x, bits = gate2_bits) {
  m <- Rmpfr::mpfr(x, bits)
  y <- do.call(fun, list(m))
  list(lo = ra_to_double(y, "down"), hi = ra_to_double(y, "up"), mpfr = y)
}

## The error of a binary64 value against the exact one, in units in the last
## place, computed in multiprecision. Computing it in binary64 quantises it to
## whole units and cannot resolve the declared half-unit bound.
gate2_ulp_error <- function(y, ref, bits = gate2_bits) {
  u <- ra_succ(abs(y)) - abs(y)
  ok <- is.finite(y) & u > 0 & is.finite(u)
  err <- rep(NA_real_, length(y))
  if (!any(ok)) return(err)
  d <- abs(Rmpfr::mpfr(y[ok], bits) - ref$mpfr[ok]) / Rmpfr::mpfr(u[ok], bits)
  err[ok] <- Rmpfr::asNumeric(d)
  err
}

test_that("GATE 2A: the correctly rounded value is inside the fast enclosure", {
  skip_on_cran()
  skip_if_not(ra_has_mpfr(), "the gate needs Rmpfr")

  n <- as.integer(Sys.getenv("RA_GATE2_N", "1000000"))
  funs <- ra_operator_table()$fun
  report <- data.frame(fun = funs, n = 0L, e_obs = NA_real_,
                       e_bound = ra_operator_table()$ulp,
                       slack = vapply(funs, ra_slack, integer(1)),
                       used = NA_real_, stringsAsFactors = FALSE)

  ## The sweep runs in chunks. A million multiprecision numbers held at once is
  ## a gigabyte of referent, and a gate that fails by exhausting memory reports
  ## nothing about the thing it was built to test.
  chunk <- 50000L

  for (i in seq_along(funs)) {
    f <- funs[i]
    x <- gate2_points(f, n, seed = 800L + i)
    outside <- 0L
    worst <- NA_real_
    for (from in seq.int(1L, length(x), by = chunk)) {
      xs <- x[from:min(from + chunk - 1L, length(x))]
      enc <- ra_elem(f, ra_interval(xs, xs))
      ref <- gate2_reference(f, xs)
      bad <- ra_inf(enc) > ref$lo | ra_sup(enc) < ref$hi
      bad[is.na(bad)] <- TRUE
      outside <- outside + sum(bad)
      evaluator <- get(".ra_cr", envir = asNamespace("RobustArithmetic"))
      err <- gate2_ulp_error(evaluator(f, xs), ref)
      if (any(!is.na(err))) worst <- max(worst, max(err, na.rm = TRUE),
                                         na.rm = TRUE)
    }
    ## containment is the claim, asserted absolutely
    expect_identical(outside, 0L,
                     label = paste0("GATE 2A ", f, ": points outside the ",
                                    "enclosure (of ", length(x), ")"))
    ## the margin is a measurement, over the very points this gate swept
    report$n[i] <- length(x)
    report$e_obs[i] <- worst
    report$used[i] <- worst / report$slack[i]
  }

  cat("\nGATE 2 observed error of the included evaluation path, in ulps,",
      "against its declared bound and slack:\n")
  print(report, row.names = FALSE, digits = 4)
  tight <- report$fun[!is.na(report$used) & report$used > 0.80]
  cat("Slacks the sweep found tight (used above 0.80): ",
      if (length(tight)) paste(tight, collapse = ", ") else "none", "\n",
      sep = "")
  above <- report$fun[!is.na(report$e_obs) &
                        report$e_obs > report$e_bound]
  cat("Functions where the included path exceeded its declared bound: ",
      if (length(above)) paste(above, collapse = ", ") else "none", "\n",
      sep = "")
  ## The included route must respect both its half-unit bound and the wider
  ## enclosure budget.
  expect_true(all(is.na(report$e_obs) | report$e_obs <= report$e_bound))
  expect_true(all(is.na(report$e_obs) | report$e_obs <= report$slack))
  ## The exported measurement is a standalone instrument over its own mesh, and
  ## it has to reach the same verdict about the declared bound.
  m <- ra_measure_library_error(n = 5000L, seed = 80L)
  expect_true(all(!is.na(m$observed) & m$observed <= 0.5))
})

test_that("GATE 2B: every point of a box is inside the enclosure of the box", {
  skip_on_cran()
  skip_if_not(ra_has_mpfr(), "the gate needs Rmpfr")

  n_box <- as.integer(Sys.getenv("RA_GATE2_BOXES", "10000"))
  n_in <- 100L
  funs <- ra_operator_table()$fun

  for (i in seq_along(funs)) {
    f <- funs[i]
    set.seed(1800L + i)
    d <- .ra_domains[[f]]
    ## boxes of widely differing widths, since a narrow box tests the endpoints
    ## and a wide one tests the search for interior extrema
    centre <- gate2_points(f, n_box, seed = 1900L + i)
    centre <- centre[seq_len(min(n_box, length(centre)))]
    w <- abs(centre) * 2^runif(length(centre), -50, 4) +
      2^runif(length(centre), -60, 3)
    a <- pmax(centre - w / 2, d$lo)
    b <- pmin(centre + w / 2, d$hi)
    if (d$lo_open) a <- pmax(a, ra_succ(d$lo))
    if (d$hi_open) b <- pmin(b, ra_pred(d$hi))
    ok <- is.finite(a) & is.finite(b) & a <= b
    a <- a[ok]
    b <- b[ok]
    enc <- ra_elem(f, ra_interval(a, b))

    violations <- 0L
    for (k in seq_len(n_in)) {
      t <- runif(length(a))
      p <- a + t * (b - a)
      p <- pmin(pmax(p, a), b)
      ref <- gate2_reference(f, p)
      bad <- ra_inf(enc) > ref$lo | ra_sup(enc) < ref$hi
      bad[is.na(bad)] <- TRUE
      violations <- violations + sum(bad)
    }
    expect_identical(violations, 0L,
                     label = paste0("GATE 2B ", f, ": interior points outside ",
                                    "the enclosure of their box (", length(a),
                                    " boxes x ", n_in, " points)"))
  }
})

test_that("CP-1: the included evaluator respects its half-unit bound", {
  skip_on_cran()
  skip_if_not(ra_has_mpfr(), "the control needs Rmpfr")

  evaluator <- get(".ra_cr", envir = asNamespace("RobustArithmetic"))
  maxima <- numeric(0)
  for (f in ra_operator_table()$fun) {
    x <- gate2_points(f, 20000L, seed = 2600L + nchar(f) * 7L)
    ref <- gate2_reference(f, x)
    err <- gate2_ulp_error(evaluator(f, x), ref)
    maxima[f] <- max(err, na.rm = TRUE)
    expect_true(all(is.na(err) | err <= 0.5),
                label = paste0("CP-1 ", f, ": declared bound"))
  }
  cat("\nCP-1 maximum errors of the included evaluator, by function:\n")
  print(maxima)
})

test_that("CP-2: an injected error beyond the slack breaks containment", {
  ## This control proves that the containment comparison can fail. The injected
  ## evaluator is four successors above the included result, while the declared
  ## enclosure budget returns only two steps toward the exact value.
  skip_on_cran()
  skip_if_not(ra_has_mpfr(), "the control needs Rmpfr")

  evaluator <- get(".ra_cr", envir = asNamespace("RobustArithmetic"))
  x <- seq(0.1, 1, length.out = 2001L)
  ref <- gate2_reference("sin", x)
  clean_enc <- ra_elem("sin", ra_interval(x, x))
  clean <- sum(ra_inf(clean_enc) > ref$lo | ra_sup(clean_enc) < ref$hi)

  shifted <- evaluator("sin", x)
  for (k in seq_len(4L)) shifted <- ra_succ(shifted)
  bad_lo <- shifted
  bad_hi <- shifted
  for (k in seq_len(2L)) {
    bad_lo <- ra_pred(bad_lo)
    bad_hi <- ra_succ(bad_hi)
  }
  violations <- sum(bad_lo > ref$lo | bad_hi < ref$hi)
  expect_gt(violations, 0L)
  expect_identical(clean, 0L)
})

test_that("GATE 2D: the rigorous level is never wider than the fast one", {
  skip_on_cran()
  skip_if_not(ra_has_mpfr(), "the gate needs Rmpfr")

  for (i in seq_along(ra_operator_table()$fun)) {
    f <- ra_operator_table()$fun[i]
    x <- gate2_points(f, 1000L, seed = 4200L + i)
    x <- x[seq_len(min(1000L, length(x)))]
    fast <- ra_elem(f, ra_interval(x, x), level = "fast")
    rig <- ra_elem(f, ra_interval(x, x), level = "rigorous", precision = 106L)
    expect_true(all(ra_wid(rig) <= ra_wid(fast), na.rm = TRUE),
                label = paste0("GATE 2D ", f, ": rigorous no wider than fast"))
    expect_true(all(ra_inf(rig) >= ra_inf(fast) &
                      ra_sup(rig) <= ra_sup(fast), na.rm = TRUE),
                label = paste0("GATE 2D ", f, ": rigorous inside fast"))
  }
})
