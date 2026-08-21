## Typed conditions.
##
## Every failure this package can produce is a condition with a class of its
## own, so that a caller can tell the cases apart without parsing prose. The
## class vector is always c("ra_<kind>", "ra_error", "error", "condition"), and
## the message names the term it is about. Silence is never a failure mode: a
## computation that cannot reach a verdict returns an object that says so, and
## only a violated contract raises.

#' @title Raise a typed error of the package
#' @description Builds and signals a condition whose class vector identifies the
#'   kind of contract that was violated, so that callers can catch one kind
#'   without catching the others and without matching on the message text.
#' @param kind A character scalar naming the kind of failure. It becomes the
#'   first element of the class vector, prefixed with \code{"ra_"}.
#' @param message A character scalar with the message shown to the user.
#' @param call The call to report as the origin of the condition. Defaults to
#'   the caller of the function that raises.
#' @param ... Further named fields stored in the condition object, for callers
#'   that want the offending values rather than their rendering.
#' @return No return value. The function always signals a condition, so it never
#'   returns to its caller.
#' @details The three-layer class vector is what makes selective handling
#'   possible: \code{tryCatch(..., ra_empty_interval = )} catches exactly one
#'   case, \code{ra_error = } catches every failure of this package and nothing
#'   from any other, and \code{error = } catches it along with everything else.
#' @section Methodological notes:
#'   The package distinguishes a violated contract, which raises, from an
#'   undecided verdict, which does not. An interval operation that cannot prove
#'   what was asked returns an enclosure or a verdict object carrying the word
#'   for its abstention; it does not raise and it does not fall silent. Errors
#'   are reserved for inputs that could not have a meaning at all, such as an
#'   interval whose lower endpoint exceeds its upper one.
#'
#'   Chapter 8 of Wickham (2019) treats the condition system and the classing
#'   of conditions for selective handling.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Wickham, H. (2019). Advanced R (2nd ed.). Chapman & Hall/CRC.
#'   https://doi.org/10.1201/9781351201315
#' @examples
#' res <- tryCatch(
#'   ra_stop("empty_interval", "the interval is empty"),
#'   ra_empty_interval = function(cnd) class(cnd)[1L]
#' )
#' res
#' @seealso [ra_interval()], which raises \code{ra_bad_endpoints} when its
#'   invariant is violated.
#' @export
ra_stop <- function(kind, message, call = sys.call(-1L), ...) {
  if (!is.character(kind) || length(kind) != 1L || is.na(kind)) {
    stop("`kind` must be a single non-missing character string.", call. = FALSE)
  }
  if (!is.character(message) || length(message) != 1L || is.na(message)) {
    stop("`message` must be a single non-missing character string.",
         call. = FALSE)
  }
  cnd <- structure(
    c(list(message = message, call = call), list(...)),
    class = c(paste0("ra_", kind), "ra_error", "error", "condition")
  )
  stop(cnd)
}

#' @title Report what the rigorous level would give and why it is unavailable
#' @description Produces the sentence the package uses when a computation that
#'   would have been resolved at the rigorous level cannot be, because the
#'   optional backend is not installed. The sentence names the backend, names
#'   what is lost, and names what still works without it.
#' @param what A character scalar naming the operation that was being attempted.
#' @return A character scalar holding the message. It is returned rather than
#'   signalled, because a missing optional backend is not a violated contract:
#'   the fast level answers, and the caller is told what a rigorous level would
#'   have added.
#' @details The wording follows the clean-planting pattern: a missing suggested
#'   package produces a statement of consequence, never a silent degradation and
#'   never an error. The fast level remains fully available and its enclosures
#'   remain valid; what is lost is the escalation ladder that would narrow a
#'   verdict whose distance to the decision boundary is smaller than the
#'   declared slack of the fast level.
#' @section Methodological notes:
#'   'Rmpfr' sits in \code{Suggests} and is probed with
#'   \code{requireNamespace()} at the point of use, never at load time, so the
#'   package installs and runs without it.
#' @section Dependencies:
#'   Names 'Rmpfr', which is in \code{Suggests}.
#' @references
#'   Maechler, M. (2024). Rmpfr: R MPFR - multiple precision floating-point
#'   reliable (Version 1.1-2) [Software]. Comprehensive R Archive Network.
#'   https://doi.org/10.32614/CRAN.package.Rmpfr
#'
#'   Fousse, L., Hanrot, G., Lefevre, V., Pelissier, P., & Zimmermann, P. (2007).
#'   MPFR: A multiple-precision binary floating-point library with correct
#'   rounding. ACM Transactions on Mathematical Software, 33(2), Article 13.
#'   https://doi.org/10.1145/1236463.1236468
#' @examples
#' cat(ra_message_no_mpfr("the escalation of exp() to 212 bits"), "\n")
#' @seealso [ra_has_mpfr()], the probe this message accompanies.
#' @export
ra_message_no_mpfr <- function(what) {
  if (!is.character(what) || length(what) != 1L || is.na(what)) {
    ra_stop("bad_argument", "`what` must be a single character string.")
  }
  paste0(
    "The rigorous level is unavailable for ", what, ": package 'Rmpfr' is not ",
    "installed. The fast level answered instead, and its enclosure is valid; ",
    "what is lost is the precision ladder that would narrow a verdict lying ",
    "closer to the decision boundary than the declared slack of the fast ",
    "level. Install 'Rmpfr' to obtain it."
  )
}
#' @title Raise a typed warning of the package
#' @description Builds and signals a warning condition whose class vector
#'   identifies the kind of degradation being reported, so that callers can
#'   catch or silence one kind without touching the others.
#' @param kind A character scalar naming the kind of degradation. It becomes
#'   the first element of the class vector, prefixed with \code{"ra_"}.
#' @param message A character scalar with the message shown to the user.
#' @param call The call to report as the origin of the condition. Defaults to
#'   the caller of the function that raises.
#' @param ... Further named fields stored in the condition object.
#' @return The function signals a warning and then returns \code{NULL}
#'   invisibly, so execution continues at the caller.
#' @details The class vector is
#'   \code{c("ra_<kind>", "ra_warning", "warning", "condition")}, mirroring
#'   the error side. A warning here is reserved for a computation that can
#'   continue on a declared fallback and says so; a violated contract raises
#'   through [ra_stop()] instead, and an undecided verdict does neither.
#' @section Methodological notes:
#'   The warning path exists for exactly one situation: a safeguard has
#'   degraded the fast level and the rigorous level is available to escalate
#'   to. Continuing in silence would hide the degradation, and stopping would
#'   punish a caller whose answer can still be produced with its guarantee
#'   intact. The word travels with the result.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Wickham, H. (2019). Advanced R (2nd ed.). Chapman & Hall/CRC.
#'   https://doi.org/10.1201/9781351201315
#' @examples
#' res <- withCallingHandlers(
#'   {
#'     ra_warn("example_kind", "an example warning")
#'     "the computation continued"
#'   },
#'   ra_example_kind = function(w) invokeRestart("muffleWarning")
#' )
#' res
#' @seealso [ra_stop()] for the error side of the condition system.
#' @export
ra_warn <- function(kind, message, call = sys.call(-1L), ...) {
  cond <- structure(
    class = c(paste0("ra_", kind), "ra_warning", "warning", "condition"),
    list(message = message, call = call, ...))
  warning(cond)
  invisible(NULL)
}
