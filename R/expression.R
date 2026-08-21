## Expressions, and the dependence problem.
##
## Evaluating an expression in interval arithmetic gives an enclosure of its
## range, but a wide one, because each occurrence of a variable is treated as an
## independent quantity: the enclosure of x - x over [-1, 1] is [-2, 2] and not
## [0, 0]. That is the dependence problem, and it is not a defect to be hidden.
## The overestimate is what makes the answer safe, and this file does not
## rewrite expressions to conceal it. What it does is compute a second enclosure
## by a different route and intersect, because two valid enclosures intersect to
## a valid enclosure and the narrower one wins without either being trusted
## alone.

## The head symbols of an expression, which is what has to be inside the closed
## table. The names appearing as leaves are variables and constants and are not
## symbols of the table.
.ra_expr_heads <- function(e, acc = character(0)) {
  if (is.call(e)) {
    acc <- c(acc, as.character(e[[1L]]))
    for (i in seq_along(e)[-1L]) acc <- .ra_expr_heads(e[[i]], acc)
  }
  acc
}

## The variables of an expression: the leaf names.
.ra_expr_vars <- function(e, acc = character(0)) {
  if (is.name(e)) return(c(acc, as.character(e)))
  if (is.call(e)) {
    for (i in seq_along(e)[-1L]) acc <- .ra_expr_vars(e[[i]], acc)
  }
  acc
}

## Is an exponent a constant whole number? Only then does the tight integer
## power apply; otherwise the general power is used, with the domain it needs.
.ra_whole_constant <- function(e) {
  is.numeric(e) && length(e) == 1L && is.finite(e) && e == round(e)
}

.ra_eval_node <- function(e, env, level, precision) {
  if (is.numeric(e)) return(ra_interval(e, e))
  if (is.name(e)) {
    nm <- as.character(e)
    if (!nm %in% names(env)) {
      ra_stop("unbound_variable",
              paste0("`", nm, "` has no value in the environment given to the ",
                     "evaluator. Every variable of the expression needs an ",
                     "interval or a number."),
              variable = nm)
    }
    return(.ra_as_ivl(env[[nm]]))
  }
  if (!is.call(e)) {
    ra_stop("bad_argument",
            "An expression may contain only numbers, names and calls.")
  }
  h <- as.character(e[[1L]])
  rec <- function(k) .ra_eval_node(e[[k]], env, level, precision)

  if (identical(h, "(")) return(rec(2L))
  if (identical(h, "+")) {
    return(if (length(e) == 2L) rec(2L) else ra_add(rec(2L), rec(3L)))
  }
  if (identical(h, "-")) {
    return(if (length(e) == 2L) ra_neg(rec(2L)) else ra_sub(rec(2L), rec(3L)))
  }
  if (identical(h, "*")) return(ra_mul(rec(2L), rec(3L)))
  if (identical(h, "/")) return(ra_div(rec(2L), rec(3L)))
  if (identical(h, "^")) {
    if (.ra_whole_constant(e[[3L]])) return(ra_pown(rec(2L), as.integer(e[[3L]])))
    ## A general power is exp(y * log(x)), which needs a positive base; the
    ## domain failure travels as the trivial decoration of the logarithm rather
    ## than as an error, which is what the standard prescribes.
    return(ra_elem("exp", ra_mul(rec(3L), ra_elem("log", rec(2L), level,
                                                  precision)),
                   level, precision))
  }
  if (h %in% names(.ra_shape)) return(ra_elem(h, rec(2L), level, precision))
  ra_slack(h)  ## raises ra_symbol_not_in_table with the reason it is refused
}

#' @title Check that an expression is written with admitted symbols
#' @description Walks an expression and refuses, by name and with the reason, any
#'   symbol outside the closed table of this version.
#' @param e A call, a name or a number, as returned by \code{quote()} or
#'   \code{str2lang()}.
#' @return Invisibly, a character vector of the variables the expression uses.
#'   Raises \code{ra_symbol_not_in_table} if a head symbol is refused.
#' @details The check is separate from the evaluation so that a caller can find
#'   out whether an expression is admissible before committing to a computation
#'   over it, and so that the refusal names the symbol rather than arriving as a
#'   failure deep inside a recursion.
#' @section Methodological notes:
#'   The table is closed by enumeration and not open by default. An unknown
#'   symbol is refused rather than evaluated on the assumption that whatever R
#'   does with it is an interval extension of it, which is the assumption that
#'   would silently turn an enclosure into an estimate.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Moore, R. E., Kearfott, R. B., & Cloud, M. J. (2009). Introduction to interval
#'   analysis. Society for Industrial and Applied Mathematics.
#'   https://doi.org/10.1137/1.9780898717716
#' @examples
#' ra_check_expr(quote(exp(x) - x^2))
#' tryCatch(ra_check_expr(quote(besselJ(x, 1))),
#'          ra_symbol_not_in_table = function(cnd) "refused")
#' @seealso [ra_operator_table()] and [ra_eval_natural()].
#' @export
ra_check_expr <- function(e) {
  heads <- unique(.ra_expr_heads(e))
  bad <- setdiff(heads, c(.ra_operators, names(.ra_shape)))
  if (length(bad)) ra_slack(bad[1L])
  invisible(unique(.ra_expr_vars(e)))
}

