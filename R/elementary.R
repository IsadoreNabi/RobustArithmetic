## The elementary functions, at two levels.
##
## An interval extension of an elementary function has to answer one question:
## what is the set of values the function takes over the argument box. For a
## monotone function that is the pair of endpoint values; for a function with an
## interior extremum it is not, and reading only the endpoints is the defect this
## file is built to prevent. The periodic functions are where the work is, and
## the file is honest about the one place the fast level gives a wide answer.
##
## Two levels share this skeleton. The fast level evaluates the correctly
## rounded binary64 implementation included with the package and widens by the
## slack declared in the operator table, which is a convention with a citation.
## The rigorous level evaluates in multiprecision, where correct rounding is a
## contract, and its enclosure is a theorem.

## How each admitted function behaves on its domain. The table is declared here
## and verified against the functions themselves by ra_verify_monotonicity(),
## because a shape table believed rather than measured is a shape table that
## eventually disagrees with a library update.
.ra_shape <- c(
  exp = "increasing", log = "increasing", log2 = "increasing",
  log10 = "increasing", log1p = "increasing", expm1 = "increasing",
  sqrt = "increasing", sinh = "increasing", tanh = "increasing",
  asin = "increasing", atan = "increasing",
  acos = "decreasing",
  cosh = "valley",
  sin = "periodic", cos = "periodic",
  tan = "poles"
)

## The domain of each function, with the endpoints marked open or closed. An
## open endpoint is not a special case in the evaluation: the library returns the
## limit there (log(0) is -Inf, log1p(-1) is -Inf), which is the right endpoint
## of the range. It is a special case for the decoration, because an argument box
## reaching an open endpoint is not contained in the domain.
.ra_domains <- list(
  exp = list(lo = -Inf, hi = Inf, lo_open = TRUE, hi_open = TRUE),
  expm1 = list(lo = -Inf, hi = Inf, lo_open = TRUE, hi_open = TRUE),
  sin = list(lo = -Inf, hi = Inf, lo_open = TRUE, hi_open = TRUE),
  cos = list(lo = -Inf, hi = Inf, lo_open = TRUE, hi_open = TRUE),
  tan = list(lo = -Inf, hi = Inf, lo_open = TRUE, hi_open = TRUE),
  sinh = list(lo = -Inf, hi = Inf, lo_open = TRUE, hi_open = TRUE),
  cosh = list(lo = -Inf, hi = Inf, lo_open = TRUE, hi_open = TRUE),
  tanh = list(lo = -Inf, hi = Inf, lo_open = TRUE, hi_open = TRUE),
  atan = list(lo = -Inf, hi = Inf, lo_open = TRUE, hi_open = TRUE),
  log = list(lo = 0, hi = Inf, lo_open = TRUE, hi_open = TRUE),
  log2 = list(lo = 0, hi = Inf, lo_open = TRUE, hi_open = TRUE),
  log10 = list(lo = 0, hi = Inf, lo_open = TRUE, hi_open = TRUE),
  log1p = list(lo = -1, hi = Inf, lo_open = TRUE, hi_open = TRUE),
  sqrt = list(lo = 0, hi = Inf, lo_open = FALSE, hi_open = TRUE),
  asin = list(lo = -1, hi = 1, lo_open = FALSE, hi_open = FALSE),
  acos = list(lo = -1, hi = 1, lo_open = FALSE, hi_open = FALSE)
)

## The range of each function, used to trim an enclosure that the slack pushed
## outside it. A function never takes a value outside its range, so the
## intersection is always valid; without it the widening of sqrt(0) produces a
## negative lower bound for a function that is never negative, which is a sound
## enclosure and a misleading one.
##
## The irrational limits are stored already rounded outward, because clamping to
## the double nearest an irrational bound would cut the true value off. The
## double nearest pi/2 is below pi/2, so asin(1) clamped to it would exclude the
## very value it is the arc sine of.
## It is a function and not a stored vector because the outward-rounded limits
## call ra_succ(), which lives in a file the loader reaches later; a stored
## vector would be evaluated at load time and fail. Sources are read in
## alphabetical order and top-level code must not assume otherwise.
.ra_range <- function(fun) {
  h <- ra_succ(pi / 2)
  switch(fun,
         exp = c(0, Inf), expm1 = c(-1, Inf), sqrt = c(0, Inf),
         cosh = c(1, Inf), tanh = c(-1, 1), sin = c(-1, 1), cos = c(-1, 1),
         asin = c(-h, h), atan = c(-h, h), acos = c(0, ra_succ(pi)),
         c(-Inf, Inf))
}

## Where the critical points of the periodic functions sit, as the pair (q, m)
## meaning the points q*pi + k*(m*pi) for integer k. The pole of the tangent is
## carried in the same form, because finding it is the same computation.
.ra_critical <- list(
  sin = list(max = c(q = 1 / 2, m = 2), min = c(q = 3 / 2, m = 2)),
  cos = list(max = c(q = 0, m = 2), min = c(q = 1, m = 2)),
  tan = list(pole = c(q = 1 / 2, m = 1))
)

