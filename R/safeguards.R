## Safeguards of the fast level.
##
## The fast level uses the correctly rounded binary64 evaluator included in
## the package. Its load-time safeguard therefore verifies that evaluator, not
## a version string or a platform label. Each sentinel stores an independently
## computed result, and the running evaluator must reproduce it bit for bit.
## With Rmpfr available, the first fast use also audits a fresh sample against
## MPFR. Either disagreement degrades the fast level for the session.
##
## Degradation is session state. The first affected result warns once and
## escalates to the rigorous level when Rmpfr is available. Without Rmpfr every
## affected evaluation refuses with a typed error. The public status function
## exposes the state, its reason, the sentinel verification and the audit.

## Mutable state of the loaded namespace. .onLoad() clears and rebuilds every
## binding so that calling it again is a complete self-verification.
.ra_state <- new.env(parent = emptyenv())

.ra_binary64_bits <- function(value) {
  vapply(value, function(element) {
    paste(rev(as.character(writeBin(element, raw(), size = 8L,
                                    endian = "little"))),
          collapse = "")
  }, character(1L), USE.NAMES = FALSE)
}

#' Independent sentinels of the fast level
#'
#' Return the difficult binary64 cases used to verify the elementary-function
#' evaluator included in the package whenever the namespace loads.
#'
#' @return A data frame with eight rows for each admitted function and columns
#'   `fun`, `x`, `cr`, `role`, `source` and `source_index`. `cr` is the
#'   correctly rounded binary64 value independently computed for `x`.
#'
#' @details For the fifteen software kernels, the inputs are selected
#'   deterministically across the difficult-case files in the sealed
#'   CORE-MATH archive. Square-root inputs come from the sealed binary64 sample
#'   used by the package's independent kernel tests. `dev/gen_sentinels.R`
#'   evaluates every selected input with Rmpfr at 200 bits and converts the
#'   result once with `Rmpfr::asNumeric()`. It never obtains an expected value
#'   from the evaluator that the table guards.
#'
#' @section Methodological notes:
#'   A self-check is informative only when its expected values do not share the
#'   implementation under examination. The generator therefore seals the input
#'   archive by its SHA-256 digest, derives the expected values through MPFR and
#'   stores those values as package data. Loading the package needs no optional
#'   dependency and does not regenerate the evidence.
#'
#' @section Dependencies:
#'   Base R. Regeneration requires `Rmpfr`; ordinary use does not.
#'
#' @references
#'   Fousse, L., Hanrot, G., Lefevre, V., Pelissier, P., & Zimmermann, P. (2007).
#'   MPFR: A multiple-precision binary floating-point library with correct
#'   rounding. *ACM Transactions on Mathematical Software, 33*(2), Article 13.
#'   https://doi.org/10.1145/1236463.1236468
#'
#'   Sibidanov, A., Zimmermann, P., & Glondu, S. (2022). The CORE-MATH project.
#'   In *2022 IEEE 29th Symposium on Computer Arithmetic (ARITH)* (pp. 26-34).
#'   IEEE. https://doi.org/10.1109/ARITH54963.2022.00014
#'
#' @examples
#' sentinels <- ra_sentinels()
#' table(sentinels$fun)
#'
#' @seealso [ra_check_sentinels()] for the bitwise verification and
#'   [ra_fast_level_status()] for the session state.
#' @md
#' @export
ra_sentinels <- function() {
  .ra_sentinels
}

