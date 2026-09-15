## Emulate the environments that guard the fast level during scenario checks.
## This hook runs after the package namespace finishes loading and before it is
## attached, so startup messages, tests and probes see the same state.
local({
  scenario <- Sys.getenv("RA_SCENARIO", "home")
  known <- c("home", "anchor", "windows", "load_degraded")
  if (!scenario %in% known) stop("unknown RA_SCENARIO: ", scenario)

  setHook(packageEvent("RobustArithmetic", "onLoad"), function(pkgname, pkgpath) {
    namespace <- asNamespace("RobustArithmetic")
    state <- get(".ra_state", envir = namespace)
    windows_mismatch <- c(
      "r_version is '4.7.0' and the sentinels were generated on '4.6.1'",
      "libm could not be identified in the running environment",
      paste0("platform is 'x86_64-w64-mingw32' and the sentinels were ",
             "generated on 'x86_64-redhat-linux-gnu'")
    )

    if (scenario != "home") {
      assign("anchor_mismatch", windows_mismatch, envir = state)
    }
    if (scenario == "windows") {
      real_measurement <- get("ra_measure_library_error", envir = namespace)
      emulated_measurement <- function(n = 20000L, seed = NULL, bits = 300L) {
        measurement <- real_measurement(n = n, seed = seed, bits = bits)
        selected <- measurement$fun %in% c("sin", "cos")
        measurement$observed[selected] <- measurement$slack[selected] + 1
        measurement$used[selected] <-
          measurement$observed[selected] / measurement$slack[selected]
        measurement
      }
      stopifnot(identical(names(formals(emulated_measurement)),
                          names(formals(real_measurement))))
      unlockBinding("ra_measure_library_error", namespace)
      assign("ra_measure_library_error", emulated_measurement,
             envir = namespace)
      lockBinding("ra_measure_library_error", namespace)
    }
    if (scenario == "load_degraded") {
      check <- state$sentinel_check
      stopifnot(is.data.frame(check),
                any(check$fun %in% c("sin", "cos")))
      check$ok[check$fun %in% c("sin", "cos")] <- FALSE
      assign("sentinel_check", check, envir = state)
      assign("fast_degraded", TRUE, envir = state)
    }
  })
})