.ra_check_fun <- function(fun) {
  if (!is.character(fun) || length(fun) != 1L || is.na(fun)) {
    ra_stop("bad_argument", "`fun` must be a single character string.")
  }
  if (!fun %in% names(.ra_shape)) {
    ra_slack(fun)  ## raises ra_symbol_not_in_table with the stated reason
  }
  invisible(fun)
}

## A point of the domain, used to stand in for the empty and invalid entries of
## a vector while the arithmetic runs; their results are overwritten afterwards.
.ra_safe_point <- function(fun) {
  d <- .ra_domains[[fun]]
  if (is.finite(d$lo) && is.finite(d$hi)) return((d$lo + d$hi) / 2)
  if (is.finite(d$lo)) return(d$lo + 1)
  0
}

## Spend a budget stated in exact binary64 neighbours with the arithmetic
## predecessor and successor. The formulas are exact outside the two binades
## around the subnormal threshold and may move two neighbours inside them. A
## call in that band therefore spends two units of the budget; if only one is
## left, stopping is both valid and no wider than the declared budget.
.ra_widen_bounded <- function(v, steps, move) {
  out <- as.numeric(v)
  left <- rep_len(as.integer(steps), length(out))
  while (any(left > 0L)) {
    band <- is.finite(out) & abs(out) >= 2^-1022 & abs(out) <= 2^-1020
    cost <- ifelse(band, 2L, 1L)
    take <- left >= cost & left > 0L
    if (!any(take)) break
    out[take] <- move(out[take])
    left[take] <- left[take] - cost[take]
  }
  out
}

.ra_widen_down <- function(v, steps) {
  .ra_widen_bounded(v, steps, ra_pred)
}

.ra_widen_up <- function(v, steps) {
  .ra_widen_bounded(v, steps, ra_succ)
}

## Enclose f at a vector of points. The fast path is the included correctly
## rounded binary64 evaluator widened by the declared slack; the rigorous path
## is a multiprecision evaluation crossed back through the measured bridge.
## Non-finite arguments never reach the multiprecision backend: the included
## evaluator supplies their limits and exceptional values before finite entries
## are replaced by rigorous enclosures.
.ra_eval_pts <- function(fun, v, level, precision) {
  if (identical(level, "fast") || !all(is.finite(v))) {
    y <- .ra_cr(fun, v)
    s <- ra_slack(fun)
    out <- list(lo = .ra_widen_down(y, s), hi = .ra_widen_up(y, s))
    if (identical(level, "fast")) return(out)
    fin <- is.finite(v)
    if (!any(fin)) return(out)
    inner <- .ra_eval_pts(fun, v[fin], "rigorous", precision)
    out$lo[fin] <- inner$lo
    out$hi[fin] <- inner$hi
    return(out)
  }
  m <- Rmpfr::mpfr(v, precision)
  ra_enclose_mpfr(do.call(fun, list(m)))
}

## Does the interval of reduction indices contain an integer? The interval is a
## superset of the true one, so a true critical point is never missed; a spurious
## one only widens. This is the direction the guarantee needs.
.ra_crit_hits <- function(a, b, q, m, level, precision) {
  n <- length(a)
  finite <- is.finite(a) & is.finite(b)
  hit <- rep(TRUE, n)  ## an unbounded box reaches every critical point
  if (!any(finite)) return(hit)
  af <- a[finite]
  bf <- b[finite]

  if (identical(level, "fast")) {
    p <- ra_interval(ra_pred(pi), ra_succ(pi))
    k <- ra_sub(ra_div(ra_interval(af, bf), ra_mul(p, m)), q / m)
    hit[finite] <- floor(ra_sup(k)) >= ceiling(ra_inf(k))
    return(hit)
  }

  g <- precision + 64L
  p <- Rmpfr::Const("pi", g)
  off <- p * q
  den <- p * m
  klo <- (Rmpfr::mpfr(af, g) - off) / den
  khi <- (Rmpfr::mpfr(bf, g) - off) / den
  ## A relative widening far above the few nearest-mode roundings just spent,
  ## so that the index interval remains a superset without needing a directed
  ## mode the backend does not offer for arithmetic.
  eps <- Rmpfr::mpfr(2, g)^(-(precision + 32L))
  klo <- klo - abs(klo) * eps - eps
  khi <- khi + abs(khi) * eps + eps
  hit[finite] <- as.logical(floor(khi) >= ceiling(klo))
  hit
}

## The local decoration of an elementary operation. It is not the rule the
## arithmetic uses: com asserts that the argument box is bounded, and atan of an
## unbounded box has a bounded result, so a rule reading only the output would
## claim com where the standard forbids it.
.ra_local_elem <- function(a, b, out_lo, out_hi, in_domain, empty) {
  d <- rep("com", length(a))
  unbounded <- is.infinite(a) | is.infinite(b) |
    is.infinite(out_lo) | is.infinite(out_hi)
  d[unbounded] <- "dac"
  d[!in_domain] <- "trv"
  d[empty] <- "trv"
  d
}

