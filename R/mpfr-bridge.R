## The bridge to the rigorous level.
##
## The rigorous level evaluates in multiprecision and then comes back to
## binary64. Coming back is the dangerous half: the obvious conversion loses the
## direction of the rounding and, at the ends of the range, loses the number
## itself without saying so. What follows is the path that was measured on the
## installed backend, and the reason the obvious conversion is not it.

## The escalation ladder. Doubling is the pattern of the multiprecision interval
## libraries; the first rung is twice binary64 rounded up to a multiple of the
## limb, which is where a doubled evaluation stops being a reformulation of the
## same rounding error.
.ra_precision_ladder <- c(106L, 212L, 424L, 848L)

#' @title Is the rigorous level available
#' @description Reports whether the optional multiprecision backend is
#'   installed, without loading it and without raising if it is not.
#' @return A logical scalar.
#' @details The probe is called at the point of use rather than when the package
#'   loads, which is what allows the package to be installed, checked and used
#'   without the backend. Every function that would escalate calls this first
#'   and, when it returns \code{FALSE}, answers at the fast level and says so
#'   with the sentence of [ra_message_no_mpfr()].
#' @section Methodological notes:
#'   The fast level is not a degraded mode. Its enclosures are valid enclosures
#'   and its verdicts are true verdicts; what the rigorous level adds is the
#'   ability to narrow a case whose distance to the decision boundary is smaller
#'   than the declared slack. Absent the backend, such a case is reported as
#'   undecided at the available budget, which is a word, not a silence.
#' @section Dependencies:
#'   Probes 'Rmpfr', which is in \code{Suggests}.
#' @references
#'   Maechler, M. (2024). Rmpfr: R MPFR - multiple precision floating-point
#'   reliable (Version 1.1-2) [Software]. Comprehensive R Archive Network.
#'   https://doi.org/10.32614/CRAN.package.Rmpfr
#' @examples
#' ra_has_mpfr()
#' @seealso [ra_to_double()], the bridge that needs it, and
#'   [ra_precision_ladder()].
#' @export
ra_has_mpfr <- function() {
  requireNamespace("Rmpfr", quietly = TRUE)
}

#' @title The ladder of working precisions
#' @description Returns the sequence of precisions, in bits, that the rigorous
#'   level climbs when a verdict cannot be reached at the current one.
#' @return An integer vector, in increasing order.
#' @details The rungs double. A verdict that is still undecided at the top rung
#'   is reported as undecided at that budget, with the number of bits printed;
#'   the ladder is never extended silently and the deciding criterion is never
#'   loosened to manufacture a verdict.
#' @section Methodological notes:
#'   Doubling rather than incrementing is deliberate. The cost of a rung is
#'   superlinear in its precision, so a fine ladder spends most of its budget on
#'   rungs that were never going to decide anything; and a case that fails to
#'   resolve after doubling is usually a case that is genuinely on the boundary
#'   rather than one that needed a few more bits.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Revol, N., & Rouillier, F. (2005). Motivations for an arbitrary precision interval
#'   arithmetic and the MPFI library. Reliable Computing, 11(4), 275-290.
#'   https://doi.org/10.1007/s11155-005-6891-y
#' @examples
#' ra_precision_ladder()
#' @seealso [ra_to_double()].
#' @export
ra_precision_ladder <- function() {
  .ra_precision_ladder
}

