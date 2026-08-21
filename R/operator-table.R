## The closed table of admissible symbols.
##
## An expression that this package can enclose is written with symbols from a
## table that is closed by enumeration, not open by default. The table was
## fixed by measuring the installed derivative engine and the installed
## multiprecision backend, and a symbol that is not in it is refused by name
## rather than evaluated on a guess. The four admission criteria are recorded
## with the table because a table whose reasons are not written down cannot be
## revisited when one of the four measurements changes.

## Largest known error in units in the last place, binary64, round-to-nearest,
## GNU libc 2.43, transcribed from Table 3 of the accuracy report cited in the
## documentation below. The report states that for double precision these are
## lower bounds located by a black-box search, not proven upper bounds; that is
## the fact the slack convention exists to absorb.
.ra_ulp_glibc <- c(
  exp = 0.511, log = 0.520, sin = 0.516, cos = 0.516, tan = 0.619,
  sinh = 1.93, cosh = 1.93, tanh = 2.21, sqrt = 0.500, expm1 = 0.913,
  log1p = 0.899, log2 = 0.548, log10 = 1.62, asin = 0.516, acos = 0.523,
  atan = 0.523
)

## Binary operators, unary sign and grouping. These carry no slack: the exact
## result of a rounded arithmetic operation is bracketed by the predecessor and
## successor of the computed one, which is a theorem and not a measurement.
.ra_operators <- c("+", "-", "*", "/", "^", "(")

## Symbols that stats::D differentiates but that this version refuses, each with
## the criterion it fails and the measurement behind it.
.ra_excluded <- list(
  gamma = "C4: the rigorous level breaks at the third derivative, because the chain gamma -> digamma -> trigamma leaves what MPFR provides; the installed Rmpfr answers 'Math op. 43 not yet implemented' for trigamma.",
  lgamma = "C4: same chain as gamma, reached one derivative later.",
  digamma = "C4: its derivative is trigamma, which the installed Rmpfr does not provide.",
  trigamma = "C4: not provided by the installed Rmpfr.",
  psigamma = "C4: not provided by the installed Rmpfr, and its derivatives raise the polygamma order without bound, so no finite set of symbols closes the family.",
  pnorm = "C3: no published error bound applies. R computes pnorm in its own numerical library rather than in the system math library, so the accuracy report says nothing about it, and a slack cannot be declared from a number that was never measured.",
  dnorm = "C3: same as pnorm.",
  abs = "C1: the installed stats::D does not differentiate it, and its derivative does not exist at zero. The interval operation abs() is provided in the kernel; what is refused is its appearance inside a differentiable expression.",
  sign = "C1: not in the derivative table of the installed stats::D.",
  asinh = "C1: not in the derivative table of the installed stats::D.",
  acosh = "C1: not in the derivative table of the installed stats::D.",
  atanh = "C1: not in the derivative table of the installed stats::D.",
  floor = "C1: not in the derivative table of the installed stats::D.",
  ceiling = "C1: not in the derivative table of the installed stats::D.",
  round = "C1: not in the derivative table of the installed stats::D.",
  trunc = "C1: not in the derivative table of the installed stats::D.",
  max = "C1: not in the derivative table of the installed stats::D.",
  min = "C1: not in the derivative table of the installed stats::D.",
  "%%" = "C1: not in the derivative table of the installed stats::D.",
  "%/%" = "C1: not in the derivative table of the installed stats::D."
)

