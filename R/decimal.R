## ---------------------------------------------------------------------------
## Decimal rendering that cannot assert what is false.
##
## A printed number makes one of two different claims, and the two need
## opposite treatments. Either it BOUNDS an unknown real -- an endpoint, a
## width, an error bound -- and then it must be rounded in the direction that
## keeps the sentence true, however many digits that takes; or it IDENTIFIES
## the datum a computation ran on -- the radius of the ball that was certified
## -- and then it must be reproducible, that is, it must read back to the very
## same binary64 number. Rounding to nearest serves neither, and rounding to
## nearest is what every default in R does.
##
## Subclause 6.8.3 of IEEE Std 1788.1-2017 asks of intervalToText that the
## string contain the interval, and 6.6.2 fixes what the string means: the
## value of the literal [l, u] is the MATHEMATICAL interval [l, u], that is,
## the decimals read exactly, not the doubles they happen to round to. That is
## the criterion used throughout this file. It is stricter than "the string
## reads back to the same double": the shortest such string for the double
## 0.1 + 5e-17 is 0.10000000000000006, whose exact value is BELOW the
## endpoint, so it fails 6.8.3 while looking like it passes.
## ---------------------------------------------------------------------------

## The exact product of two doubles as an unevaluated sum hi + lo, by Dekker's
## splitting. No fused multiply-add is assumed, because R gives no access to
## one. Valid while nothing overflows, which the callers check.
.ra_two_prod <- function(a, b) {
  x <- a * b
  ca <- 134217729 * a                   # 2^27 + 1
  ahi <- ca - (ca - a)
  alo <- a - ahi
  cb <- 134217729 * b
  bhi <- cb - (cb - b)
  blo <- b - bhi
  err <- ((ahi * bhi - x) + ahi * blo + alo * bhi) + alo * blo
  list(hi = x, lo = err)
}

## The sign of (the exact value of the decimal +-D * 10^p) minus v, or NA when
## the question was not decided. NA is never resolved by assuming: every caller
## answers it by moving a digit outward, which is always safe.
##
## The comparison is certified wherever it answers. The decimal significand is
## carried as an exact sum of two doubles (.ra_int_dd), the scaling by a power
## of ten is carried out in stages with a derived error bound (.ra_scale10),
## and the answer is given only where the difference exceeds that bound. What
## is not certified is declined, and declining costs one unit in the last
## printed place.
.ra_cmp_dec <- function(D, p, neg, v) {
  if (!is.finite(v) || v == 0) return(NA_integer_)
  ds <- .ra_int_dd(D)
  if (is.null(ds)) return(NA_integer_)
  Dhi <- ds$hi; Dlo <- ds$lo
  if (neg) { Dhi <- -Dhi; Dlo <- -Dlo }
  if (p >= 0L) {
    ## near the top of the range the product would overflow while the
    ## comparison would not, so both sides are divided by a power of two first.
    ## Halving is exact, so this changes nothing but the exponent.
    t <- if (abs(v) > 1e200) 2^-512 else 1
    sc <- .ra_scale10(Dhi * t, Dlo * t, p)
    if (is.null(sc)) return(NA_integer_)
    d <- (sc$hi - v * t) + sc$lo
    scale <- abs(sc$hi)
  } else {
    sc <- .ra_scale10(v, 0, -p)
    if (is.null(sc)) return(NA_integer_)
    d <- ((Dhi - sc$hi) + Dlo) - sc$lo
    scale <- abs(Dhi)
  }
  if (!is.finite(d)) return(NA_integer_)
  ## THE COMPARISON ANSWERS ONLY WHERE IT IS CERTIFIED TO. The scaling carries
  ## a relative error below 2^-101 (see .ra_scale10), so a difference above
  ## 2^-100 of the operands has the sign it computes; anything smaller,
  ## including an exact zero, is declined and resolved by moving a digit. An
  ## exact equality is not decided here at all: it is decided on the grid, by
  ## .ra_on_grid(), where the answer is arithmetic and not a comparison.
  if (abs(d) <= scale * 2^-100) return(NA_integer_)
  if (d > 0) 1L else -1L
}

