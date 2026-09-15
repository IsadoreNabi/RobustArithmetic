## Emulate a healthy, load-degraded or broken included evaluator in a fresh
## process. The hook runs immediately after the namespace's ordinary .onLoad.
## A perturbed scenario changes only sine, then invokes .onLoad again so the
## production self-verification, state reset and startup path are exercised.
## The load-degraded scenario restores the correct evaluator after that check;
## the broken scenario leaves the perturbation in place.
local({
  scenario <- Sys.getenv("RA_SCENARIO", "healthy")
  if (!scenario %in% c("healthy", "loaddeg", "broken")) {
    stop("unknown RA_SCENARIO: ", scenario)
  }
  if (identical(scenario, "healthy")) return(invisible())

  setHook(packageEvent("RobustArithmetic", "onLoad"), function(pkgname, pkgpath) {
    namespace <- asNamespace("RobustArithmetic")
    evaluator <- get(".ra_cr", envir = namespace)
    successor <- get("ra_succ", envir = namespace)
    broken <- function(fun, x) {
      value <- evaluator(fun, x)
      if (identical(fun, "sin")) {
        finite <- is.finite(value)
        value[finite] <- successor(value[finite])
      }
      value
    }
    unlockBinding(".ra_cr", namespace)
    assign(".ra_cr", broken, envir = namespace)
    lockBinding(".ra_cr", namespace)
    get(".onLoad", envir = namespace)(dirname(pkgpath), pkgname)
    if (identical(scenario, "loaddeg")) {
      unlockBinding(".ra_cr", namespace)
      assign(".ra_cr", evaluator, envir = namespace)
      lockBinding(".ra_cr", namespace)
    }
  })
})
