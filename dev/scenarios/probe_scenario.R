## Prove that the selected scenario reached the installed package.
suppressPackageStartupMessages(library(RobustArithmetic))
namespace <- asNamespace("RobustArithmetic")
state <- get(".ra_state", envir = namespace)
result <- tryCatch(
  withCallingHandlers(
    ra_solve(quote(sin(x) - 0.5), ra_interval(0, 1)),
    warning = function(warning) invokeRestart("muffleWarning")
  ),
  error = function(error) error
)
cat(sprintf(
  paste0("PROBE version=%s lib=%s has_mpfr=%s degraded=%s ",
         "mismatch=%d solve=%s\n"),
  as.character(packageVersion("RobustArithmetic")),
  dirname(getNamespaceInfo(namespace, "path")),
  get("ra_has_mpfr", envir = namespace)(),
  isTRUE(state$fast_degraded),
  length(state$anchor_mismatch),
  if (inherits(result, "error")) "refused" else "returned"
))