## (hi + lo) times 10^e, for e >= 0, as a double-double.
##
## Powers of ten are exact doubles only up to 10^22, which is why this walks
## the exponent in stages of at most twenty-two and multiplies by an exact
## factor each time. Per stage the double-double product commits at most
## 2 * 2^-106 of relative error, and there are at most sixteen stages, so the
## total stays below 2^-101; the caller compares against 2^-100 and so never
## reads a sign out of the error term. NULL when anything left the finite
## range, which the caller reads as "not decided".
.ra_scale10 <- function(hi, lo, e) {
  if (e < 0L) return(NULL)
  while (e > 0L) {
    step <- min(22L, e)
    c10 <- 10^step
    tp <- .ra_two_prod(hi, c10)
    s <- tp$lo + lo * c10
    h <- tp$hi + s
    l <- s - (h - tp$hi)
    if (!is.finite(h) || !is.finite(l)) return(NULL)
    hi <- h; lo <- l
    e <- e - step
  }
  list(hi = hi, lo = lo)
}

## The number of fractional bits of a double: the least q with v * 2^q an
## integer. The doubling is exact at every step, because it ends on the
## significand itself, which is below 2^53.
.ra_frac_bits <- function(v) {
  t <- abs(v)
  if (!is.finite(t)) return(NA_integer_)
  q <- 0L
  while (t != floor(t)) {
    t <- t * 2
    q <- q + 1L
    if (q > 1100L) return(NA_integer_)
  }
  q
}

## Does v sit exactly on the decimal grid of step 10^p?
##
## This is the one question whose answer must be exact and cheap, because it is
## what keeps -2.5 printing as -2.5. For p <= 0 it is arithmetic and not a
## comparison: v * 10^-p is an integer if and only if v * 2^-p is, since the
## remaining factor 5^-p is odd, and v * 2^-p is an integer exactly when v has
## no more than -p fractional bits. When v is on the grid, the digits sprintf
## produced at that grid ARE v, whatever its tie-breaking rule, because the
## distance to be rounded is zero.
.ra_on_grid <- function(v, p, q = .ra_frac_bits(v)) {
  if (is.na(q)) return(FALSE)
  if (p <= 0L) return(q <= -p)
  if (q != 0L || p > 22L) return(FALSE)
  w <- v / 10^p
  if (!is.finite(w) || w != floor(w)) return(FALSE)
  tp <- .ra_two_prod(w, 10^p)
  is.finite(tp$hi) && tp$hi == v && tp$lo == 0
}

## A decimal integer of up to eighteen digits as an exact sum of two doubles.
##
## Seventeen digits overflow the fifty-three bits of a double, so the obvious
## as.numeric() loses the last digit or two -- and the last digit is the whole
## question here. The residual is recovered from the decimal side, where it is
## exact: R prints an integer-valued double with %.0f without rounding it,
## because there is nothing to round, so the difference between that print and
## the digits is the error the conversion committed, and it is taken by decimal
## subtraction, which has no error of its own.
.ra_int_dd <- function(D) {
  hi <- suppressWarnings(as.numeric(D))
  if (!is.finite(hi)) return(NULL)
  if (nchar(D) <= 15L) return(list(hi = hi, lo = 0))
  lo <- .ra_dec_sub(D, sprintf("%.0f", hi))
  if (is.null(lo)) return(NULL)
  list(hi = hi, lo = lo)
}

## a - b, for non-negative integer digit strings, as a double. NULL when the
## difference is too large to be a double exactly, which never happens for the
## one caller -- a conversion error is a few units -- and would be a defect
## rather than a case if it did.
.ra_dec_sub <- function(a, b) {
  n <- max(nchar(a), nchar(b))
  ## the padding is written out because formatC(flag = "0") pads a character
  ## vector with spaces and not with zeros, which would put NA in the digits
  da <- as.integer(strsplit(paste0(strrep("0", n - nchar(a)), a), "")[[1L]])
  db <- as.integer(strsplit(paste0(strrep("0", n - nchar(b)), b), "")[[1L]])
  if (anyNA(da) || anyNA(db)) return(NULL)
  sgn <- 1
  cmp <- which(da != db)
  if (!length(cmp)) return(0)
  if (da[cmp[1L]] < db[cmp[1L]]) { tmp <- da; da <- db; db <- tmp; sgn <- -1 }
  r <- integer(n)
  borrow <- 0L
  for (i in n:1L) {
    d <- da[i] - db[i] - borrow
    if (d < 0L) { d <- d + 10L; borrow <- 1L } else borrow <- 0L
    r[i] <- d
  }
  s <- sub("^0+(?=[0-9])", "", paste(r, collapse = ""), perl = TRUE)
  if (nchar(s) > 15L) return(NULL)
  sgn * as.numeric(s)
}