#' Verify the included evaluator against independent sentinels
#'
#' Evaluate every stored difficult case through the same binary64 evaluator as
#' the fast level and compare each result bit for bit with its independent
#' correctly rounded value.
#'
#' @return A data frame with columns `fun`, `x`, `role`, `source`,
#'   `source_index`, `expected`, `observed`, `expected_bits`, `observed_bits`
#'   and `ok`. Each row of `ok` is `TRUE` only when the two binary64 bit
#'   patterns are identical.
#'
#' @details The comparison preserves distinctions hidden by ordinary numeric
#'   equality, including the sign of zero. Any error while evaluating the
#'   table makes the load-time verification unavailable, which degrades the
#'   fast level rather than certifying an unchecked evaluator.
#'
#' @section Methodological notes:
#'   Version agreement cannot establish that compiled mathematics behaves as
#'   intended. This check asks the installed evaluator itself to reproduce
#'   independently generated difficult cases. Its control is exercised by
#'   replacing that evaluator with a one-neighbour perturbation in the scenario
#'   harness and requiring the verification to fail.
#'
#' @section Dependencies:
#'   Base R and the package's registered native routines.
#'
#' @references
#'   Sibidanov, A., Zimmermann, P., & Glondu, S. (2022). The CORE-MATH project.
#'   In *2022 IEEE 29th Symposium on Computer Arithmetic (ARITH)* (pp. 26-34).
#'   IEEE. https://doi.org/10.1109/ARITH54963.2022.00014
#'
#' @examples
#' check <- ra_check_sentinels()
#' all(check$ok)
#'
#' @seealso [ra_sentinels()] for the stored cases and
#'   [ra_fast_level_status()] for the session-level consequence.
#' @md
#' @export
ra_check_sentinels <- function() {
  sentinels <- .ra_sentinels
  observed <- rep(NA_real_, nrow(sentinels))
  for (function_name in unique(sentinels$fun)) {
    selected <- sentinels$fun == function_name
    observed[selected] <- .ra_cr(function_name, sentinels$x[selected])
  }
  expected_bits <- .ra_binary64_bits(sentinels$cr)
  observed_bits <- .ra_binary64_bits(observed)
  data.frame(
    fun = sentinels$fun,
    x = sentinels$x,
    role = sentinels$role,
    source = sentinels$source,
    source_index = sentinels$source_index,
    expected = sentinels$cr,
    observed = observed,
    expected_bits = expected_bits,
    observed_bits = observed_bits,
    ok = expected_bits == observed_bits,
    stringsAsFactors = FALSE
  )
}

#' Status of the fast level in the current session
#'
#' Report whether the fast level is degraded, why it is degraded, and the two
#' verifications that determine its session state.
#'
#' @return A list with four fields: `degraded`, a logical scalar; `reason`, an
#'   empty character vector while healthy or a character scalar naming every
#'   active cause; `sentinels`, the data frame returned by
#'   [ra_check_sentinels()] at load time or `NULL` if that verification could
#'   not run; and `audit`, the first-use comparison against MPFR or `NULL` until
#'   that audit runs.
#'
#' @details The status is read-only. A failed load-time sentinel verification
#'   degrades the level immediately. With `Rmpfr` available, the first fast
#'   evaluation also runs [ra_measure_library_error()] and degrades the level
#'   if an observed error exceeds its declared slack. The first result affected
#'   by a degraded state emits one warning of class `ra_fast_level_unsafe` and
#'   escalates to the rigorous level; later results remain rigorous without
#'   repeating the warning. Without `Rmpfr`, every affected evaluation refuses
#'   with an error of the same class because no rigorous result can replace it.
#'
#' @section Methodological notes:
#'   Session state and result provenance answer different questions. This
#'   function records whether the fast route is available and why. [ra_prov()]
#'   records the guarantee carried by one returned interval, so an interval
#'   escalated after degradation carries `theorem` without changing its class.
#'
#' @section Dependencies:
#'   Base R. The first-use audit requires `Rmpfr`; reading the status does not.
#'
#' @references
#'   Fousse, L., Hanrot, G., Lefevre, V., Pelissier, P., & Zimmermann, P. (2007).
#'   MPFR: A multiple-precision binary floating-point library with correct
#'   rounding. *ACM Transactions on Mathematical Software, 33*(2), Article 13.
#'   https://doi.org/10.1145/1236463.1236468
#'
#' @examples
#' status <- ra_fast_level_status()
#' status$degraded
#' all(status$sentinels$ok)
#'
#' @seealso [ra_check_sentinels()], [ra_measure_library_error()] and
#'   [ra_prov()].
#' @md
#' @export
ra_fast_level_status <- function() {
  degraded <- isTRUE(.ra_state$fast_degraded)
  list(
    degraded = degraded,
    reason = if (degraded) .ra_degradation_reason() else character(0),
    sentinels = .ra_state$sentinel_check,
    audit = .ra_state$fast_audit
  )
}