#' @title Natural interval extension of an expression
#' @description Evaluates an expression with every operation replaced by its
#'   interval counterpart, giving an enclosure of the set of values the
#'   expression takes as its variables range over their intervals.
#' @param e A call, a name or a number.
#' @param env A named list giving each variable of \code{e} an object of class
#'   \code{ra_ivl} or a numeric vector.
#' @param level A character scalar passed to [ra_elem()] for the elementary
#'   functions, \code{"fast"} or \code{"rigorous"}. Defaults to \code{"fast"}.
#' @param precision An integer scalar, the working precision of the rigorous
#'   level. Defaults to the first rung of [ra_precision_ladder()].
#' @return An object of class \code{ra_ivl}.
#' @details Each occurrence of a variable is evaluated independently, so an
#'   expression mentioning a variable more than once is generally overestimated.
#'   The overestimate is one-sided and that is the whole guarantee: the result
#'   contains the range and may be wider, so a value proved outside it is proved
#'   outside the range.
#'
#'   An integer constant exponent uses the tight integer power, which handles a
#'   base spanning zero correctly; any other exponent is evaluated as the
#'   exponential of the product with the logarithm, which needs a positive base
#'   and reports a base that is not positive through the decoration.
#' @section Methodological notes:
#'   The identity \code{x - x = 0} is not applied. Implementing it would make
#'   this expression exact and every expression not covered by the rewriting rule
#'   silently different from the ones that are, which is worse than a uniform
#'   overestimate a caller can reason about. The package chooses not to be clever
#'   in one place at the price of being unpredictable everywhere, and the choice
#'   has a test that fixes it: the enclosure of \code{x - x} over \code{[-1, 1]}
#'   is asserted to be \code{[-2, 2]}.
#' @section Dependencies:
#'   Base R at the fast level; 'Rmpfr' from \code{Suggests} at the rigorous one.
#' @references
#'   Moore, R. E., Kearfott, R. B., & Cloud, M. J. (2009). Introduction to interval
#'   analysis. Society for Industrial and Applied Mathematics.
#'   https://doi.org/10.1137/1.9780898717716
#'
#'   Neumaier, A. (1990). Interval methods for systems of equations. Cambridge
#'   University Press. https://doi.org/10.1017/CBO9780511526473
#' @examples
#' x <- ra_interval(-1, 1)
#' ra_eval_natural(quote(x - x), list(x = x))
#' ra_eval_natural(quote(exp(x) + x^2), list(x = ra_interval(0, 1)))
#' @seealso [ra_enclose_expr()], which combines this with the centered form.
#' @export
ra_eval_natural <- function(e, env, level = c("fast", "rigorous"),
                            precision = ra_precision_ladder()[1L]) {
  level <- match.arg(level)
  ra_check_expr(e)
  .ra_eval_node(e, env, level, as.integer(precision)[1L])
}

