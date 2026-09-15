## Load-time wiring. This file sorts last on purpose and holds the only code
## the package runs at load: a bitwise verification of the included evaluator
## against independent sentinels. .onLoad() clears the complete session state
## first, so invoking it again performs the same verification from scratch.

.onLoad <- function(libname, pkgname) {
  bindings <- ls(.ra_state, all.names = TRUE)
  if (length(bindings)) rm(list = bindings, envir = .ra_state)
  chk <- tryCatch(ra_check_sentinels(), error = function(e) NULL)
  assign("sentinel_check", chk, envir = .ra_state)
  assign("fast_degraded", is.null(chk) || any(!chk$ok), envir = .ra_state)
  assign("fast_audited", FALSE, envir = .ra_state)
  assign("fast_audit", NULL, envir = .ra_state)
  assign("fast_warning_emitted", FALSE, envir = .ra_state)
  invisible()
}

.onAttach <- function(libname, pkgname) {
  if (isTRUE(.ra_state$fast_degraded)) {
    packageStartupMessage("RobustArithmetic: the fast level is DEGRADED (",
                          .ra_degradation_reason(), ").")
  }
  invisible()
}