#' @title The closed table of symbols an expression may use
#' @description Returns the symbols this version of the package admits inside an
#'   expression it is asked to enclose, together with the largest known error of
#'   the system math library for each one and the slack the fast level adds on
#'   top of it.
#' @param what A character scalar choosing what to return: \code{"functions"}
#'   for the unary functions with their errors and slacks, \code{"operators"}
#'   for the operators and grouping symbols, \code{"excluded"} for the symbols
#'   that are refused and the criterion each one fails, or \code{"all"} for a
#'   list holding the three. Defaults to \code{"functions"}.
#' @return For \code{"functions"}, a data frame with columns \code{fun},
#'   \code{ulp} and \code{slack}. For \code{"operators"}, a character vector.
#'   For \code{"excluded"}, a data frame with columns \code{symbol} and
#'   \code{reason}. For \code{"all"}, a named list with all three.
#' @details A symbol is admitted only if it satisfies four conditions at once,
#'   all of them measured against the installed software rather than read from
#'   documentation.
#'
#'   The first is that the installed \code{stats::D} differentiates it, since
#'   the centered form and the monotonicity test both need a derivative and the
#'   package does not carry a differentiation engine of its own.
#'
#'   The second is that the table is closed under differentiation: the
#'   derivative of an admitted symbol, and the derivative of that, and so on
#'   until the set stops growing, must be writable with admitted symbols. This
#'   is the condition that a table assembled by taste tends to fail, and failing
#'   it is not a nuisance but a hole: the mean-value form leaves the table on
#'   its first step and there is nothing to evaluate.
#'
#'   The third is that a largest known error in units in the last place is
#'   published for the system math library, since the fast level is a
#'   library evaluation widened by a declared slack and a slack cannot be
#'   declared over an unmeasured error.
#'
#'   The fourth is that the multiprecision backend provides the function with
#'   correct rounding, since otherwise the rigorous level and the escalation
#'   ladder have nowhere to go and a verdict lying inside the slack could never
#'   be resolved.
#'
#'   The slack is \code{ceiling(2 * e + 1)} units in the last place, where
#'   \code{e} is the published error. The factor of two and the added unit
#'   absorb two known gaps: the published figures for double precision are lower
#'   bounds found by search rather than proven upper bounds, and the measured
#'   build is not bit-for-bit the build installed here. The convention is named
#'   and cited rather than tuned, and it is never widened to accommodate a
#'   failing point; a point outside the slack is investigated instead.
#' @section Methodological notes:
#'   The entry for \code{sqrt} is deliberately conservative. Correct rounding of
#'   the square root is required by the floating-point standard, so a single
#'   outward step provably encloses it and the published 0.500 is an upper bound
#'   rather than a lower one. The table nonetheless applies the same convention
#'   to it as to every other entry, so that no function carries a rule of its
#'   own; the cost is one unit in the last place on an operation whose width is
#'   negligible at the scales this package works at, and the benefit is a table
#'   with no special cases to get wrong.
#'
#'   The error figures are Table 3, column GNU libc 2.43, of Gladman et al.
#'   (2026), which is the report the documentation of the GNU C Library refers
#'   to for its accuracy figures; the correct rounding of the square root is
#'   clause 5.4.1 of IEEE Std 754-2019.
#' @section Dependencies:
#'   Uses \code{stats::D} to close the table, and probes 'Rmpfr' from
#'   \code{Suggests} for the fourth criterion.
#' @references
#'   Gladman, B., Innocente, V., Mather, J., Ozaki, K., & Zimmermann, P. (2026).
#'   Accuracy of mathematical functions in single, double, double extended, and
#'   quadruple precision (edition of February 2026) [Technical report].
#'   https://members.loria.fr/PZimmermann/papers/accuracy.pdf
#'
#'   Institute of Electrical and Electronics Engineers. (2019). IEEE standard for
#'   floating-point arithmetic (IEEE Std 754-2019).
#'   https://doi.org/10.1109/IEEESTD.2019.8766229
#' @examples
#' tab <- ra_operator_table()
#' tab[tab$fun %in% c("exp", "tanh"), ]
#' ra_operator_table("operators")
#' head(ra_operator_table("excluded"), 3)
#' @seealso [ra_slack()], which reads a single entry of the table.
#' @export
ra_operator_table <- function(what = c("functions", "operators", "excluded",
                                       "all")) {
  what <- match.arg(what)
  funs <- data.frame(
    fun = names(.ra_ulp_glibc),
    ulp = unname(.ra_ulp_glibc),
    slack = ceiling(2 * unname(.ra_ulp_glibc) + 1),
    stringsAsFactors = FALSE
  )
  excl <- data.frame(
    symbol = names(.ra_excluded),
    reason = unlist(.ra_excluded, use.names = FALSE),
    stringsAsFactors = FALSE
  )
  switch(what,
         functions = funs,
         operators = .ra_operators,
         excluded = excl,
         all = list(functions = funs, operators = .ra_operators,
                    excluded = excl))
}