#' @title Interval extension of an elementary function
#' @description Encloses the set of values an admitted function takes over an
#'   interval, at either of the two levels the package provides.
#' @param fun A character scalar naming a function of the closed table returned
#'   by [ra_operator_table()].
#' @param x An object of class \code{ra_ivl}, or a numeric vector, which is
#'   promoted to intervals of zero width.
#' @param level A character scalar, \code{"fast"} for the included correctly
#'   rounded binary64 implementation widened by the declared slack, or
#'   \code{"rigorous"} for a multiprecision evaluation. Defaults to
#'   \code{"fast"}.
#' @param precision An integer scalar, the working precision in bits of the
#'   rigorous level. Ignored at the fast level. Defaults to the first rung of
#'   [ra_precision_ladder()].
#' @return An object of class \code{ra_ivl} of the length of \code{x}.
#' @details The value returned encloses \code{{f(t) : t in x, t in dom(f)}}. The
#'   enclosure may be wider than that set and is never narrower, so a point
#'   proved to lie outside it is proved to be outside the range.
#'
#'   The endpoints are chosen by the shape of the function on its domain rather
#'   than by evaluating both ends and sorting. A monotone function is read at its
#'   ends; the hyperbolic cosine has its minimum in the interior of any box
#'   containing zero, and the value there is exactly one; the sine and cosine
#'   have interior extrema whose positions are found by reduction, and the value
#'   at an attained extremum is exactly one in absolute value. Those exact values
#'   receive no slack, because they are the mathematics of the function and not
#'   an evaluation of a library.
#'
#'   The result is finally intersected with the range of the function. This
#'   matters at the ends of a range that the slack can step past: the square root
#'   of zero is zero, and widening it downward would report that the square root
#'   of a nonnegative box might be negative.
#'
#'   An argument box that leaves the domain is intersected with it. The part
#'   outside is dropped, the range of the part inside is returned, and the
#'   decoration falls to \code{trv}, which is the standard saying that the claim
#'   of being defined everywhere on the box has failed. A box entirely outside
#'   the domain gives the empty interval. Neither case raises and neither
#'   produces a missing value.
#' @section Methodological notes:
#'   The fast implementation consists of fifteen CORE-MATH software kernels and
#'   the binary64 hardware square root. Its declared error bound is one half of
#'   a unit in the last place, so the pre-registered formula
#'   \code{ceiling(2 * e + 1)} applies two outward steps to every function. The
#'   result retains measured provenance because the correctly rounded claim of
#'   the included software was verified numerically and is not established here
#'   as a theorem for every kernel.
#'
#'   The reduction that locates the interior extrema is performed in interval
#'   arithmetic against an enclosure of pi, and the resulting interval of indices
#'   is asked whether it contains an integer. That interval is a superset of the
#'   true one, so the test can report an extremum that is not there but can never
#'   miss one that is; the first widens the answer and the second would break the
#'   guarantee. When the box is wide enough that the index interval contains an
#'   integer regardless, the answer is the full range, which is valid and, above
#'   a magnitude that [ra_periodic_frontier()] measures, also tight: adjacent
#'   doubles of that size are more than a period apart.
#'
#'   The tangent is read as monotone only when the index interval of its poles
#'   contains no integer. When it may contain one, the range is genuinely
#'   unbounded and the answer is the whole line with \code{trv}. A point argument
#'   is never a pole, because every pole is irrational and every double is not,
#'   so the reduction is skipped there and the library value is used.
#' @section Dependencies:
#'   The fast level uses the package's registered native routines and has no
#'   external package dependency. The rigorous level requires 'Rmpfr', which is
#'   in \code{Suggests}, and raises \code{ra_no_mpfr} when it is absent, since
#'   the caller asked for it by name.
#' @references
#'   Moore, R. E., Kearfott, R. B., & Cloud, M. J. (2009). Introduction to interval
#'   analysis. Society for Industrial and Applied Mathematics.
#'   https://doi.org/10.1137/1.9780898717716
#'
#'   Institute of Electrical and Electronics Engineers. (2018). IEEE standard for
#'   interval arithmetic (simplified) (IEEE Std 1788.1-2017).
#'   https://doi.org/10.1109/IEEESTD.2018.8277144
#'
#'   Sibidanov, A., Zimmermann, P., & Glondu, S. (2022). The CORE-MATH project.
#'   In 2022 IEEE 29th Symposium on Computer Arithmetic (ARITH) (pp. 26-34).
#'   IEEE. https://doi.org/10.1109/ARITH54963.2022.00014
#' @examples
#' ra_elem("exp", ra_interval(0, 1))
#' ra_elem("sin", ra_interval(0, pi))
#' ra_elem("log", ra_interval(-1, 2))
#' ra_elem("tan", ra_interval(1, 2))
#' @seealso [ra_operator_table()] for what is admitted, [ra_slack()] for the
#'   widening of the fast level, and [ra_elem_escalate()] for the ladder.
#' @export
ra_elem <- function(fun, x, level = c("fast", "rigorous"),
                    precision = ra_precision_ladder()[1L]) {
  .ra_check_fun(fun)
  level <- match.arg(level)
  ## the gate of the safeguards: a degraded fast level escalates with a word
  ## or refuses with a word, and the first fast use of a session audits the
  ## route when the backend is there to audit against
  if (identical(level, "fast")) level <- .ra_fast_gate(fun)
  x <- .ra_as_ivl(x)
  n <- length(x)
  if (n == 0L) return(x)
  if (identical(level, "rigorous") && !ra_has_mpfr()) {
    ra_stop("no_mpfr",
            paste0("The rigorous level of `", fun, "` needs package 'Rmpfr', ",
                   "which is not installed. Call with level = \"fast\" for an ",
                   "enclosure that is valid but wider."))
  }
  precision <- as.integer(precision)[1L]

  dom <- .ra_domains[[fun]]
  nai <- ra_is_nai(x)
  was_empty <- ra_is_empty(x)

  a <- pmax(x$lo, dom$lo)
  b <- pmin(x$hi, dom$hi)
  ## Empty after restriction: the parts do not overlap, or they meet exactly at
  ## an endpoint the domain does not contain.
  empty <- was_empty | nai | a > b |
    (a == b & ((a == dom$lo & dom$lo_open) | (b == dom$hi & dom$hi_open)))
  empty[is.na(empty)] <- TRUE

  in_domain <-
    (is.infinite(dom$lo) | x$lo > dom$lo | (x$lo == dom$lo & !dom$lo_open)) &
    (is.infinite(dom$hi) | x$hi < dom$hi | (x$hi == dom$hi & !dom$hi_open))
  in_domain[is.na(in_domain)] <- FALSE

  safe <- .ra_safe_point(fun)
  a[empty] <- safe
  b[empty] <- safe

  ea <- .ra_eval_pts(fun, a, level, precision)
  eb <- .ra_eval_pts(fun, b, level, precision)
  lo <- pmin(ea$lo, eb$lo)
  hi <- pmax(ea$hi, eb$hi)

  shape <- .ra_shape[[fun]]
  if (identical(shape, "increasing")) {
    lo <- ea$lo
    hi <- eb$hi
  } else if (identical(shape, "decreasing")) {
    lo <- eb$lo
    hi <- ea$hi
  } else if (identical(shape, "valley")) {
    ## The only valley in the table is the hyperbolic cosine, whose minimum is
    ## at zero and is exactly one.
    lo[a <= 0 & b >= 0] <- 1
  } else if (identical(shape, "periodic")) {
    wide <- !empty & a < b
    cr <- .ra_critical[[fun]]
    hits_max <- wide & .ra_crit_hits(a, b, cr$max[["q"]], cr$max[["m"]],
                                     level, precision)
    hits_min <- wide & .ra_crit_hits(a, b, cr$min[["q"]], cr$min[["m"]],
                                     level, precision)
    hi[hits_max] <- 1
    lo[hits_min] <- -1
  } else if (identical(shape, "poles")) {
    wide <- !empty & a < b
    cr <- .ra_critical[[fun]]$pole
    hits <- wide & .ra_crit_hits(a, b, cr[["q"]], cr[["m"]], level, precision)
    lo[hits] <- -Inf
    hi[hits] <- Inf
    in_domain[hits] <- FALSE
  }

  rng <- .ra_range(fun)
  lo <- pmax(lo, rng[1L])
  hi <- pmin(hi, rng[2L])

  local <- .ra_local_elem(a, b, lo, hi, in_domain, empty)
  ## the provenance of the level: the fast level is a measured convention,
  ## the rigorous level preserves what it received (a theorem stays one)
  pv <- if (identical(level, "fast")) rep("measured", n) else ra_prov(x)
  .ra_assemble(lo, hi, .ra_prop(local, x$dec), empty, nai, pv)
}