## Gate passed by every requested fast-level evaluation. The audit flag is set
## before measurement so that the measurement cannot re-enter the audit.
.ra_fast_gate <- function(fun) {
  if (!isTRUE(.ra_state$fast_degraded) &&
      !isTRUE(.ra_state$fast_audited) && ra_has_mpfr()) {
    assign("fast_audited", TRUE, envir = .ra_state)
    measurement <- ra_measure_library_error(n = 400L)
    assign("fast_audit", measurement, envir = .ra_state)
    above <- !is.na(measurement$observed) &
      measurement$observed > measurement$slack
    if (any(above)) {
      assign("fast_degraded", TRUE, envir = .ra_state)
    }
  }

  if (!isTRUE(.ra_state$fast_degraded)) return("fast")

  reason <- .ra_degradation_reason()
  if (ra_has_mpfr()) {
    if (!isTRUE(.ra_state$fast_warning_emitted)) {
      assign("fast_warning_emitted", TRUE, envir = .ra_state)
      ra_warn(
        "fast_level_unsafe",
        paste0(
          "The fast level is degraded for this session (", reason,
          "). This result escalates to the rigorous level, remains a theorem, ",
          "and later results in this session will not repeat this warning."
        )
      )
    }
    return("rigorous")
  }

  ra_stop(
    "fast_level_unsafe",
    paste0(
      "The fast level is degraded for this session (", reason,
      ") and package 'Rmpfr' is not installed, so there is no rigorous level ",
      "to use instead. No enclosure is returned."
    )
  )
}

.ra_degradation_reason <- function() {
  sentinel_check <- .ra_state$sentinel_check
  audit <- .ra_state$fast_audit
  reasons <- character(0)

  if (is.null(sentinel_check)) {
    reasons <- c(reasons, "the load-time sentinel verification could not run")
  } else if (any(!sentinel_check$ok)) {
    failed <- unique(sentinel_check$fun[!sentinel_check$ok])
    reasons <- c(
      reasons,
      paste0("the load-time sentinel verification disagreed bit for bit for ",
             paste(failed, collapse = ", "))
    )
  }

  if (!is.null(audit)) {
    above <- !is.na(audit$observed) & audit$observed > audit$slack
    if (any(above)) {
      reasons <- c(
        reasons,
        paste0("the session audit measured the included evaluator above its ",
               "slack for ", paste(unique(audit$fun[above]), collapse = ", "))
      )
    }
  }

  if (!length(reasons)) reasons <- "degraded by request"
  paste(reasons, collapse = "; ")
}

#' @title The provenance of an interval's guarantee
#' @description Returns, for each element, whether its enclosure is
#'   guaranteed by theorem or by a measured convention, which is the word the
#'   fast level carries.
#' @param x An object of class \code{ra_ivl}.
#' @return A character vector, one of \code{"theorem"} or \code{"measured"}
#'   per element.
#' @details Exact endpoints and everything the kernel derives from them by
#'   outward rounding are theorems; so is the rigorous level, whose backend
#'   rounds correctly by contract. The fast level is a measured convention: a
#'   declared slack over an error measured on the route in use. Mixture
#'   propagates the weaker word, and the printed form of an interval repeats
#'   it, so a reader cannot mistake a convention for a theorem.
#' @section Methodological notes:
#'   An object missing the field, which can only come from code written
#'   before this safeguard, reports the weaker word. Defaulting to the
#'   stronger one would turn a forgotten assignment into an overclaim, which
#'   is the exact failure mode this field exists to prevent.
#' @section Dependencies:
#'   Base R.
#' @references
#'   Rump, S. M. (2010). Verification methods: Rigorous results using
#'   floating-point arithmetic. Acta Numerica, 19, 287-449.
#'   https://doi.org/10.1017/S096249291000005X
#' @examples
#' ra_prov(ra_interval(1, 2))
#' ra_prov(ra_elem("exp", ra_interval(0, 1)))
#' @seealso [ra_elem()] for the two levels, [ra_interval()].
#' @export
ra_prov <- function(x) {
  if (!inherits(x, "ra_ivl")) {
    ra_stop("bad_argument", "Expected an ra_ivl.")
  }
  p <- x$prov
  if (is.null(p)) rep("measured", length(x$lo)) else p
}

## The elementwise weaker of provenance words. Arguments are character
## vectors already recycled by the caller.
.ra_prov2 <- function(a, b) {
  ifelse(a == "measured" | b == "measured", "measured", "theorem")
}