#' @title Convert a multiprecision number to a double in a chosen direction
#' @description Turns a multiprecision value into a binary64 value that is
#'   guaranteed to lie on the requested side of it, so that a rigorous
#'   evaluation can be returned as an ordinary interval without losing its
#'   guarantee at the last step.
#' @param x An object of class \code{mpfr}.
#' @param direction A character scalar, either \code{"down"} or \code{"up"}.
#' @return A numeric vector of the same length as \code{x}.
#' @details The path is the one measured on the installed backend: round the
#'   multiprecision value to the precision of binary64 in the requested
#'   direction with \code{Rmpfr::roundMpfr()}, then cross to a double with
#'   \code{Rmpfr::toNum()} in the same direction. Two roundings are needed
#'   rather than one because the first fixes the significand and the second
#'   fixes the type, and only the second knows about the limits of the
#'   destination format.
#'
#'   The arithmetic operators of the backend were measured and do not accept a
#'   rounding mode; they evaluate to nearest. This costs nothing, because the
#'   multiprecision library rounds every one of its functions correctly by
#'   contract, so evaluating to nearest at a precision well above binary64 and
#'   then rounding once in the wanted direction gives an enclosure whose width
#'   is at most one unit in the last place, by theorem rather than by
#'   measurement.
#' @section Methodological notes:
#'   \code{as.numeric()} must not be used for this crossing, and the package
#'   contains a test whose purpose is to fail if anyone tries. It underflows to
#'   zero and overflows to infinity in silence: a positive multiprecision value
#'   below the smallest subnormal becomes zero, which is a valid lower bound and
#'   an invalid upper bound, and nothing in the returned value says which of the
#'   two it was asked to be. \code{toNum()} in a directed mode was measured to
#'   respect the subnormal range and to saturate at the largest finite double
#'   downward and at infinity upward, which is what an outward bound needs.
#' @section Dependencies:
#'   Requires 'Rmpfr', which is in \code{Suggests}. Raises
#'   \code{ra_no_mpfr} if it is absent, because unlike an escalation this
#'   function has no fast-level answer to fall back to: it was handed a
#'   multiprecision object, which could only have come from the backend.
#' @references
#'   Fousse, L., Hanrot, G., Lefevre, V., Pelissier, P., & Zimmermann, P. (2007).
#'   MPFR: A multiple-precision binary floating-point library with correct
#'   rounding. ACM Transactions on Mathematical Software, 33(2), Article 13.
#'   https://doi.org/10.1145/1236463.1236468
#' @examples
#' if (ra_has_mpfr()) {
#'   third <- Rmpfr::mpfr("1", 120L) / 3
#'   lo <- ra_to_double(third, "down")
#'   hi <- ra_to_double(third, "up")
#'   c(lo < 1 / 3 || lo == 1 / 3, hi > 1 / 3 || hi == 1 / 3)
#' }
#' @seealso [ra_has_mpfr()] and [ra_precision_ladder()].
#' @export
ra_to_double <- function(x, direction = c("down", "up")) {
  direction <- match.arg(direction)
  if (!ra_has_mpfr()) {
    ra_stop("no_mpfr",
            paste0("Converting a multiprecision value needs package 'Rmpfr', ",
                   "which is not installed."))
  }
  mode <- if (identical(direction, "down")) "D" else "U"
  narrowed <- Rmpfr::roundMpfr(x, 53L, rnd.mode = mode)
  Rmpfr::toNum(narrowed, rnd.mode = mode)
}

#' @title Enclose a multiprecision value in a pair of doubles
#' @description Returns the tightest pair of binary64 endpoints this package can
#'   place around a multiprecision value.
#' @param x An object of class \code{mpfr}.
#' @return A list with elements \code{lo} and \code{hi}, both numeric vectors of
#'   the length of \code{x}.
#' @details The two endpoints are [ra_to_double()] in each direction. When the
#'   multiprecision value happens to be exactly representable the two coincide,
#'   and the enclosure is a point; otherwise they are adjacent doubles and the
#'   enclosure has the least width any pair of doubles could have.
#' @section Methodological notes:
#'   This is the only place where a result of the rigorous level becomes an
#'   ordinary interval, so it is the only place where the guarantee of the
#'   rigorous level could be lost. Concentrating the crossing here is what makes
#'   the guarantee auditable.
#' @section Dependencies:
#'   Requires 'Rmpfr', which is in \code{Suggests}.
#' @references
#'   Revol, N., & Rouillier, F. (2005). Motivations for an arbitrary precision interval
#'   arithmetic and the MPFI library. Reliable Computing, 11(4), 275-290.
#'   https://doi.org/10.1007/s11155-005-6891-y
#' @examples
#' if (ra_has_mpfr()) {
#'   e <- ra_enclose_mpfr(exp(Rmpfr::mpfr("1", 200L)))
#'   e$hi - e$lo
#' }
#' @seealso [ra_to_double()].
#' @export
ra_enclose_mpfr <- function(x) {
  list(lo = ra_to_double(x, "down"), hi = ra_to_double(x, "up"))
}
