## Load-time wiring. This file sorts last on purpose and holds the only code
## the package runs at load: the sentinel check of the fast level and the
## comparison against the environment anchor. Both fill .ra_state; neither
## prints. What there is to say is said by .onAttach, once, to a person.

.onLoad <- function(libname, pkgname) {
  chk <- tryCatch(ra_check_sentinels(), error = function(e) NULL)
  assign("sentinel_check", chk, envir = .ra_state)
  assign("fast_degraded", is.null(chk) || any(!chk$ok), envir = .ra_state)
  assign("fast_audited", FALSE, envir = .ra_state)
  assign("fast_audit", NULL, envir = .ra_state)
  mm <- tryCatch(.ra_compare_anchor(.ra_anchor),
                 error = function(e) character(0))
  assign("anchor_mismatch", mm, envir = .ra_state)
  invisible()
}

.onAttach <- function(libname, pkgname) {
  if (isTRUE(.ra_state$fast_degraded)) {
    packageStartupMessage("RobustArithmetic: the fast level is DEGRADED (",
                          .ra_degradation_reason(), ").")
  } else if (length(.ra_state$anchor_mismatch)) {
    packageStartupMessage("RobustArithmetic: the sentinel anchor is from a ",
                          "different environment (",
                          paste(.ra_state$anchor_mismatch, collapse = "; "),
                          "); the load-time check still passed on the route ",
                          "in use.")
  }
  invisible()
}
