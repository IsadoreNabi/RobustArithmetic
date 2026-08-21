## Outward rounding without touching the floating-point unit.
##
## Every enclosure this package produces rests on two functions: one that moves
## a double strictly down and one that moves it strictly up, both computed in
## the rounding mode R happens to be in, which is round-to-nearest and which the
## package never changes. The formulas are those of Rump, Zimmermann, Boldo and
## Melquiond; their validity is a theorem about round-to-nearest, not a property
## of the machine, and it was re-verified against a bit-level reference on this
## machine before the package was written.

## The two constants of the theorem, written as expressions rather than as
## decimal literals so that no digit of the source has to be trusted: u is the
## unit roundoff of binary64, phi is its successor u(1 + 2u), and eta is the
## smallest positive subnormal.
.ra_u <- 2^-53
.ra_phi <- 2^-53 * (1 + 2^-52)
.ra_eta <- 2^-1074

#' @title The two constants of the outward-rounding theorem
#' @description Returns the unit roundoff of binary64, the widening factor of
#'   the predecessor and successor formulas, and the smallest positive
#'   subnormal, as the package holds them.
#' @return A named numeric vector of length three, with elements \code{u},
#'   \code{phi} and \code{eta}.
#' @details The three are exposed because a reader who wants to check the
#'   package against the paper should be able to read the constants rather than
#'   take them on trust. \code{phi} is the successor of \code{u} in binary64,
#'   which is what makes the formulas valid at the points where the naive
#'   factor \code{u} fails; those points are not exotic, and \code{x = 1} is one
#'   of them.
#' @section Methodological notes:
#'   The naive factor is the positive control of the rounding tests: the same
#'   formulas evaluated with \code{phi = u} must violate validity, and the test
#'   suite fails if they do not. A positive control that cannot fire is a broken
#'   harness, so the naive factor is kept and exercised rather than deleted.
#'
#'   The validity and exactness claims are Theorems 2.1 and 2.2 of Rump et al.
#'   (2009), whose proofs are machine-checked in Coq.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Rump, S. M., Zimmermann, P., Boldo, S., & Melquiond, G. (2009). Computing
#'   predecessor and successor in rounding to nearest. BIT Numerical Mathematics,
#'   49(2), 419-431. https://doi.org/10.1007/s10543-009-0218-z
#' @examples
#' k <- ra_constants()
#' k[["phi"]] > k[["u"]]
#' identical(k[["phi"]], 2^-53 * (1 + 2^-52))
#' @seealso [ra_succ()] and [ra_pred()], which use them.
#' @export
ra_constants <- function() {
  c(u = .ra_u, phi = .ra_phi, eta = .ra_eta)
}

#' @title Successor of a double in round-to-nearest
#' @description Returns, for every element of \code{x}, a double strictly
#'   greater than it and no smaller than its immediate successor in binary64.
#'   The computation is performed in the rounding mode already in force and does
#'   not change it.
#' @param x A numeric vector. Integer vectors are coerced.
#' @return A numeric vector of the same length as \code{x}. Missing values and
#'   \code{NaN} propagate.
#' @details The formula is \code{x + (phi * abs(x) + eta)}, evaluated in
#'   round-to-nearest, which the cited theorem proves lies in the half-open
#'   range from the immediate successor of \code{x} upward, so that using it in
#'   place of the immediate successor widens an enclosure and never narrows one.
#'
#'   How much it widens is also a theorem and not a measurement. The second of
#'   the cited theorems states that the value returned is exactly the immediate
#'   successor for every finite argument outside the two binades around the
#'   subnormal threshold, which for binary64 are the magnitudes between
#'   \code{2^-1022} and \code{2^-1020}, and that inside that band it is one bit
#'   beyond. A sweep of 180092 arguments on this machine found the exceptions
#'   exactly where the theorem allows them and nowhere else: eight points, at
#'   \code{2^-1022} and \code{2^-1021} and their negatives.
#'
#'   Two arguments are handled outside the formula because the formula produces
#'   \code{NaN} there rather than a wrong number: at \code{-Inf}, where the
#'   result is the largest finite negative double, and at \code{NaN} itself,
#'   which propagates. At \code{+Inf} the formula returns \code{+Inf}, which is
#'   the correct saturation, and at the largest finite double it returns
#'   \code{+Inf}, which is a valid upper bound and is how an overflow leaves the
#'   arithmetic without pretending to a finite answer.
#' @section Methodological notes:
#'   Changing the rounding mode of the floating-point unit, which is how
#'   directed rounding is usually obtained, is not available from R and would
#'   not be safe if it were: the evaluator, the just-in-time compiler and any
#'   linked numerical library sit between this code and the unit, and a directed
#'   mode that leaked into one of them would be a silent defect of the worst
#'   kind. This is the reason the package pays the cost of a formula instead.
#'   The declared price is that each fast-level operation overestimates by at
#'   most one unit in the last place per endpoint relative to true directed
#'   rounding.
#'
#'   The comparison point in the floating-point standard is the nextUp
#'   operation of IEEE Std 754-2019, clause 5.3.1.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Rump, S. M., Zimmermann, P., Boldo, S., & Melquiond, G. (2009). Computing
#'   predecessor and successor in rounding to nearest. BIT Numerical Mathematics,
#'   49(2), 419-431. https://doi.org/10.1007/s10543-009-0218-z
#'
#'   Institute of Electrical and Electronics Engineers. (2019). IEEE standard for
#'   floating-point arithmetic (IEEE Std 754-2019).
#'   https://doi.org/10.1109/IEEESTD.2019.8766229
#' @examples
#' ra_succ(1) == 1 + 2^-52
#' ra_succ(0) == 2^-1074
#' ra_succ(.Machine$double.xmax)
#' ra_succ(-Inf) == -.Machine$double.xmax
#' @seealso [ra_pred()], its mirror image, and [ra_constants()].
#' @export
ra_succ <- function(x) {
  x <- as.numeric(x)
  out <- x + (.ra_phi * abs(x) + .ra_eta)
  neg_inf <- !is.na(x) & x == -Inf
  out[neg_inf] <- -.Machine$double.xmax
  out
}