#' @title Verify the declared shapes against the functions themselves
#' @description Runs each admitted function over a mesh of its own domain and
#'   reports whether the shape the package declares for it is the shape it has.
#' @param classes An optional named character vector overriding the declared
#'   shape of the named functions, used to check that a wrong declaration is
#'   detected. Defaults to \code{NULL}, meaning the declared table.
#' @param n An integer scalar, the number of mesh points per function. Defaults
#'   to 4001.
#' @param span A numeric scalar, the half-width of the mesh for functions whose
#'   domain is unbounded. Defaults to 8, which spans more than two periods.
#' @return A list with three elements: \code{observed}, a character vector of the
#'   shape each function was found to have; \code{disagreeing}, the names of the
#'   functions whose declared shape differs from it; and \code{agrees}, a logical
#'   scalar that is \code{TRUE} when \code{disagreeing} is empty.
#' @details The shape is read from the signs of the successive differences of the
#'   function on the mesh, with the exact ties dropped so that a saturating
#'   function such as the hyperbolic tangent is not mistaken for a
#'   non-monotone one. No sign change is a monotone function; one change from
#'   falling to rising is a valley; more than one change is either a periodic
#'   function or one with poles, and the two are told apart by the length of the
#'   shortest run, since a pole reverses the sign of the difference for a single
#'   step and a genuine half-period lasts for hundreds.
#' @section Methodological notes:
#'   The shape table is the one part of the elementary layer that could be wrong
#'   without any arithmetic being wrong, and the failure it would cause is a
#'   silent loss of containment rather than an error. Reading only the endpoints
#'   of the hyperbolic cosine over a box containing zero returns an interval that
#'   misses the true minimum by however much the box reaches to the left, and
#'   nothing in the result says so. This function exists so that the table is
#'   measured on the machine that will use it, and its own positive control is
#'   that a deliberately wrong entry passed through \code{classes} must appear in
#'   \code{disagreeing}.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Neumaier, A. (1990). Interval methods for systems of equations. Cambridge
#'   University Press. https://doi.org/10.1017/CBO9780511526473
#' @examples
#' ra_verify_monotonicity()$agrees
#' ra_verify_monotonicity(classes = c(cosh = "increasing"))$disagreeing
#' @seealso [ra_elem()], which uses the table this verifies.
#' @export
ra_verify_monotonicity <- function(classes = NULL, n = 4001L, span = 8) {
  declared <- .ra_shape
  if (!is.null(classes)) {
    if (is.null(names(classes)) || any(!nzchar(names(classes)))) {
      ra_stop("bad_argument", "`classes` must be a named character vector.")
    }
    declared[names(classes)] <- unname(classes)
  }
  observed <- vapply(names(.ra_shape), function(f) {
    d <- .ra_domains[[f]]
    lo <- if (is.finite(d$lo)) d$lo + 1e-6 else -span
    hi <- if (is.finite(d$hi)) d$hi - 1e-6 else span
    y <- do.call(f, list(seq(lo, hi, length.out = n)))
    dy <- diff(y)
    dy <- dy[is.finite(dy) & dy != 0]
    if (!length(dy)) return("constant")
    r <- rle(sign(dy))
    neg <- r$lengths[r$values < 0]
    pos <- r$lengths[r$values > 0]
    if (!length(neg)) return("increasing")
    if (!length(pos)) return("decreasing")
    if (length(neg) == 1L && length(pos) == 1L && r$values[1L] < 0) {
      return("valley")
    }
    if (min(c(neg, pos)) <= 2L) "poles" else "periodic"
  }, character(1))
  bad <- names(observed)[observed != declared[names(observed)]]
  list(observed = observed, disagreeing = bad, agrees = length(bad) == 0L)
}