#' @title Slack in units in the last place declared for one function
#' @description Returns the number of outward rounding steps the fast level adds
#'   to an evaluation of the named function, on top of the outward step that
#'   every rounded operation already receives.
#' @param fun A character scalar naming a function of the closed table.
#' @return An integer scalar, the number of steps.
#' @details The value is \code{ceiling(2 * e + 1)} for the published error
#'   \code{e} of the named function. Asking for a symbol outside the table
#'   raises \code{ra_symbol_not_in_table} rather than returning a default,
#'   because a default here would be a number chosen by nobody and applied to
#'   everything the table forgot.
#' @section Methodological notes:
#'   The slack is a declared convention, not a calibration. It is not fitted to
#'   any observed failure and it is not adjusted when a sweep finds a point
#'   outside it; such a point is a finding about the evaluation, and the
#'   response is to investigate the point, not to enlarge the number until the
#'   point falls inside.
#'
#'   The published figures are Table 3 of Gladman et al. (2026).
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Gladman, B., Innocente, V., Mather, J., Ozaki, K., & Zimmermann, P. (2026).
#'   Accuracy of mathematical functions in single, double, double extended, and
#'   quadruple precision (edition of February 2026) [Technical report].
#'   https://members.loria.fr/PZimmermann/papers/accuracy.pdf
#' @examples
#' ra_slack("exp")
#' ra_slack("tanh")
#' tryCatch(ra_slack("gamma"), ra_symbol_not_in_table = function(cnd) "refused")
#' @seealso [ra_operator_table()].
#' @export
ra_slack <- function(fun) {
  if (!is.character(fun) || length(fun) != 1L || is.na(fun)) {
    ra_stop("bad_argument", "`fun` must be a single character string.")
  }
  if (!fun %in% names(.ra_ulp_glibc)) {
    reason <- if (!is.null(.ra_excluded[[fun]])) {
      paste0(" It is refused for a stated reason. ", .ra_excluded[[fun]])
    } else {
      ""
    }
    ra_stop("symbol_not_in_table",
            paste0("`", fun, "` is not in the closed table of this version, ",
                   "so no slack is declared for it.", reason,
                   " See ra_operator_table() for what is admitted."),
            symbol = fun)
  }
  as.integer(ceiling(2 * .ra_ulp_glibc[[fun]] + 1))
}