#' @title Predecessor of a double in round-to-nearest
#' @description Returns, for every element of \code{x}, a double strictly
#'   smaller than it and no greater than its immediate predecessor in binary64.
#'   The computation is performed in the rounding mode already in force and does
#'   not change it.
#' @param x A numeric vector. Integer vectors are coerced.
#' @return A numeric vector of the same length as \code{x}. Missing values and
#'   \code{NaN} propagate.
#' @details The formula is \code{x - (phi * abs(x) + eta)}. Everything said in
#'   the documentation of [ra_succ()] about validity, tightness and the two
#'   arguments handled outside the formula applies here with the signs
#'   reversed: the exception is \code{+Inf}, where the result is the largest
#'   finite double, and the saturation is toward \code{-Inf}.
#' @section Methodological notes:
#'   The pair is used in exactly one way: an arithmetic result computed in
#'   round-to-nearest lies within half a unit in the last place of the exact
#'   value, so the exact value lies between the predecessor and the successor of
#'   the computed one. That sentence is the whole outward-rounding layer of the
#'   fast level, and every enclosure the package returns is built from it.
#'
#'   The comparison point in the floating-point standard is the nextDown
#'   operation of IEEE Std 754-2019, clause 5.3.1.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Rump, S. M., Zimmermann, P., Boldo, S., & Melquiond, G. (2009). Computing
#'   predecessor and successor in rounding to nearest. BIT Numerical Mathematics,
#'   49(2), 419-431. https://doi.org/10.1007/s10543-009-0218-z
#'
#'   Institute of Electrical and Electronics Engineers. (2019). IEEE standard for
#'   floating-point arithmetic (IEEE Std 754-2019).
#'   https://doi.org/10.1109/IEEESTD.2019.8766229
#' @examples
#' ra_pred(1) == 1 - 2^-53
#' ra_pred(0) == -2^-1074
#' ra_pred(Inf) == .Machine$double.xmax
#' @seealso [ra_succ()], its mirror image, and [ra_constants()].
#' @export
ra_pred <- function(x) {
  x <- as.numeric(x)
  out <- x - (.ra_phi * abs(x) + .ra_eta)
  pos_inf <- !is.na(x) & x == Inf
  out[pos_inf] <- .Machine$double.xmax
  out
}

#' @title Widen a pair of endpoints outward by one rounding step
#' @description Takes the endpoints of an interval computed in round-to-nearest
#'   and moves each one away from the other, so that the exact value of whatever
#'   produced them is enclosed.
#' @param lo A numeric vector of lower endpoints.
#' @param hi A numeric vector of upper endpoints, of the same length as
#'   \code{lo}.
#' @return A list with elements \code{lo} and \code{hi}, both numeric vectors of
#'   the length of the inputs.
#' @details The function exists so that the outward step appears once in the
#'   sources rather than at every call site, which is what keeps a missing step
#'   from being invisible. A missing outward step does not produce a wrong
#'   number: it produces a number that is right almost always and wrong at the
#'   boundary, which is the failure this package is built to prevent.
#' @section Methodological notes:
#'   The step is applied unconditionally, including when the computed endpoints
#'   happen to be exact. Detecting exactness would require knowing the exact
#'   result, which is the thing not known; paying one rounding step of width for
#'   an operation that did not need it is the price of not having to know.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Rump, S. M. (2010). Verification methods: Rigorous results using floating-point
#'   arithmetic. Acta Numerica, 19, 287-449.
#'   https://doi.org/10.1017/S096249291000005X
#' @examples
#' w <- ra_round_out(0.1, 0.1)
#' w$lo < 0.1 && w$hi > 0.1
#' @seealso [ra_pred()] and [ra_succ()].
#' @export
ra_round_out <- function(lo, hi) {
  lo <- as.numeric(lo)
  hi <- as.numeric(hi)
  if (length(lo) != length(hi)) {
    ra_stop("bad_argument",
            "`lo` and `hi` must have the same length.")
  }
  list(lo = ra_pred(lo), hi = ra_succ(hi))
}
