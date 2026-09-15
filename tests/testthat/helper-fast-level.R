## Keep tests of fast-level logic independent of the ambient math library.
## The load check and the first-use audit are separate degradation routes, so
## both are held open here and the complete session state is restored on exit.
hold_fast_level_open <- function() {
  old <- list(
    fast_degraded = .ra_state$fast_degraded,
    fast_audited = .ra_state$fast_audited,
    fast_audit = .ra_state$fast_audit,
    fast_warning_emitted = .ra_state$fast_warning_emitted
  )

  assign("fast_degraded", FALSE, envir = .ra_state)
  assign("fast_audited", TRUE, envir = .ra_state)
  assign("fast_audit", NULL, envir = .ra_state)
  assign("fast_warning_emitted", FALSE, envir = .ra_state)

  function() {
    assign("fast_degraded", old$fast_degraded, envir = .ra_state)
    assign("fast_audited", old$fast_audited, envir = .ra_state)
    assign("fast_audit", old$fast_audit, envir = .ra_state)
    assign("fast_warning_emitted", old$fast_warning_emitted,
           envir = .ra_state)
    invisible()
  }
}

preserve_fast_level_state <- function() {
  old <- as.list(.ra_state, all.names = TRUE)

  function() {
    bindings <- ls(.ra_state, all.names = TRUE)
    if (length(bindings)) rm(list = bindings, envir = .ra_state)
    list2env(old, envir = .ra_state)
    invisible()
  }
}