#' @title Measure the error of the evaluation path the fast level actually uses
#' @description Evaluates each admitted function over a mesh of its domain, both
#'   through the included fast implementation and through the multiprecision
#'   backend, and reports the largest disagreement in units in the last place
#'   beside the bound declared for the included implementation.
#' @param n An integer scalar, how many arguments to try per function. Defaults
#'   to 20000.
#' @param seed An integer scalar seeding the arguments, or \code{NULL}, the
#'   default, in which case the state of the random number generator is left
#'   exactly as the caller had it and no seed is set inside the function.
#' @param bits An integer scalar, the working precision of the referent.
#'   Defaults to 300.
#' @return A data frame with one row per admitted function and the columns
#'   \code{fun}, \code{n}, \code{observed}, \code{published}, \code{slack} and
#'   \code{used}, the last being the observed error as a fraction of the slack.
#' @details The slack of the fast level is \code{ceiling(2 * e + 1)} units in the
#'   last place over the declared bound \code{e = 0.5}. The fifteen included
#'   CORE-MATH kernels are correctly rounded under their contract, and the
#'   binary64 hardware square root is correctly rounded under IEEE 754. This
#'   function measures the installed package's path against an independent
#'   multiprecision referent.
#'
#'   The error is computed in multiprecision and not in binary64. Computed in
#'   binary64 it quantises to whole units in the last place, which cannot resolve
#'   whether an observed disagreement lies below the half-unit bound.
#' @section Methodological notes:
#'   The figure returned is a lower bound found by sampling. It is reported and
#'   never used to set the slack: a slack fitted to an observed error would be a
#'   calibration wearing the clothes of a convention, and the pre-registration
#'   of this phase forbids widening a declared number to accommodate a
#'   measurement. The measurement instead checks that the installed route stays
#'   within its declared half-unit bound and reports how much of the two-step
#'   slack is being spent.
#' @section Dependencies:
#'   Requires 'Rmpfr', which is in \code{Suggests}, and raises \code{ra_no_mpfr}
#'   without it, since there is no referent to measure against.
#' @references
#'   Sibidanov, A., Zimmermann, P., & Glondu, S. (2022). The CORE-MATH project.
#'   In 2022 IEEE 29th Symposium on Computer Arithmetic (ARITH) (pp. 26-34).
#'   IEEE. https://doi.org/10.1109/ARITH54963.2022.00014
#' @examples
#' if (ra_has_mpfr()) {
#'   head(ra_measure_library_error(n = 500L, seed = 80L), 4)
#' }
#' @seealso [ra_slack()] and [ra_elem()].
#' @export
ra_measure_library_error <- function(n = 20000L, seed = NULL, bits = 300L) {
  if (!ra_has_mpfr()) {
    ra_stop("no_mpfr",
            paste0("Measuring the library error needs package 'Rmpfr', which ",
                   "is not installed: there is nothing to measure against."))
  }
  if (!is.null(seed)) {
    set.seed(seed)
  }
  funs <- names(.ra_shape)
  out <- data.frame(fun = funs, n = 0L, observed = NA_real_,
                    published = .ra_ulp_fast[funs],
                    slack = vapply(funs, ra_slack, integer(1)),
                    used = NA_real_, row.names = NULL,
                    stringsAsFactors = FALSE)
  for (i in seq_along(funs)) {
    f <- funs[i]
    d <- .ra_domains[[f]]
    x <- if (is.finite(d$lo) && is.finite(d$hi)) {
      stats::runif(n, d$lo, d$hi)
    } else if (is.finite(d$lo)) {
      d$lo + 2^stats::runif(n, -60, 60)
    } else {
      2^stats::runif(n, -60, 60) * sample(c(-1, 1), n, replace = TRUE)
    }
    x <- x[x > d$lo | (x == d$lo & !d$lo_open)]
    x <- x[x < d$hi | (x == d$hi & !d$hi_open)]
    y <- .ra_cr(f, x)
    z <- do.call(f, list(Rmpfr::mpfr(x, bits)))
    u <- ra_succ(abs(y)) - abs(y)
    ok <- is.finite(y) & u > 0 & is.finite(u)
    out$n[i] <- length(x)
    if (any(ok)) {
      e <- Rmpfr::asNumeric(abs(Rmpfr::mpfr(y[ok], bits) - z[ok]) /
                              Rmpfr::mpfr(u[ok], bits))
      out$observed[i] <- max(e)
      out$used[i] <- out$observed[i] / out$slack[i]
    }
  }
  out
}

