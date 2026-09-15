## Exercise the installed package after hook_scenario.R selected the evaluator.
attach_package <- identical(Sys.getenv("RA_SCENARIO_ATTACH"), "yes")
library_directory <- Sys.getenv("RA_SCENARIO_LIBRARY")
.libPaths(c(library_directory, .libPaths()))

startup <- character(0)
if (attach_package) {
  withCallingHandlers(
    library(RobustArithmetic, lib.loc = library_directory),
    packageStartupMessage = function(message) {
      startup <<- c(startup, conditionMessage(message))
      invokeRestart("muffleMessage")
    }
  )
} else {
  loadNamespace("RobustArithmetic", lib.loc = library_directory)
}

namespace <- asNamespace("RobustArithmetic")
exports <- getNamespaceExports(namespace)
status <- RobustArithmetic::ra_fast_level_status()
reason <- paste(status$reason, collapse = " ")
sin_bad <- is.data.frame(status$sentinels) &&
  any(status$sentinels$fun == "sin" & !status$sentinels$ok)

warnings <- 0L
warning_class <- 0L
errors <- 0L
error_class <- 0L
provenance <- character(0)
functions <- RobustArithmetic::ra_operator_table("functions")$fun
for (function_name in functions) {
  result <- withCallingHandlers(
    tryCatch(
      RobustArithmetic::ra_elem(
        function_name, RobustArithmetic::ra_interval(0.2, 0.3)
      ),
      error = function(error) {
        errors <<- errors + 1L
        if (inherits(error, "ra_fast_level_unsafe")) {
          error_class <<- error_class + 1L
        }
        NULL
      }
    ),
    warning = function(warning) {
      warnings <<- warnings + 1L
      if (inherits(warning, "ra_fast_level_unsafe")) {
        warning_class <<- warning_class + 1L
      }
      invokeRestart("muffleWarning")
    }
  )
  if (!is.null(result)) {
    provenance <- c(provenance, RobustArithmetic::ra_prov(result))
  }
}

cat(sprintf(
  paste0(
    "PROBE startup=%d startup_degraded=%s degraded=%s reason_sin=%s ",
    "sentinel_sin_bad=%s warnings=%d warnings_of_class=%d errors=%d ",
    "errors_of_class=%d prov=%s exports=%d anchor_exported=%s ",
    "status_exported=%s rmpfr=%s\n"
  ),
  length(startup),
  any(grepl("degrad", startup, ignore.case = TRUE)),
  isTRUE(status$degraded),
  grepl("\\bsin\\b", reason),
  sin_bad,
  warnings,
  warning_class,
  errors,
  error_class,
  if (length(provenance)) paste(sort(unique(provenance)), collapse = "+") else "none",
  length(exports),
  "ra_environment_anchor" %in% exports,
  "ra_fast_level_status" %in% exports,
  requireNamespace("Rmpfr", quietly = TRUE)
))