## The significand and the exponent of v at k significant digits, as digits and
## an integer, so that the value is +-D * 10^p. The digits come from sprintf,
## which rounds; nothing downstream trusts the direction of that rounding.
.ra_sci <- function(v, k) {
  s <- sprintf("%.*e", k - 1L, abs(v))
  ## the layout of %e is fixed -- one digit, a point when there is more than
  ## one, then k - 1 digits -- so the exponent starts at a position that is
  ## known and does not have to be searched for. This is called seventeen times
  ## per endpoint printed, which is why it is written with substr and not with
  ## a regular expression.
  i <- if (k == 1L) 2L else k + 2L
  D <- if (k == 1L) substr(s, 1L, 1L) else
    paste0(substr(s, 1L, 1L), substr(s, 3L, i - 1L))
  list(D = D, p = as.integer(substring(s, i + 1L)) - (k - 1L))
}

## One unit in the last digit, added or subtracted on the digit string itself.
## Doing this in decimal rather than in binary is what makes the step exact:
## the string is the number here, and 999 + 1 is 1000 with no rounding to argue
## about.
.ra_digits_bump <- function(D, up) {
  d <- as.integer(strsplit(D, "", fixed = TRUE)[[1L]])
  if (up) {
    i <- length(d)
    repeat {
      if (i == 0L) { d <- c(1L, d); break }
      if (d[i] < 9L) { d[i] <- d[i] + 1L; break }
      d[i] <- 0L
      i <- i - 1L
    }
  } else {
    i <- length(d)
    repeat {
      if (i == 0L) return("0")            # the string was all zeros already
      if (d[i] > 0L) { d[i] <- d[i] - 1L; break }
      d[i] <- 9L
      i <- i - 1L
    }
  }
  paste(d, collapse = "")
}

## The digits placed on the page. Exact: this moves a point and drops zeros
## that carry no value, and never rounds.
.ra_render <- function(neg, D, p) {
  n <- nchar(D)
  ## both strips are guarded by a single-character test, because this is on the
  ## per-digit-count path and neither case is the common one: leading zeros
  ## appear only after a borrow, trailing zeros only when sprintf padded
  if (substr(D, 1L, 1L) == "0") {
    D <- sub("^0+", "", D)
    if (!nzchar(D)) return("0")
    n <- nchar(D)
  }
  if (substr(D, n, n) == "0") {
    nz <- sub("0+$", "", D)
    if (!nzchar(nz)) return("0")
    p <- p + (n - nchar(nz))
    D <- nz
    n <- nchar(D)
  }
  e10 <- n - 1L + p
  if (e10 >= -4L && e10 <= 14L) {
    body <- if (p >= 0L) {
      paste0(D, strrep("0", p))
    } else if (n > -p) {
      paste0(substr(D, 1L, n + p), ".", substring(D, n + p + 1L))
    } else {
      paste0("0.", strrep("0", -p - n), D)
    }
  } else {
    mant <- if (n == 1L) D else paste0(substr(D, 1L, 1L), ".", substring(D, 2L))
    body <- paste0(mant, "e", if (e10 < 0L) "-" else "+", sprintf("%02d", abs(e10)))
  }
  paste0(if (neg) "-" else "", body)
}

## The value of the digits, without laying them out. as.numeric() reads the
## bare scientific form, so no rendering is needed to ask what a candidate is
## worth -- and the search asks that seventeen times for every one it keeps.
.ra_value <- function(neg, D, p) {
  suppressWarnings(as.numeric(paste0(if (neg) "-" else "", D, "e", p)))
}