#' @title Where the periodic enclosures stop resolving, and why
#' @description Measures the magnitude above which an interval of a given
#'   relative width can no longer be enclosed by the sine more narrowly than the
#'   whole range, at each of the two levels, and reports it beside the magnitude
#'   at which the spacing of binary64 makes that answer the correct one.
#' @param rel_width A numeric scalar, the width of the probe interval as a
#'   fraction of its magnitude. Defaults to \code{2^-20}.
#' @param n An integer scalar, how many probe points to draw per exponent.
#'   Defaults to 16.
#' @param max_exponent An integer scalar, where to stop looking. Defaults to 80.
#' @param seed An integer scalar seeding the probe points, or \code{NULL}, the
#'   default, in which case the state of the random number generator is left
#'   exactly as the caller had it and no seed is set inside the function. The
#'   two levels probe the same points either way, because the points are drawn
#'   once and shared, not redrawn per level.
#' @return A list with the probe width, the measured exponent at each level, the
#'   exponent predicted by the spacing of the format, and a witness magnitude
#'   below the fast frontier where the enclosure is strictly narrower than the
#'   whole range. The rigorous entries are \code{NA} when the backend is absent.
#' @details The enclosure of the sine over a box degenerates to the whole range
#'   when the interval of reduction indices contains an integer, which happens
#'   once the box is about a period wide. For a box of relative width \code{r}
#'   and magnitude \code{a}, that is \code{a * r >= 2 * pi}, so the frontier is
#'   predicted at the exponent \code{ceiling(log2(2 * pi / r))}, and the measured
#'   value is reported against that prediction rather than on its own.
#' @section Methodological notes:
#'   The number this reports corrects an expectation that is easy to hold and
#'   wrong: that the frontier is set by the precision of the argument reduction,
#'   and that the rigorous level would therefore push it far out. It is not. The
#'   rounding of the reduction contributes about one unit in the last place of
#'   the index, while the box contributes its own width divided by the period,
#'   and no nondegenerate box is narrower than one unit in the last place of its
#'   magnitude. The reduction can therefore widen the index interval by a small
#'   factor and never by an order. Above magnitude \code{2^52 * 2 * pi},
#'   consecutive doubles are more than a period apart and the whole range is not
#'   a loss but the exact answer, at either level.
#' @section Dependencies:
#'   Base R; probes 'Rmpfr' for the rigorous frontier and reports \code{NA} for
#'   it when the backend is absent.
#' @references
#'   Muller, J.-M., Brunie, N., de Dinechin, F., Jeannerod, C.-P., Joldes, M.,
#'   Lefevre, V., Melquiond, G., Revol, N., & Torres, S. (2018). Handbook of
#'   floating-point arithmetic (2nd ed.). Birkhauser.
#'   https://doi.org/10.1007/978-3-319-76526-6
#' @examples
#' fr <- ra_periodic_frontier()
#' c(measured = fr$fast_exponent, predicted = fr$granularity_exponent)
#' @seealso [ra_elem()].
#' @export
ra_periodic_frontier <- function(rel_width = 2^-20, n = 16L,
                                 max_exponent = 80L, seed = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }
  predicted <- ceiling(log2(2 * pi / rel_width))
  ## drawn once and shared by both levels, so that the comparison between the
  ## fast and the rigorous frontier is over the same probe points
  draws <- matrix(stats::runif(n * (max_exponent + 1L)), nrow = n)
  scan_one <- function(level) {
    witness <- NA_real_
    frontier <- NA_integer_
    for (e in seq.int(0L, max_exponent)) {
      a <- 2^e * (1 + draws[, e + 1L])
      x <- ra_interval(a, ra_succ(a + a * rel_width))
      w <- ra_wid(ra_elem("sin", x, level = level))
      if (any(w < 2) && is.na(frontier)) witness <- max(a[w < 2])
      if (all(w >= 2)) {
        frontier <- e
        break
      }
    }
    list(frontier = frontier, witness = witness)
  }
  fast <- scan_one("fast")
  rig <- if (ra_has_mpfr()) scan_one("rigorous") else {
    list(frontier = NA_integer_, witness = NA_real_)
  }
  list(rel_width = rel_width,
       fast_exponent = fast$frontier,
       rigorous_exponent = rig$frontier,
       granularity_exponent = predicted,
       fast_witness = fast$witness,
       rigorous_witness = rig$witness)
}

