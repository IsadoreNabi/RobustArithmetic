## The safeguards of the fast level.
##
## The fast level rests on a declared slack over a measured error, and the
## threat that measurement leaves open is exact: an insufficient slack would
## produce an invalid enclosure indistinguishable from a valid one at run
## time. Nothing printed would show it. This file turns that invisible
## failure mode into a trip wire that is tested on this machine, on the
## evaluation route in use, at every load of the package.
##
## Four safeguards live here; the fifth is the pair of tests that prove the
## trip wire can trip. Load sentinels: the published worst-case inputs of the
## system library plus the points where the evaluation route of R was measured
## to differ from it, each stored with its correctly rounded value bracketed
## by two doubles computed in multiprecision and verified by a second,
## independent way. Session audit: with the backend present, the first fast
## evaluation of a session measures the route against it and caches the
## verdict. Provenance: every interval says whether its guarantee is a
## theorem or a measured convention, the weaker word wins on mixture, and the
## printed form repeats it. Environment anchor: the sentinels say what they
## were generated against, and a mismatch is named rather than discovered.

## The mutable state of the loaded namespace. Created here, filled by
## .onLoad(); nothing in this file runs at load time beyond this constructor,
## because top-level code cannot assume the reading order of the sources.
.ra_state <- new.env(parent = emptyenv())

#' @title The load sentinels of the fast level
#' @description Returns the table of sentinel points against which the fast
#'   level is checked at every load: for each admitted function, the input
#'   with the largest known error of the system library, and, where the
#'   evaluation route of R was measured to differ from that library, the
#'   point of the discrepancy.
#' @return A data frame with one row per sentinel and columns \code{fun},
#'   \code{x}, \code{dn}, \code{up}, \code{role} and \code{slack}. \code{dn}
#'   and \code{up} are the two doubles that bracket the correctly rounded
#'   value of the function at \code{x}.
#' @details The worst-case inputs are the published ones for the library this
#'   package was anchored against; the report they come from is named in the
#'   references, and the exact table and column are recorded in the generator
#'   script \code{dev/gen_sentinels.R}, which also verifies every bracketing
#'   pair at two unrelated precisions and, where a series is cheap, against a
#'   series. The discrepancy points are the ones measured in this project:
#'   at them, the route R uses does not return the correctly rounded value
#'   the library returns when called from compiled C code.
#' @section Methodological notes:
#'   A sentinel is only as good as the independence of its stored value. The
#'   bracketing pairs are computed by the multiprecision backend at 500 bits,
#'   re-verified at 800, and stored as data, so the check at load time makes
#'   no call to the backend and costs microseconds. Regenerating them is a
#'   deliberate act with its script, never a side effect.
#' @section Dependencies:
#'   Base R. The generator script needs 'Rmpfr', but its product is data.
#' @references
#'   Gladman, B., Innocente, V., Mather, J., Ozaki, K., & Zimmermann, P. (2026).
#'   Accuracy of mathematical functions in single, double, double extended, and
#'   quadruple precision (edition of February 2026) [Technical report].
#'   https://members.loria.fr/PZimmermann/papers/accuracy.pdf
#' @examples
#' head(ra_sentinels())
#' @seealso [ra_check_sentinels()] for the check the table feeds,
#'   [ra_environment_anchor()] for what it was generated against.
#' @export
ra_sentinels <- function() {
  .ra_sentinels
}