## Is the decimal +-D * 10^p certified to lie on the required side of v?
##
## Three proofs are admitted and nothing else. The first two need no arithmetic
## beyond what R already guarantees: decimal-to-binary conversion is a rounding
## and therefore monotone, so a converted value strictly below v proves the
## decimal is below v, and one strictly above proves the decimal is above. Only
## when the conversion lands exactly on v is the question open, and then the
## third proof, the exact comparison, decides it. When none of the three
## answers, the caller moves a digit outward. An undecided case is never read
## as a pass.
.ra_safe <- function(D, p, neg, v, up, on_grid) {
  ## the candidate is converted from its raw digits and exponent rather than
  ## from its rendering: the two have the same value, and only the accepted
  ## candidate is worth laying out on a page
  y <- .ra_value(neg, D, p)
  if (is.na(y)) return(FALSE)
  if (up && y > v) return(TRUE)
  if (!up && y < v) return(TRUE)
  if (y != v) return(FALSE)
  ## the conversion landed on v, so the decimal is within half a rounding step
  ## of it and the question is which side. Equality first, because it is the
  ## common case and the only one decided exactly; then the sign.
  if (on_grid) return(TRUE)
  cmp <- .ra_cmp_dec(D, p, neg, v)
  !is.na(cmp) && (if (up) cmp > 0L else cmp < 0L)
}

## The shortest decimal string that is certified to bound v on the given side
## and that stays within one rounding step of it.
##
## The two requirements are of different kinds and are kept apart on purpose.
## Containment is a theorem: the string returned satisfies it by the proof
## above, at every digit count, always. Tightness is a search: among the
## candidates that satisfy it, the first one no looser than [ra_pred(v),
## ra_succ(v)] is taken, so that printing an enclosure never costs more than
## one operation of the arithmetic costs. If the search fails the last
## certified candidate is returned, which is loose but still true; if
## certification itself fails the function stops, because a printed bound that
## was not proved is exactly what this file exists to prevent.
.ra_bound1 <- function(v, up) {
  if (is.nan(v)) return("NaN")
  if (is.na(v)) return(NA_character_)
  if (!is.finite(v)) return(if (v > 0) "Inf" else "-Inf")
  if (v == 0) return("0")
  neg <- v < 0
  target <- if (up) ra_succ(v) else ra_pred(v)
  q <- .ra_frac_bits(v)
  keep <- NULL
  for (k in 1:17) {
    pr <- .ra_sci(v, k)
    D <- pr$D
    ## the grid certificate belongs to the digits sprintf produced, not to the
    ## ones a bump moved away from them
    on_grid <- .ra_on_grid(v, pr$p, q)
    ok <- FALSE
    for (i in 0:20) {
      if (.ra_safe(D, pr$p, neg, v, up, on_grid)) { ok <- TRUE; break }
      D <- .ra_digits_bump(D, xor(up, neg))
      on_grid <- FALSE
    }
    if (!ok) next
    ys <- .ra_value(neg, D, pr$p)
    if (if (up) ys <= target else ys >= target) return(.ra_render(neg, D, pr$p))
    keep <- list(D = D, p = pr$p)
  }
  if (!is.null(keep)) return(.ra_render(neg, keep$D, keep$p))
  ra_stop("internal", paste0(
    "no certified decimal bound could be produced for ", sprintf("%.17g", v),
    ". This is a defect in the package, not in the call: please report it."))
}

## The shortest decimal string that reads back to the identical double. This is
## the other claim -- reproduction of a datum, not a bound on an unknown -- and
## it is the right one only where the number IS the datum.
.ra_exact1 <- function(v) {
  if (is.nan(v)) return("NaN")
  if (is.na(v)) return(NA_character_)
  if (!is.finite(v)) return(if (v > 0) "Inf" else "-Inf")
  if (v == 0) return("0")
  neg <- v < 0
  for (k in 1:17) {
    pr <- .ra_sci(v, k)
    if (.ra_value(neg, pr$D, pr$p) == v) return(.ra_render(neg, pr$D, pr$p))
  }
  sprintf("%.17g", v)
}

## The vector forms. Endpoints repeat far more often than they differ -- a
## window, a constant, a root found twice -- so the work is done once per
## distinct value.
.ra_map_unique <- function(v, f) {
  if (!length(v)) return(character(0))
  u <- unique(v)
  vapply(u, f, character(1L), USE.NAMES = FALSE)[match(v, u)]
}