#' @title Climb the precision ladder until a question is settled
#' @description Evaluates an elementary function at the fast level and, if the
#'   enclosure does not settle the question the caller asked, again at each rung
#'   of the precision ladder, stopping at the first rung that does or reporting
#'   the budget it exhausted.
#' @param fun A character scalar naming a function of the closed table.
#' @param x An object of class \code{ra_ivl} of length one, or a numeric scalar.
#' @param decide A function of one argument, the enclosure, returning a logical
#'   scalar that is \code{TRUE} when the enclosure settles the question.
#' @param ladder An integer vector of precisions in bits, in increasing order.
#'   Defaults to [ra_precision_ladder()].
#' @return An object of class \code{ra_escalation}.
#' @details The abstention is the point of this function. A question that the
#'   available budget cannot settle produces an object saying so, with the number
#'   of bits printed in the sentence; it does not return a verdict chosen to
#'   break the tie, and it does not fall silent. When the backend is absent the
#'   fast level answers alone and the object carries the sentence of
#'   [ra_message_no_mpfr()], because a missing optional package is not a failure
#'   of the caller.
#' @section Methodological notes:
#'   The deciding criterion belongs to the caller and is never loosened here. The
#'   ladder is the mechanism for resolving rather than relaxing: a verdict lying
#'   closer to a boundary than the declared slack of the fast level is not
#'   declared by widening the tolerance until it fits, it is recomputed with more
#'   bits until the enclosure separates from the boundary or the budget runs out.
#'   Which of the two happened is recorded in the object rather than inferred
#'   from the answer.
#' @section Dependencies:
#'   Base R; uses 'Rmpfr' from \code{Suggests} for every rung above the fast
#'   level, and degrades to the fast level alone without it.
#' @references
#'   Revol, N., & Rouillier, F. (2005). Motivations for an arbitrary precision interval
#'   arithmetic and the MPFI library. Reliable Computing, 11(4), 275-290.
#'   https://doi.org/10.1007/s11155-005-6891-y
#'
#'   Rump, S. M. (2010). Verification methods: Rigorous results using floating-point
#'   arithmetic. Acta Numerica, 19, 287-449.
#'   https://doi.org/10.1017/S096249291000005X
#' @examples
#' if (ra_has_mpfr()) {
#'   ra_elem_escalate("sin", ra_interval(1, 1),
#'                    function(iv) ra_wid(iv) < 2^-52)
#' }
#' @seealso [ra_elem()] and [ra_precision_ladder()].
#' @export
ra_elem_escalate <- function(fun, x, decide, ladder = ra_precision_ladder()) {
  .ra_check_fun(fun)
  if (!is.function(decide)) {
    ra_stop("bad_argument", "`decide` must be a function of one argument.")
  }
  x <- .ra_as_ivl(x)
  if (length(x) != 1L) {
    ra_stop("bad_argument",
            paste0("`x` must be a single interval; escalation answers one ",
                   "question at a time, and a vector would hide which element ",
                   "exhausted the budget."))
  }
  ladder <- as.integer(ladder)

  iv <- ra_elem(fun, x, level = "fast")
  if (isTRUE(decide(iv))) {
    return(.ra_escalation(fun, x, iv, NA_integer_, TRUE,
                          "settled at the fast level"))
  }
  if (!ra_has_mpfr()) {
    return(.ra_escalation(fun, x, iv, NA_integer_, FALSE,
                          ra_message_no_mpfr(paste0("the escalation of ", fun,
                                                    "()"))))
  }
  for (p in ladder) {
    iv <- ra_elem(fun, x, level = "rigorous", precision = p)
    if (isTRUE(decide(iv))) {
      return(.ra_escalation(fun, x, iv, p, TRUE,
                            paste0("settled at ", p, " bits")))
    }
  }
  top <- ladder[length(ladder)]
  .ra_escalation(fun, x, iv, top, FALSE,
                 paste0("no verdict at this budget (", top, " bits)"))
}

