## Keep tests of fast-level logic independent of the ambient math library.
## The load check and the first-use audit are separate degradation routes, so
## both are held open here and the complete session state is restored on exit.
hold_fast_level_open <- function() {
  old <- list(
    fast_degraded = .ra_state$fast_degraded,
    fast_audited = .ra_state$fast_audited,
    fast_audit = .ra_state$fast_audit
  )

  assign("fast_degraded", FALSE, envir = .ra_state)
  assign("fast_audited", TRUE, envir = .ra_state)
  assign("fast_audit", NULL, envir = .ra_state)

  function() {
    assign("fast_degraded", old$fast_degraded, envir = .ra_state)
    assign("fast_audited", old$fast_audited, envir = .ra_state)
    assign("fast_audit", old$fast_audit, envir = .ra_state)
    invisible()
  }
}