#' @title Enclose the range of a univariate expression, by three routes at once
#' @description Computes the range of an expression over an interval by the
#'   natural extension, by the centered form and, when the derivative allows it,
#'   by monotonicity, and returns the intersection of whichever routes applied.
#' @param e A call, a name or a number.
#' @param x An object of class \code{ra_ivl} of length one, or a numeric vector
#'   of length one or two giving the endpoints.
#' @param var A character scalar naming the variable that ranges over \code{x}.
#'   Defaults to \code{"x"}.
#' @param env A named list giving values to the other variables of \code{e}.
#'   Defaults to an empty list.
#' @param methods A character vector choosing the routes to attempt, any of
#'   \code{"natural"}, \code{"mean_value"} and \code{"monotonic"}. Defaults to
#'   all three.
#' @param level A character scalar, \code{"fast"} or \code{"rigorous"}.
#' @param precision An integer scalar, the working precision of the rigorous
#'   level.
#' @return An object of class \code{ra_ivl} of length one, carrying the attribute
#'   \code{"ra_routes"}, a character vector naming the routes that contributed.
#' @details The three routes are three theorems and the answer is their
#'   intersection, which is valid because each of them alone is.
#'
#'   The natural extension evaluates the expression with interval operations. It
#'   always applies and is usually the widest.
#'
#'   The centered form is \code{f(c) + df(x) * (x - c)}, with \code{df} the
#'   derivative and \code{c} the
#'   midpoint. It is the mean value theorem read as an enclosure. It needs the
#'   derivative, which comes from the differentiation engine of R, and it is
#'   narrower than the natural extension on a narrow box and wider on a wide one,
#'   which is why both are computed rather than one chosen in advance.
#'
#'   The monotonicity route applies when the enclosure of the derivative excludes
#'   zero. The function is then monotone on the box, its range is the hull of the
#'   values at the two endpoints, and that is the exact range up to the enclosure
#'   of the endpoint evaluations themselves. It is the cheapest and the tightest
#'   and it is tried first in the sense that it is reported when it applies.
#' @section Methodological notes:
#'   Intersecting rather than choosing is deliberate. A rule that picked the
#'   narrower of two enclosures by comparing their widths would be making a
#'   decision the caller cannot audit; the intersection needs no decision and is
#'   never wider than either. Where a route does not apply it contributes
#'   nothing, and which ones contributed is recorded in the returned attribute
#'   rather than left to be inferred from the width.
#' @section Dependencies:
#'   Uses \code{stats::D} for the derivative. 'Rmpfr' from \code{Suggests} at the
#'   rigorous level.
#' @references
#'   Moore, R. E., Kearfott, R. B., & Cloud, M. J. (2009). Introduction to interval
#'   analysis. Society for Industrial and Applied Mathematics.
#'   https://doi.org/10.1137/1.9780898717716
#'
#'   Neumaier, A. (1990). Interval methods for systems of equations. Cambridge
#'   University Press. https://doi.org/10.1017/CBO9780511526473
#' @examples
#' ra_enclose_expr(quote(x - x), ra_interval(-1, 1))
#' ra_enclose_expr(quote(exp(x)), ra_interval(0, 1))
#' ra_enclose_expr(quote(r - x^2), ra_interval(-1, 1), env = list(r = 0.5))
#' @seealso [ra_eval_natural()].
#' @export
ra_enclose_expr <- function(e, x, var = "x", env = list(),
                            methods = c("natural", "mean_value", "monotonic"),
                            level = c("fast", "rigorous"),
                            precision = ra_precision_ladder()[1L]) {
  level <- match.arg(level)
  methods <- match.arg(methods, several.ok = TRUE)
  ra_check_expr(e)
  if (!is.character(var) || length(var) != 1L) {
    ra_stop("bad_argument", "`var` must be a single character string.")
  }
  x <- .ra_as_ivl(x)
  if (length(x) != 1L) {
    ra_stop("bad_argument",
            paste0("`x` must be a single interval; the routes are combined ",
                   "per box and a vector would hide which box used which."))
  }
  precision <- as.integer(precision)[1L]
  at <- function(v) .ra_eval_node(e, c(env, stats::setNames(list(v), var)),
                                  level, precision)

  got <- ra_entire()
  used <- character(0)
  natural <- NULL

  if ("natural" %in% methods) {
    natural <- at(x)
    got <- ra_intersect(got, natural)
    used <- c(used, "natural")
  }

  deriv <- tryCatch(stats::D(e, var), error = function(err) NULL)
  dx <- NULL
  if (!is.null(deriv) &&
      length(setdiff(unique(.ra_expr_heads(deriv)),
                     c(.ra_operators, names(.ra_shape)))) == 0L) {
    dx <- tryCatch(.ra_eval_node(deriv,
                                 c(env, stats::setNames(list(x), var)),
                                 level, precision),
                   ra_error = function(cnd) NULL)
  }

  if (!is.null(dx) && !ra_is_nai(dx) && !ra_is_empty(dx)) {
    if ("mean_value" %in% methods) {
      c0 <- ra_mid(x)
      if (is.finite(c0)) {
        ctr <- ra_interval(c0, c0)
        mv <- ra_add(at(ctr), ra_mul(dx, ra_sub(x, ctr)))
        got <- ra_intersect(got, mv)
        used <- c(used, "mean_value")
      }
    }
    if ("monotonic" %in% methods && !(ra_inf(dx) <= 0 && ra_sup(dx) >= 0)) {
      lo <- at(ra_interval(ra_inf(x), ra_inf(x)))
      hi <- at(ra_interval(ra_sup(x), ra_sup(x)))
      got <- ra_intersect(got, ra_hull(lo, hi))
      used <- c(used, "monotonic")
    }
  }

  ## The intersection is decorated trv by the standard, because no single
  ## decoration is right for every use of a set operation. Here the caller can
  ## justify a stronger one: the routes are interval extensions of the same
  ## function on the same box, so the weakest of their decorations is the claim
  ## the result can carry.
  if (length(used)) {
    got <- ra_set_dec(got, ra_dec(if (is.null(natural)) got else natural))
  }
  structure(got, ra_routes = used)
}