.ra_escalation <- function(fun, argument, interval, bits, decided, word) {
  structure(list(fun = fun, argument = argument, interval = interval,
                 bits = bits, decided = decided, word = word),
            class = "ra_escalation")
}

#' @title Show the result of an escalation
#' @description Render an escalation for the console and for a data frame, with
#'   the word of its verdict and the budget it reached.
#' @param x An object of class \code{ra_escalation}.
#' @param object An object of class \code{ra_escalation}, for \code{summary}.
#' @param row.names,optional Arguments of the \code{as.data.frame} generic. The
#'   first is used; the second is ignored.
#' @param ... Further arguments, ignored, present for consistency with the
#'   generics.
#' @return \code{format} returns a character scalar; \code{print} returns its
#'   argument invisibly; \code{as.data.frame} returns a one-row data frame with
#'   the function, the enclosure, its decoration, the budget, whether the
#'   question was settled and the word; \code{summary} returns an object of class
#'   \code{ra_escalation_summary}, which prints the same fields with the
#'   argument box added.
#' @details The word is printed always, including when the question was settled,
#'   so that a reader never has to infer from the presence of a number whether
#'   the number was reached or exhausted.
#' @section Methodological notes:
#'   These are written with the class rather than after it. A class whose
#'   printing and coercion arrive later spends the interval producing output that
#'   looks like a list of three fields, which is how an abstention gets read as a
#'   result.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Wickham, H. (2019). Advanced R (2nd ed.). Chapman & Hall/CRC.
#'   https://doi.org/10.1201/9781351201315
#' @examples
#' if (ra_has_mpfr()) {
#'   e <- ra_elem_escalate("sin", ra_interval(1, 1),
#'                         function(iv) ra_wid(iv) < 2^-52)
#'   print(e)
#'   as.data.frame(e)
#'   summary(e)
#' }
#' @seealso [ra_elem_escalate()].
#' @name ra_escalation_show
NULL

#' @rdname ra_escalation_show
#' @export
format.ra_escalation <- function(x, ...) {
  paste0(x$fun, "(", format(x$argument), ") = ", format(x$interval),
         "  [", x$word, "]")
}

#' @rdname ra_escalation_show
#' @export
print.ra_escalation <- function(x, ...) {
  cat("<ra_escalation>\n")
  cat(format(x), "\n", sep = "")
  invisible(x)
}

#' @rdname ra_escalation_show
#' @export
as.data.frame.ra_escalation <- function(x, row.names = NULL, optional = FALSE,
                                        ...) {
  data.frame(fun = x$fun, lo = ra_inf(x$interval), hi = ra_sup(x$interval),
             dec = ra_dec(x$interval), bits = x$bits, decided = x$decided,
             word = x$word, row.names = row.names, stringsAsFactors = FALSE)
}

#' @rdname ra_escalation_show
#' @export
summary.ra_escalation <- function(object, ...) {
  structure(list(fun = object$fun,
                 argument = format(object$argument),
                 interval = format(object$interval),
                 width = ra_wid(object$interval),
                 bits = object$bits,
                 decided = object$decided,
                 word = object$word),
            class = "ra_escalation_summary")
}

#' @rdname ra_escalation_show
#' @export
print.ra_escalation_summary <- function(x, ...) {
  cat("Function:  ", x$fun, "\n", sep = "")
  cat("Argument:  ", x$argument, "\n", sep = "")
  ## the width bounds how much is not known, so it is rounded up: printed short
  ## it would claim a narrower enclosure than the one that was computed
  cat("Enclosure: ", x$interval, "  width ", .ra_card_up(x$width), "\n", sep = "")
  cat("Budget:    ",
      if (is.na(x$bits)) "fast level" else paste0(x$bits, " bits"), "\n",
      sep = "")
  cat("Settled:   ", x$decided, "\n", sep = "")
  cat("Verdict:   ", x$word, "\n", sep = "")
  invisible(x)
}