#' @title Check the evaluation route in use against the sentinels
#' @description Evaluates every admitted function on its sentinel points by
#'   the same route the fast level uses, counts the outward rounding steps
#'   needed for the enclosure to contain the correctly rounded value, and
#'   compares that count against the declared slack.
#' @param slack An optional integer vector recycled over the rows, replacing
#'   the declared slack for the comparison. The check itself does not change:
#'   this is the handle by which the tests prove the check can fail, and it
#'   exists because a watchman that cannot fail for the thing it watches is
#'   not a watchman.
#' @return A data frame with columns \code{fun}, \code{x}, \code{role},
#'   \code{steps_needed}, \code{slack} and \code{ok}. \code{steps_needed} is
#'   \code{NA} when even a generous search bound did not suffice, which is
#'   itself a failure.
#' @details The evaluation is one ordinary vectorized call per function, the
#'   same shape the fast level uses, so the check exercises the route in use
#'   rather than a look-alike. A row fails when the steps needed exceed the
#'   slack; any failing row degrades the fast level for the session, and the
#'   degradation speaks through \code{ra_fast_level_unsafe} rather than
#'   through a wrong enclosure.
#' @section Methodological notes:
#'   The check runs at every load rather than once at installation, because
#'   the thing it watches is the pairing of this package with the mathematics
#'   of the running process, and that pairing changes with library upgrades
#'   that never notify the package.
#' @section Dependencies:
#'   Base R.
#' @references
#'   Gladman, B., Innocente, V., Mather, J., Ozaki, K., & Zimmermann, P. (2026).
#'   Accuracy of mathematical functions in single, double, double extended, and
#'   quadruple precision (edition of February 2026) [Technical report].
#'   https://members.loria.fr/PZimmermann/papers/accuracy.pdf
#' @examples
#' chk <- ra_check_sentinels()
#' all(chk$ok)
#' @seealso [ra_sentinels()] for the table, [ra_environment_anchor()] for the
#'   named anchor a failure is explained against.
#' @export
ra_check_sentinels <- function(slack = NULL) {
  s <- .ra_sentinels
  need <- rep(NA_integer_, nrow(s))
  bound <- max(s$slack) + 2L
  for (f in unique(s$fun)) {
    i <- which(s$fun == f)
    y <- do.call(f, list(s$x[i]))
    for (j in seq_along(i)) {
      lo <- y[j]
      hi <- y[j]
      for (k in 0:bound) {
        if (lo <= s$dn[i[j]] && hi >= s$up[i[j]]) {
          need[i[j]] <- k
          break
        }
        lo <- ra_pred(lo)
        hi <- ra_succ(hi)
      }
    }
  }
  sl <- if (is.null(slack)) s$slack else rep_len(as.integer(slack), nrow(s))
  data.frame(fun = s$fun, x = s$x, role = s$role, steps_needed = need,
             slack = sl, ok = !is.na(need) & need <= sl,
             stringsAsFactors = FALSE)
}

#' @title The environment anchor of the sentinels
#' @description Returns what the sentinel table was generated against and the
#'   comparison of the running environment with it, so that a sentinel
#'   failure can be explained rather than merely reported.
#' @return A list with two fields: \code{anchor}, the stored description
#'   (C library version, R version, byte-code compilation level, platform
#'   identifier, backend version, generation date and source of the worst-case
#'   inputs),
#'   and \code{mismatch}, a character vector naming each comparable field that
#'   differs or cannot be identified, empty only when every compared field
#'   matches.
#' @details The comparison covers \code{r_version}, \code{jit_level},
#'   \code{libm} and \code{platform}. The platform is the identifier reported
#'   by \code{R.version$platform}. An unavailable C library or platform
#'   identifier, in either the running environment or the stored anchor, is
#'   itself a mismatch: lack of evidence cannot establish that the running
#'   environment is the generator. The anchor explains; it does not guard. The
#'   guard is the sentinel check itself, which measures the route rather than
#'   trusting any version string.
#' @section Methodological notes:
#'   A version string equal to the anchor does not prove the route is the
#'   anchored one, and a different string does not prove it is not; this is
#'   why the anchor is reported alongside the check instead of replacing it.
#' @section Dependencies:
#'   Base R. Reading the C library version uses \code{getconf} where it
#'   exists; a missing or unusable response is reported as a mismatch.
#' @references
#'   Gladman, B., Innocente, V., Mather, J., Ozaki, K., & Zimmermann, P. (2026).
#'   Accuracy of mathematical functions in single, double, double extended, and
#'   quadruple precision (edition of February 2026) [Technical report].
#'   https://members.loria.fr/PZimmermann/papers/accuracy.pdf
#' @examples
#' ra_environment_anchor()
#' @seealso [ra_check_sentinels()], [ra_sentinels()].
#' @export
ra_environment_anchor <- function() {
  list(anchor = .ra_anchor, mismatch = .ra_compare_anchor(.ra_anchor))
}