.ra_bound <- function(v, up) {
  .ra_map_unique(as.numeric(v), function(z) .ra_bound1(z, up))
}

.ra_exact <- function(v) {
  .ra_map_unique(as.numeric(v), .ra_exact1)
}

## The two card helpers, so that a call site says which claim it is making.
.ra_card_up <- function(v) if (is.na(v)) "NA" else .ra_bound1(v, TRUE)
.ra_card_fid <- function(v) if (is.na(v)) "NA" else .ra_exact1(v)

#' @title The text output of the interval standard
#' @description Converts intervals to strings that are valid interval literals
#'   and that contain the interval they came from, which is what subclause
#'   6.8.3 of IEEE Std 1788.1-2017 asks of \code{intervalToText}.
#' @param x An object of class \code{ra_ivl}.
#' @param cs A character scalar, the conversion specifier of 6.8.3, or
#'   \code{NULL}. The recognised values are \code{"decorated"}, which is the
#'   default and appends the decoration, and \code{"bare"}, which omits it.
#'   Any other value is invalid and is refused rather than ignored, because
#'   6.8.3 allows an implementation to define which specifiers it recognises
#'   but not to accept one silently and do something else.
#' @return A character vector of the length of \code{x}.
#' @details The difference from \code{format()} is small and entirely about
#'   syntax, because the containment is the same and comes from the same place.
#'   Infinities are written \code{inf} and \code{-inf}, which is the spelling
#'   of 6.6.1(d) and not the \code{Inf} of R; and the asterisk that
#'   \code{format()} puts on a measured enclosure is dropped, because a literal
#'   has no place to carry provenance and a string that cannot be read back is
#'   not the output of this subclause. The provenance is still readable with
#'   [ra_prov()], and a caller writing a certificate should carry it in its own
#'   field rather than in the number.
#'
#'   What the string means is fixed by 6.6.2: the value of the literal
#'   \code{[l, u]} is the \emph{mathematical} interval \code{[l, u]}, the
#'   decimals read exactly. That, and not "the string reads back to the same
#'   double", is the criterion these strings satisfy.
#' @section Methodological notes:
#'   The tightness of the enclosure is left implementation-defined by 6.8.3,
#'   and what this implementation defines is stated rather than left to be
#'   measured: the value of the string is contained in \code{[ra_pred(lo),
#'   ra_succ(hi)]}, so converting an interval to text costs no more than one
#'   operation of the arithmetic costs.
#'
#'   The uncertain form of 6.6.2, \code{m?r}, is not emitted. It is often
#'   shorter for a narrow interval, and a later version may take a specifier
#'   for it; nothing here depends on it, and a form that is not emitted is
#'   better absent than half-written.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Institute of Electrical and Electronics Engineers. (2018). IEEE standard
#'   for interval arithmetic (simplified) (IEEE Std 1788.1-2017).
#'   https://doi.org/10.1109/IEEESTD.2018.8277144
#' @examples
#' ra_interval_to_text(ra_interval(1/3, 1/3 + 1e-12))
#' ra_interval_to_text(ra_entire(), cs = "bare")
#' @seealso [format.ra_ivl()] for the console rendering, which encloses in the
#'   same way but spells the infinities as R does.
#' @export
ra_interval_to_text <- function(x, cs = NULL) {
  x <- .ra_as_ivl(x)
  if (is.null(cs)) cs <- "decorated"
  if (!(is.character(cs) && length(cs) == 1L && !is.na(cs) &&
        cs %in% c("decorated", "bare"))) {
    ra_stop("bad_argument",
            "`cs` must be NULL, \"decorated\" or \"bare\": those are the conversion specifiers this implementation recognises.")
  }
  lo <- sub("^Inf$", "inf", sub("^-Inf$", "-inf", .ra_bound(x$lo, up = FALSE)))
  hi <- sub("^Inf$", "inf", sub("^-Inf$", "-inf", .ra_bound(x$hi, up = TRUE)))
  out <- paste0("[", lo, ", ", hi, "]")
  out[ra_is_empty(x)] <- "[empty]"
  if (cs == "decorated") out <- paste0(out, "_", x$dec)
  out[ra_is_nai(x)] <- "[nai]"
  out
}
