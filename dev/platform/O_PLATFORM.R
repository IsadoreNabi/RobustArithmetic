## Oracle O_PLATFORM: on a real platform, a healthy installation of the package
## is silent and not degraded, and its sentinels pass. Complements O_CR_RMPFR.R,
## which checks correct rounding on the same machine.
##
## Claims, in a fresh process:
##   - library(RobustArithmetic) emits no startup message;
##   - ra_fast_level_status() reports not degraded;
##   - ra_check_sentinels() reports every row ok;
##   - 1000 fast evaluations of sin, attached, emit no warning and no error;
##   - ra_environment_anchor is not exported and ra_fast_level_status is.
## Usage: Rscript O_PLATFORM.R [library dir]
args <- commandArgs(TRUE)
lib <- if (length(args) >= 1 && nzchar(args[1])) args[1] else NULL
if (!is.null(lib)) .libPaths(c(lib, .libPaths()))
startup <- character(0)
withCallingHandlers(library(RobustArithmetic),
  packageStartupMessage = function(m) {
    startup <<- c(startup, conditionMessage(m)); invokeRestart("muffleMessage")
  })
ns <- asNamespace("RobustArithmetic")
ex <- getNamespaceExports(ns)
cat("O_PLATFORM package", as.character(packageVersion("RobustArithmetic")), "R",
    R.version$platform, R.version.string, "rmpfr", requireNamespace("Rmpfr", quietly = TRUE), "\n")
bad <- 0L
chk <- function(name, cond, detail = "") {
  cond <- isTRUE(cond)
  cat(sprintf("PLATFORM %-52s %s %s\n", name, if (cond) "ok" else "BAD", detail))
  if (!cond) bad <<- bad + 1L
}
chk("no startup message", length(startup) == 0L, paste(startup, collapse = " | "))
chk("ra_environment_anchor not exported", !"ra_environment_anchor" %in% ex)
chk("ra_fast_level_status exported", "ra_fast_level_status" %in% ex)
st <- tryCatch(ra_fast_level_status(), error = function(e) e)
chk("status reports not degraded", !inherits(st, "error") && identical(st$degraded, FALSE),
    if (inherits(st, "error")) conditionMessage(st) else paste(st$reason, collapse = " "))
sc <- tryCatch(ra_check_sentinels(), error = function(e) e)
funs <- c("exp", "log", "sin", "cos", "tan", "sinh", "cosh", "tanh", "sqrt",
          "expm1", "log1p", "log2", "log10", "asin", "acos", "atan")
is_tab <- is.data.frame(sc) && all(c("fun", "ok") %in% names(sc))
per_fun <- if (is_tab) table(factor(sc$fun, levels = funs), useNA = "ifany") else integer(0)
chk("sentinel table has 128 rows, eight per function",
    is_tab && nrow(sc) == 128L && length(per_fun) == 16L && all(per_fun == 8L),
    if (is_tab) paste("rows", nrow(sc)) else "no table")
chk("sentinels all ok", is_tab && nrow(sc) == 128L && is.logical(sc$ok) && !anyNA(sc$ok) && all(sc$ok),
    if (is_tab) paste(unique(sc$fun[!sc$ok %in% TRUE]), collapse = ",") else "no table")
nw <- 0L; ne <- 0L
for (i in 1:1000) {
  withCallingHandlers(
    tryCatch(ra_elem("sin", ra_interval(i / 1000, i / 1000 + 1e-3)), error = function(e) ne <<- ne + 1L),
    warning = function(w) { nw <<- nw + 1L; invokeRestart("muffleWarning") })
}
chk("1000 fast evaluations: no warning", nw == 0L, paste("warnings", nw))
chk("1000 fast evaluations: no error", ne == 0L, paste("errors", ne))
cat(if (bad == 0L) "O_PLATFORM PASS\n" else sprintf("O_PLATFORM FAIL bad=%d\n", bad))
quit(status = if (bad == 0L) 0L else 1L)