## Compare the running environment against an anchor, naming what differs.
## Split from the public function so the tests can hand it a doctored anchor
## and prove the comparator can fail for what it watches.
.ra_compare_anchor <- function(anchor) {
  out <- character(0)
  rv <- paste(R.version$major, R.version$minor, sep = ".")
  if (!identical(rv, anchor$r_version)) {
    out <- c(out, paste0("r_version is '", rv, "' and the sentinels were ",
                         "generated on '", anchor$r_version, "'"))
  }
  jit <- compiler::enableJIT(-1L)
  if (!identical(jit, anchor$jit_level)) {
    out <- c(out, paste0("jit_level is ", jit,
                         " and the sentinels were generated at ",
                         anchor$jit_level))
  }
  libm <- tryCatch(
    suppressWarnings(system2("getconf", "GNU_LIBC_VERSION", stdout = TRUE,
                             stderr = FALSE)[1L]),
    error = function(e) NA_character_)
  libm_known <- is.character(libm) && length(libm) == 1L &&
    !is.na(libm) && nzchar(libm)
  anchor_libm_known <- is.character(anchor$libm) &&
    length(anchor$libm) == 1L && !is.na(anchor$libm) && nzchar(anchor$libm)
  if (!libm_known) {
    out <- c(out, "libm could not be identified in the running environment")
  } else if (!anchor_libm_known) {
    out <- c(out, "libm could not be identified in the sentinel anchor")
  } else if (!identical(libm, anchor$libm)) {
    out <- c(out, paste0("libm reports '", libm,
                         "' and the sentinels were generated against '",
                         anchor$libm, "'"))
  }
  platform <- R.version$platform
  platform_known <- is.character(platform) &&
    length(platform) == 1L && !is.na(platform) &&
    nzchar(platform)
  anchor_platform_known <- is.character(anchor$platform) &&
    length(anchor$platform) == 1L && !is.na(anchor$platform) &&
    nzchar(anchor$platform)
  if (!platform_known) {
    out <- c(out, paste0("platform could not be identified in the running ",
                         "environment"))
  } else if (!anchor_platform_known) {
    out <- c(out, "platform could not be identified in the sentinel anchor")
  } else if (!identical(platform, anchor$platform)) {
    out <- c(out, paste0("platform is '", platform,
                         "' and the sentinels were generated on '",
                         anchor$platform, "'"))
  }
  out
}

## The gate every fast-level evaluation passes. Returns the level to use.
## When the fast level is degraded it escalates to the rigorous level with a
## warning if the backend is there, and raises if it is not: a word, never
## silence. With the backend present, the first fast use of the session also
## audits the route against the declared slack and applies the same
## degradation if the audit fails.
.ra_fast_gate <- function(fun) {
  if (!isTRUE(.ra_state$fast_degraded) && !isTRUE(.ra_state$fast_audited) &&
      ra_has_mpfr()) {
    ## the flag goes up before measuring so the measurement cannot re-enter
    assign("fast_audited", TRUE, envir = .ra_state)
    m <- ra_measure_library_error(n = 400L)
    assign("fast_audit", m, envir = .ra_state)
    if (any(!is.na(m$observed) & m$observed > m$slack)) {
      assign("fast_degraded", TRUE, envir = .ra_state)
    }
  }
  if (!isTRUE(.ra_state$fast_degraded)) return("fast")
  why <- .ra_degradation_reason()
  if (ra_has_mpfr()) {
    ra_warn("fast_level_unsafe",
            paste0("The fast level is degraded for this session (", why,
                   "). `", fun, "` escalates to the rigorous level ",
                   "(the declared fallback), which is slower ",
                   "and remains a theorem."))
    return("rigorous")
  }
  ra_stop("fast_level_unsafe",
          paste0("The fast level is degraded for this session (", why,
                 ") and package 'Rmpfr' is not installed, so there is no ",
                 "rigorous level to escalate to. No enclosure is returned: ",
                 "a wrong one would be indistinguishable from a right one."))
}

## One sentence naming why the fast level is degraded, with the environment
## anchor appended when it differs: the anchor explains, the check guards.
.ra_degradation_reason <- function() {
  chk <- .ra_state$sentinel_check
  aud <- .ra_state$fast_audit
  parts <- character(0)
  if (is.null(chk)) {
    parts <- c(parts, "the load-time sentinel check could not run")
  } else if (any(!chk$ok)) {
    bad <- chk[!chk$ok, , drop = FALSE]
    parts <- c(parts, paste0("sentinel check failed for ",
                             paste(unique(bad$fun), collapse = ", ")))
  }
  if (!is.null(aud) && any(!is.na(aud$observed) & aud$observed > aud$slack)) {
    bad <- aud[!is.na(aud$observed) & aud$observed > aud$slack, , drop = FALSE]
    parts <- c(parts, paste0("session audit measured the route above its ",
                             "slack for ",
                             paste(unique(bad$fun), collapse = ", ")))
  }
  if (!length(parts)) parts <- "degraded by request"
  mm <- .ra_state$anchor_mismatch
  if (length(mm)) {
    parts <- c(parts, paste0("note that the environment differs from the ",
                             "sentinel anchor: ",
                             paste(mm, collapse = "; ")))
  }
  paste(parts, collapse = "; ")
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