#' @title Re-close the table against the installed software
#' @description Runs the admission criteria again, here and now, against the
#'   derivative engine and the multiprecision backend of the machine the package
#'   is running on, and reports what it found.
#' @param include_mpfr A logical scalar saying whether to test the fourth
#'   criterion, which needs the optional backend. Defaults to whether the
#'   backend is installed.
#' @return A list with four elements. \code{differentiable} is a character
#'   vector of admitted functions the installed derivative engine refuses.
#'   \code{escaped} is a character vector of symbols that the derivatives of the
#'   admitted set reach and that the table does not contain. \code{unsupported}
#'   is a character vector of admitted functions the backend does not provide,
#'   or \code{NULL} when the fourth criterion was not tested.
#'   \code{closed} is a logical scalar, \code{TRUE} when the first three are all
#'   empty.
#' @details The table in the sources is a transcription of measurements taken on
#'   one machine on one day. The software underneath it moves: a release of R
#'   can add a rule to the derivative table, and a release of the backend can
#'   implement a function it did not have. This function exists so that the
#'   transcription can be audited rather than trusted, by whoever is running the
#'   package and not only by whoever wrote it.
#'
#'   The closure is computed over head symbols rather than over whole
#'   expressions, which is what makes it terminate. Differentiating a function
#'   whose derivative is the same function at a higher order never repeats an
#'   expression, and a walk over expressions would not stop; it repeats its head
#'   immediately. The general power is seeded explicitly, because its rule is
#'   the only one that introduces a symbol present in neither operand, and it
#'   introduces it only when the exponent contains the variable.
#' @section Methodological notes:
#'   A check that can only pass is not a check. This one can fail in three
#'   independent ways, and each failure names the symbol responsible rather than
#'   reporting that something is wrong. Failure of the second criterion is the
#'   serious one: it means the centered form of some admitted function leaves
#'   the table on its first step, and there is nothing to evaluate.
#'
#'   Chapter 5 of Moore et al. (2009) treats interval extensions of
#'   expressions and the role of the derivative in the centered form.
#' @section Dependencies:
#'   Uses \code{stats::D}. Probes 'Rmpfr' from \code{Suggests} for the fourth
#'   criterion, and reports \code{NULL} for it when the backend is absent.
#' @references
#'   Moore, R. E., Kearfott, R. B., & Cloud, M. J. (2009). Introduction to interval
#'   analysis. Society for Industrial and Applied Mathematics.
#'   https://doi.org/10.1137/1.9780898717716
#' @examples
#' rep <- ra_verify_operator_table(include_mpfr = FALSE)
#' rep$closed
#' rep$escaped
#' @seealso [ra_operator_table()].
#' @export
ra_verify_operator_table <- function(include_mpfr = ra_has_mpfr()) {
  admitted <- names(.ra_ulp_glibc)

  symbols_of <- function(e, acc = character(0)) {
    if (is.call(e)) {
      acc <- c(acc, as.character(e[[1L]]))
      for (i in seq_along(e)[-1L]) acc <- symbols_of(e[[i]], acc)
    }
    acc
  }
  calls_of <- function(e, acc = list()) {
    if (is.call(e)) {
      acc <- c(acc, list(e))
      for (i in seq_along(e)[-1L]) acc <- calls_of(e[[i]], acc)
    }
    acc
  }

  refused <- character(0)
  for (f in admitted) {
    d <- tryCatch(stats::D(call(f, quote(x)), "x"), error = function(e) NULL)
    if (is.null(d)) refused <- c(refused, f)
  }

  queue <- c(lapply(admitted, function(f) call(f, quote(x))), list(quote(x^x)))
  heads <- character(0)
  reached <- character(0)
  while (length(queue)) {
    e <- queue[[1L]]
    queue <- queue[-1L]
    h <- as.character(e[[1L]])
    if (h %in% heads) next
    heads <- c(heads, h)
    d <- tryCatch(stats::D(e, "x"), error = function(err) NULL)
    if (is.null(d)) next
    reached <- c(reached, symbols_of(d))
    queue <- c(queue, calls_of(d))
  }
  escaped <- sort(setdiff(unique(reached), c(admitted, .ra_operators)))

  unsupported <- NULL
  if (isTRUE(include_mpfr)) {
    if (!ra_has_mpfr()) {
      ra_stop("no_mpfr",
              paste0("The fourth criterion needs package 'Rmpfr', which is ",
                     "not installed. Call with include_mpfr = FALSE to run ",
                     "the other three."))
    }
    x <- Rmpfr::mpfr("0.3", 120L)
    unsupported <- character(0)
    for (f in admitted) {
      ok <- tryCatch(inherits(do.call(f, list(x)), "mpfr"),
                     error = function(e) FALSE)
      if (!isTRUE(ok)) unsupported <- c(unsupported, f)
    }
  }

  list(differentiable = refused,
       escaped = escaped,
       unsupported = unsupported,
       closed = length(refused) == 0L && length(escaped) == 0L &&
         (is.null(unsupported) || length(unsupported) == 0L))
}
