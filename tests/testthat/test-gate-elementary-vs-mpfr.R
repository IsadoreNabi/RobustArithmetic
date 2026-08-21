## GATE 2 -- the elementary layer against multiprecision evaluation.
##
## The fast level of an elementary function is a library call widened by a slack
## that was declared from a published error and never tuned. Two things have to
## be true of it, and they are different claims tested differently.
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
## The third figure is not a claim but a measurement: how much of the declared
## slack the library actually spends. A gate that passes without saying by how
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

## The correctly rounded value: whichever of the two bracketing doubles is
## nearer the exact one, decided in multiprecision because deciding it in
## binary64 is deciding it with the instrument under test.
gate2_nearest <- function(ref, bits = gate2_bits) {
  lo <- Rmpfr::mpfr(ref$lo, bits)
  hi <- Rmpfr::mpfr(ref$hi, bits)
  take_hi <- as.logical((ref$mpfr - lo) > (hi - ref$mpfr))
  out <- ref$lo
  take_hi[is.na(take_hi)] <- FALSE
  out[take_hi] <- ref$hi[take_hi]
  out
}

## The error of a library value against the exact one, in units in the last
## place, computed in multiprecision. Computing it in binary64 quantises it to
## whole units, which is coarser than every figure it is meant to resolve: the
## published errors run from 0.500 to 2.21, and an instrument that can only
## answer 1 or 2 cannot see any of them.
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
                       e_pub = ra_operator_table()$ulp,
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
      err <- gate2_ulp_error(do.call(f, list(xs)), ref)
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

  cat("\nGATE 2 observed error of the evaluation path in use, in ulps,",
      "against the published figure and the declared slack:\n")
  print(report, row.names = FALSE, digits = 4)
  tight <- report$fun[!is.na(report$used) & report$used > 0.80]
  cat("Slacks the sweep found tight (used above 0.80): ",
      if (length(tight)) paste(tight, collapse = ", ") else "none", "\n",
      sep = "")
  above <- report$fun[!is.na(report$e_obs) & report$e_obs > report$e_pub]
  cat("Functions where the path in use exceeded the published scalar figure: ",
      if (length(above)) paste(above, collapse = ", ") else "none", "\n",
      sep = "")
  ## reading 1 of the pre-registration: the observed error never exceeds the
  ## slack, which is the same statement as containment, said in ulps
  expect_true(all(is.na(report$e_obs) | report$e_obs <= report$slack))
  ## reading 2: exceeding the published figure is a finding and not a failure,
  ## and the two must not be confused. The figure above is the margin over the
  ## very points this gate asserted containment on; the exported measurement is
  ## a standalone instrument over its own mesh, and it has to reach the same
  ## verdict about the slack or one of the two is measuring something else.
  m <- ra_measure_library_error(n = 5000L)
  expect_true(all(is.na(m$observed) | m$observed <= m$slack))
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

test_that("CP-1: the sweep finds points where the library is not correctly rounded", {
  ## If the library agreed with the correctly rounded value everywhere on the
  ## mesh, gate 2A would be passing for the wrong reason and the slack would
  ## never be exercised. The gate is only meaningful if such points exist, so
  ## their existence is asserted rather than assumed.
  skip_on_cran()
  skip_if_not(ra_has_mpfr(), "the control needs Rmpfr")

  counts <- integer(0)
  for (f in ra_operator_table()$fun) {
    x <- gate2_points(f, 20000L, seed = 2600L + nchar(f) * 7L)
    ref <- gate2_reference(f, x)
    y <- do.call(f, list(x))
    ## not correctly rounded means the library value is not the nearer of the
    ## two doubles bracketing the exact one, which is a half-unit question and
    ## has to be decided in multiprecision
    near <- gate2_nearest(ref)
    off <- is.finite(y) & is.finite(near) & y != near
    counts[f] <- sum(off)
    if (any(off)) {
      ## and every such point is inside the fast enclosure, which is the claim
      xi <- x[off]
      enc <- ra_elem(f, ra_interval(xi, xi))
      ri <- gate2_reference(f, xi)
      expect_true(all(ra_inf(enc) <= ri$lo & ra_sup(enc) >= ri$hi),
                  label = paste0("CP-1 ", f, ": the mis-rounded points are ",
                                 "still enclosed (", sum(off), " of them)"))
    }
  }
  cat("\nCP-1 mis-rounded points found on the mesh, by function:\n")
  print(counts)
  ## the control fires if the library is imperfect somewhere; a mesh on which
  ## it were perfect everywhere would make gate 2A pass for the wrong reason
  expect_true(sum(counts) > 0L)
})

test_that("CP-2: a slack of zero must break containment on the same data", {
  ## The symmetric control, and the one that proves the harness can fail. With
  ## the slack removed the enclosure is the library value bracketed by one
  ## outward step, which cannot cover an error above one unit in the last place.
  skip_on_cran()
  skip_if_not(ra_has_mpfr(), "the control needs Rmpfr")

  ns <- asNamespace("RobustArithmetic")
  old <- get(".ra_ulp_glibc", envir = ns)
  unlockBinding(".ra_ulp_glibc", ns)
  on.exit({
    assign(".ra_ulp_glibc", old, envir = ns)
    lockBinding(".ra_ulp_glibc", ns)
  }, add = TRUE)

  violations <- 0L
  clean <- 0L
  for (f in c("tanh", "sinh", "cosh", "log10")) {
    x <- gate2_points(f, 50000L, seed = 3100L + nchar(f))
    ref <- gate2_reference(f, x)

    assign(".ra_ulp_glibc", old, envir = ns)
    enc_ok <- ra_elem(f, ra_interval(x, x))
    clean <- clean + sum(ra_inf(enc_ok) > ref$lo | ra_sup(enc_ok) < ref$hi,
                         na.rm = TRUE)

    zeroed <- old
    zeroed[f] <- 0
    assign(".ra_ulp_glibc", zeroed, envir = ns)
    enc_bad <- ra_elem(f, ra_interval(x, x))
    violations <- violations + sum(ra_inf(enc_bad) > ref$lo |
                                     ra_sup(enc_bad) < ref$hi, na.rm = TRUE)
  }
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
