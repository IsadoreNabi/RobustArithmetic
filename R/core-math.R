#' Evaluate a vendored correctly rounded elementary function
#'
#' Evaluate one of the package's sixteen binary64 elementary-function kernels.
#' This internal interface supports validation of the vendored implementation;
#' the package's fast interval level does not call it yet.
#'
#' @param fun A character scalar naming one of `exp`, `log`, `sin`, `cos`,
#'   `tan`, `sinh`, `cosh`, `tanh`, `sqrt`, `expm1`, `log1p`, `log2`, `log10`,
#'   `asin`, `acos`, or `atan`.
#' @param x A numeric vector. Integer values are converted to binary64 before
#'   evaluation.
#'
#' @return A double vector with the same length as `x` and no attributes.
#'
#' @details The fifteen software kernels come from the pinned CORE-MATH source.
#'   Square root uses the platform's hardware operation. Missing values remain
#'   missing values, and not-a-number values remain not-a-number values.
#'
#' @section Methodological notes:
#'   The compiled implementation is tested bit for bit against references
#'   computed independently with MPFR. Those references are not produced by
#'   this interface or by the vendored implementation.
#'
#' @section Dependencies:
#'   Uses R's registered native-routine interface. The compiled kernels have no
#'   external package dependency.
#'
#' @references
#'   Sibidanov, A., Zimmermann, P., & Glondu, S. (2022). The CORE-MATH project.
#'   In 2022 IEEE 29th Symposium on Computer Arithmetic (ARITH) (pp. 26-34).
#'   IEEE. https://doi.org/10.1109/ARITH54963.2022.00014
#'
#' @seealso [ra_elem()] for the public interval interface that remains on its
#'   existing evaluation path in this integration unit.
#' @noRd
.ra_cr <- function(fun, x) {
  if (!is.character(fun) || length(fun) != 1L || is.na(fun)) {
    stop("`fun` must be one non-missing function name.", call. = FALSE)
  }
  if (!is.numeric(x)) {
    stop("`x` must be a numeric vector.", call. = FALSE)
  }
  .Call(C_ra_core_math, fun, x)
}
