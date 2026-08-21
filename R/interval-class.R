## The interval class and its decorations.
##
## An interval here is a closed connected subset of the real line, held as two
## parallel vectors of endpoints and a parallel vector of decorations. The
## representation is inf-sup, which is what the set-based flavor of the interval
## standard uses and what the extended division of the Newton operator is
## naturally written in.
##
## Two conventions have to be fixed because the standard fixes them only at the
## mathematical level and leaves the encoding to the implementation. The empty
## set is held as the reversed pair (+Inf, -Inf), so that emptiness is the test
## lo > hi and the intersection of two intervals is the pair (max of the lows,
## min of the highs) with no case analysis. Not-an-Interval is held as the pair
## (NaN, NaN) with the ill decoration, so that it cannot be mistaken for a
## number in any comparison.

## The propagation order of the standard, as ranks: com > dac > def > trv > ill.
.ra_dec_rank <- c(ill = 1L, trv = 2L, def = 3L, dac = 4L, com = 5L)

.ra_rank <- function(d) {
  r <- .ra_dec_rank[d]
  if (anyNA(r)) {
    bad <- unique(d[is.na(r)])
    ra_stop("bad_decoration",
            paste0("Unknown decoration: ", paste(bad, collapse = ", "),
                   ". The five of the standard are com, dac, def, trv, ill."),
            decoration = bad)
  }
  unname(r)
}

.ra_unrank <- function(r) names(.ra_dec_rank)[r]

## The permitted-combination rules of the standard, applied rather than
## checked: a forbidden pair is repaired to the nearest permitted one, which is
## what setDec is specified to do.
.ra_repair_dec <- function(lo, hi, dec) {
  nai <- is.na(lo) | is.na(hi)
  empty <- !nai & lo > hi
  unbounded <- !nai & !empty & (is.infinite(lo) | is.infinite(hi))
  dec[dec == "ill"] <- "ill"
  dec[empty & dec %in% c("com", "dac", "def")] <- "trv"
  dec[unbounded & dec == "com"] <- "dac"
  dec[nai] <- "ill"
  dec
}

#' @title Build an interval
#' @description Creates a decorated interval from its endpoints, checking the
#'   invariant that makes it an interval at all, and attaching the decoration
#'   the standard prescribes when none is named.
#' @param lo A numeric vector of lower endpoints. \code{-Inf} is allowed as a
#'   bound; \code{+Inf} is not, because no nonempty interval has it as a lower
#'   bound.
#' @param hi A numeric vector of upper endpoints, recycled against \code{lo}.
#'   \code{+Inf} is allowed as a bound and \code{-Inf} is not.
#' @param decoration A character vector of decorations, one of \code{"com"},
#'   \code{"dac"}, \code{"def"}, \code{"trv"} or \code{"ill"}, recycled. When
#'   left as \code{NULL}, the initial decoration of the standard is used:
#'   \code{"com"} for a nonempty bounded interval, \code{"dac"} for an unbounded
#'   one and \code{"trv"} for the empty one.
#' @return An object of class \code{ra_ivl}.
#' @details The invariant \code{lo <= hi} is checked here and never again.
#'   Every operation of the package preserves it as a theorem, and checking it
#'   downstream would be checking arithmetic that was already proved; what it
#'   would catch is a defect in this package, which is what the test suite is
#'   for and not what a user's run should pay for.
#'
#'   Infinite endpoints are bounds and never members: \code{[-Inf, Inf]} is the
#'   whole real line and not the extended real line, so \code{Inf} is not in it.
#'   This is why \code{[Inf, Inf]} is not an interval and is refused rather than
#'   silently turned into something else.
#'
#'   A missing endpoint produces Not-an-Interval rather than an error, because a
#'   missing value is a statement about knowledge and not a violated contract;
#'   an inverted pair of known endpoints is a violated contract and raises.
#' @section Methodological notes:
#'   The constructor raises where subclause 6.7.5 of IEEE Std 1788.1-2017 has
#'   the decorated constructor return Not-an-Interval. This is a declared
#'   divergence and it is deliberate. Note first what the subclause asks: a
#'   failed constructor both returns a datum \emph{and} signals the
#'   \code{UndefinedOperation} exception, so what the standard forbids is
#'   failing in silence, not failing loudly. In R the loud form of that is a
#'   typed condition, and the quiet form -- returning a value that looks like
#'   an interval and carries a defect inside it -- is the one this package will
#'   not take by default, because in a language where nothing forces the caller
#'   to inspect a decoration, a Not-an-Interval returned by default travels.
#'   The value form is one call away for anyone who wants it: build it with
#'   [ra_nai()], or catch the condition, which is typed for exactly that.
#'
#'   The definition of an interval is subclause 4.2 of the standard; the
#'   decorations are its subclause 5.2, the permitted combinations 5.4, and the
#'   initial decoration 5.5.1.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Institute of Electrical and Electronics Engineers. (2018). IEEE standard for
#'   interval arithmetic (simplified) (IEEE Std 1788.1-2017).
#'   https://doi.org/10.1109/IEEESTD.2018.8277144
#' @examples
#' ra_interval(1, 2)
#' ra_interval(c(-1, 0), c(1, 3))
#' ra_interval(-Inf, Inf)
#' tryCatch(ra_interval(2, 1), ra_bad_endpoints = function(cnd) "refused")
#' @seealso [ra_empty()], [ra_entire()], [ra_nai()] for the special values, and
#'   [ra_inf()] for the accessors.
#' @export
ra_interval <- function(lo, hi = lo, decoration = NULL) {
  lo <- as.numeric(lo)
  hi <- as.numeric(hi)
  n <- max(length(lo), length(hi))
  if (n == 0L) {
    return(structure(list(lo = numeric(0), hi = numeric(0),
                          dec = character(0), prov = character(0)),
                     class = "ra_ivl"))
  }
  lo <- rep_len(lo, n)
  hi <- rep_len(hi, n)

  known <- !is.na(lo) & !is.na(hi)
  bad <- known & lo > hi
  if (any(bad)) {
    i <- which(bad)[1L]
    ra_stop("bad_endpoints",
            paste0("An interval needs lo <= hi, and element ", i,
                   " has lo = ", format(lo[i]), " and hi = ", format(hi[i]),
                   ". Use ra_empty() for the empty interval, which is a value ",
                   "and not an inverted pair."),
            lo = lo[i], hi = hi[i], index = i)
  }
  bad_inf <- known & (lo == Inf | hi == -Inf)
  if (any(bad_inf)) {
    i <- which(bad_inf)[1L]
    ra_stop("bad_endpoints",
            paste0("Infinities are bounds of an interval and never members, ",
                   "so no nonempty interval has +Inf as its lower bound or ",
                   "-Inf as its upper bound. Element ", i, " has lo = ",
                   format(lo[i]), " and hi = ", format(hi[i]), "."),
            lo = lo[i], hi = hi[i], index = i)
  }

  lo[!known] <- NaN
  hi[!known] <- NaN
  if (is.null(decoration)) {
    decoration <- ifelse(!known, "ill",
                         ifelse(is.infinite(lo) | is.infinite(hi), "dac",
                                "com"))
  } else {
    decoration <- rep_len(as.character(decoration), n)
    .ra_rank(decoration)
  }
  structure(list(lo = lo, hi = hi,
                 dec = .ra_repair_dec(lo, hi, decoration),
                 prov = rep("theorem", n)),
            class = "ra_ivl")
}

#' @title The special intervals
#' @description Build the empty interval, the whole real line, and
#'   Not-an-Interval, each as a value of the interval class.
#' @param n An integer scalar, how many to build. Defaults to one.
#' @return An object of class \code{ra_ivl} of length \code{n}.
#' @details The three are values and not errors. The empty interval is the
#'   proved answer to a question such as where a function with no zero in a box
#'   has one; the whole real line is the honest answer when nothing is known;
#'   Not-an-Interval is what an invalid construction produces when it is asked
#'   to produce a value rather than to stop.
#'
#'   Their decorations are fixed by the standard and are not free: the empty
#'   interval can only carry \code{trv}, because the decorations above it assert
#'   that the argument box is nonempty; the whole real line carries \code{dac}
#'   rather than \code{com}, because \code{com} asserts boundedness; and
#'   Not-an-Interval carries \code{ill} by definition.
#' @section Methodological notes:
#'   Making these values rather than exceptions is what allows the paving engine
#'   to say what it proved. A box proved to contain no root returns the empty
#'   interval, which is a theorem; a box the engine ran out of budget on returns
#'   an interval with a word attached. Neither is a silence and neither is an
#'   error.
#'
#'   The definitions are subclauses 4.5.1 and 5.3 of IEEE Std 1788.1-2017.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Institute of Electrical and Electronics Engineers. (2018). IEEE standard for
#'   interval arithmetic (simplified) (IEEE Std 1788.1-2017).
#'   https://doi.org/10.1109/IEEESTD.2018.8277144
#' @examples
#' ra_empty()
#' ra_entire()
#' ra_nai()
#' ra_is_empty(ra_empty())
#' @seealso [ra_interval()].
#' @name ra_specials
NULL

#' @rdname ra_specials
#' @export
ra_empty <- function(n = 1L) {
  structure(list(lo = rep(Inf, n), hi = rep(-Inf, n), dec = rep("trv", n),
                 prov = rep("theorem", n)),
            class = "ra_ivl")
}

#' @rdname ra_specials
#' @export
ra_entire <- function(n = 1L) {
  structure(list(lo = rep(-Inf, n), hi = rep(Inf, n), dec = rep("dac", n),
                 prov = rep("theorem", n)),
            class = "ra_ivl")
}

#' @rdname ra_specials
#' @export
ra_nai <- function(n = 1L) {
  structure(list(lo = rep(NaN, n), hi = rep(NaN, n), dec = rep("ill", n),
                 prov = rep("theorem", n)),
            class = "ra_ivl")
}

#' @title Read the parts of an interval
#' @description Extract the lower endpoint, the upper endpoint, the decoration,
#'   or the answers to the questions of whether an interval is empty, the whole
#'   line, or Not-an-Interval.
#' @param x An object of class \code{ra_ivl}.
#' @return Numeric vectors for the endpoints, a character vector for the
#'   decoration, and logical vectors for the three questions, all of the length
#'   of \code{x}.
#' @details The endpoints of the empty interval are the reversed pair the
#'   representation uses; a caller who wants to branch on emptiness should ask
#'   [ra_is_empty()] rather than compare endpoints, so that the encoding stays
#'   an internal matter.
#' @section Methodological notes:
#'   The decoration is the provenance field of a result, not a second opinion
#'   about it. An interval decorated \code{trv} is exactly as valid an enclosure
#'   as one decorated \code{com}; what differs is how much the operation was
#'   able to assert about the function it evaluated.
#'
#'   The operations follow subclauses 4.5.7 and 5.5.2 of IEEE Std 1788.1-2017.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Institute of Electrical and Electronics Engineers. (2018). IEEE standard for
#'   interval arithmetic (simplified) (IEEE Std 1788.1-2017).
#'   https://doi.org/10.1109/IEEESTD.2018.8277144
#' @examples
#' x <- ra_interval(c(1, -Inf), c(2, Inf))
#' ra_inf(x)
#' ra_sup(x)
#' ra_dec(x)
#' ra_is_entire(x)
#' @seealso [ra_wid()] for the derived quantities.
#' @name ra_parts
NULL

#' @rdname ra_parts
#' @export
ra_inf <- function(x) {
  .ra_check_ivl(x)
  x$lo
}

#' @rdname ra_parts
#' @export
ra_sup <- function(x) {
  .ra_check_ivl(x)
  x$hi
}

#' @rdname ra_parts
#' @export
ra_dec <- function(x) {
  .ra_check_ivl(x)
  x$dec
}

#' @rdname ra_parts
#' @export
ra_is_nai <- function(x) {
  .ra_check_ivl(x)
  is.na(x$lo) | is.na(x$hi)
}

#' @rdname ra_parts
#' @export
ra_is_empty <- function(x) {
  .ra_check_ivl(x)
  !ra_is_nai(x) & x$lo > x$hi
}

#' @rdname ra_parts
#' @export
ra_is_entire <- function(x) {
  .ra_check_ivl(x)
  !ra_is_nai(x) & x$lo == -Inf & x$hi == Inf
}

.ra_check_ivl <- function(x) {
  if (!inherits(x, "ra_ivl")) {
    ra_stop("bad_argument", "Expected an object of class ra_ivl.")
  }
  invisible(TRUE)
}

#' @title Derived quantities of an interval
#' @description The width, midpoint, radius, magnitude and mignitude, computed
#'   so that each one is itself an outward bound of the quantity it names.
#' @param x An object of class \code{ra_ivl}.
#' @return A numeric vector of the length of \code{x}. The empty interval gives
#'   \code{NaN} for all five, and Not-an-Interval gives \code{NaN}.
#' @details The width is rounded upward and the radius is rounded upward, so
#'   that neither can be reported smaller than it is; a width reported too small
#'   is what would let a stopping rule declare a box narrow enough when it is
#'   not. The midpoint is rounded to nearest and is the one quantity here that
#'   is not a bound: it is a point of the interval, chosen for expansion, and
#'   the operations that use it re-enclose whatever they compute from it.
#'
#'   The magnitude is the largest absolute value attained on the interval and
#'   the mignitude is the smallest; the mignitude is zero exactly when the
#'   interval contains zero, which is how the division and the monotonicity test
#'   ask that question.
#' @section Methodological notes:
#'   Reporting the midpoint without an outward step is safe only because no
#'   guarantee rests on it. The Newton operator may expand about any point of
#'   the box and remains valid; the choice of the midpoint is an efficiency
#'   decision, and its rounding error is absorbed by the enclosure of the
#'   function value computed there.
#'
#'   The definitions of the midpoint, radius, magnitude and mignitude are
#'   section 1.6 of Neumaier (1990).
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Neumaier, A. (1990). Interval methods for systems of equations. Cambridge
#'   University Press. https://doi.org/10.1017/CBO9780511526473
#' @examples
#' x <- ra_interval(c(-2, 1), c(3, 4))
#' ra_wid(x)
#' ra_mid(x)
#' ra_mag(x)
#' ra_mig(x)
#' @seealso [ra_inf()].
#' @name ra_measures
NULL

#' @rdname ra_measures
#' @export
ra_wid <- function(x) {
  .ra_check_ivl(x)
  out <- ra_succ(x$hi - x$lo)
  out[ra_is_empty(x) | ra_is_nai(x)] <- NaN
  out
}

#' @rdname ra_measures
#' @export
ra_mid <- function(x) {
  .ra_check_ivl(x)
  out <- x$lo / 2 + x$hi / 2
  both_inf <- is.finite(x$lo) & is.finite(x$hi)
  out[!both_inf] <- NaN
  out[!both_inf & x$lo == -Inf & x$hi == Inf] <- 0
  fin <- is.finite(x$lo) & is.finite(x$hi)
  out[fin & !is.finite(out)] <- (x$lo[fin & !is.finite(out)] +
                                   x$hi[fin & !is.finite(out)]) / 2
  out[ra_is_empty(x) | ra_is_nai(x)] <- NaN
  out
}

#' @rdname ra_measures
#' @export
ra_rad <- function(x) {
  .ra_check_ivl(x)
  m <- ra_mid(x)
  out <- ra_succ(pmax(ra_succ(m - x$lo), ra_succ(x$hi - m)))
  out[ra_is_empty(x) | ra_is_nai(x)] <- NaN
  out
}

#' @rdname ra_measures
#' @export
ra_mag <- function(x) {
  .ra_check_ivl(x)
  out <- pmax(abs(x$lo), abs(x$hi))
  out[ra_is_empty(x) | ra_is_nai(x)] <- NaN
  out
}

#' @rdname ra_measures
#' @export
ra_mig <- function(x) {
  .ra_check_ivl(x)
  out <- pmin(abs(x$lo), abs(x$hi))
  out[x$lo <= 0 & x$hi >= 0] <- 0
  out[ra_is_empty(x) | ra_is_nai(x)] <- NaN
  out
}

#' @title Show an interval
#' @description Render intervals for the console and for a data frame, with the
#'   decoration attached to each one and the special values named rather than
#'   printed as endpoint pairs.
#' @param x An object of class \code{ra_ivl}.
#' @param ... Further arguments, ignored, present for consistency with the
#'   generics.
#' @param row.names,optional Arguments of the \code{as.data.frame} generic. The
#'   first is used; the second is ignored.
#' @param object An object of class \code{ra_ivl}, for the \code{summary}
#'   method.
#' @return \code{format} returns a character vector; \code{print} returns its
#'   argument invisibly; \code{as.data.frame} returns a data frame with columns
#'   \code{lo}, \code{hi}, \code{dec} and \code{wid}; \code{summary} returns an
#'   object of class \code{ra_ivl_summary}, which prints a count of each
#'   decoration and of each special value.
#' @details The empty interval prints as the word for it and not as the reversed
#'   endpoint pair that represents it, because the pair is an encoding and
#'   printing it would invite a reader to compare endpoints instead of asking.
#'   Not-an-Interval prints as its name for the same reason.
#' @section Methodological notes:
#'   The decoration is printed always and never suppressed when it is
#'   \code{com}. A field that appears only when it is interesting teaches a
#'   reader to stop looking for it, and the decoration is precisely the field
#'   that must be read on the results that look ordinary.
#'
#'   \strong{The printed pair encloses the interval, and the reader is owed
#'   that and not a tidy number.} Subclause 6.8.3 of IEEE Std 1788.1-2017 asks
#'   of \code{intervalToText} that the string contain the interval it came
#'   from, and subclause 6.6.2 fixes what a string means: the value of the
#'   literal \code{[l, u]} is the \emph{mathematical} interval \code{[l, u]},
#'   that is, the decimals read exactly. Rounding each endpoint to nearest --
#'   which is what every printing default in R does -- breaks that: the
#'   enclosure whose endpoints are the predecessor and the successor of one
#'   would print as \code{[1, 1]}, which contains neither. So the lower
#'   endpoint is rounded down and the upper endpoint up, each to the fewest
#'   digits that carry the proof.
#'
#'   Two consequences a reader meets immediately. An endpoint prints with as
#'   many digits as its \emph{value} needs and not as many as its neighbour
#'   needs, so \code{[0.1, 0.2]} prints its endpoints at different lengths: the
#'   double nearest \code{0.1} is above the decimal \code{0.1}, so \code{0.1}
#'   is a true lower bound, while the double nearest \code{0.2} is also above
#'   the decimal \code{0.2}, so \code{0.2} is not a true upper bound and the
#'   next one is printed. And a degenerate interval prints as two different
#'   decimals, because a degenerate interval of doubles is not a real number:
#'   it is everything that rounds to one.
#'
#'   Numbers that are decimals exactly -- \code{-2.5}, \code{3.75},
#'   \code{1e-3}, every power of two -- print exactly as they did, at their own
#'   length, because for them rounding down and rounding up are the number
#'   itself. Nothing is paid where nothing is owed.
#'
#'   \strong{What the widening costs is bounded and declared.} The printed
#'   enclosure is contained in \code{[ra_pred(lo), ra_succ(hi)]}: printing an
#'   enclosure never costs more than one operation of the arithmetic costs, and
#'   the width on the page is the width in the object to within that.
#'
#'   \strong{What it costs in time is declared too}, because it is not free:
#'   each endpoint is proved rather than formatted, which is of the order of a
#'   millisecond, and distinct values are the unit, so a vector whose endpoints
#'   repeat costs what its distinct endpoints cost. Printing the handful of
#'   intervals a session looks at is imperceptible; formatting a vector of
#'   thousands is seconds, and a caller in that position wants
#'   \code{as.data.frame()}, which does no proving because it does no printing.
#'   The
#'   endpoints themselves are in \code{x$lo} and \code{x$hi}, and
#'   \code{as.data.frame()} carries them unrounded, which is where a reader who
#'   needs the doubles goes.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Institute of Electrical and Electronics Engineers. (2018). IEEE standard for
#'   interval arithmetic (simplified) (IEEE Std 1788.1-2017).
#'   https://doi.org/10.1109/IEEESTD.2018.8277144
#' @examples
#' x <- ra_interval(c(1, -Inf), c(2, Inf))
#' format(x)
#' print(x)
#' as.data.frame(x)
#' summary(c(x, ra_empty(), ra_nai()))
#' @seealso [ra_interval()].
#' @name ra_show
NULL

#' @rdname ra_show
#' @export
format.ra_ivl <- function(x, ...) {
  ## paste0() treats a zero-length argument as the empty string rather than
  ## propagating the length, so an empty vector of intervals would format as
  ## one line of punctuation instead of as nothing
  if (!length(x$lo)) return(character(0))
  ## the endpoints are rounded AWAY from each other, so that the pair of
  ## decimals on the page encloses the pair of doubles underneath, read as
  ## decimals and not as the doubles they happen to round to. Rounding to
  ## nearest, which is what every default in R does, prints an enclosure that
  ## does not enclose: see .ra_bound1() and the note on 6.8.3 below
  out <- paste0("[", .ra_bound(x$lo, up = FALSE), ", ",
                .ra_bound(x$hi, up = TRUE), "]_", x$dec)
  out[ra_is_empty(x)] <- paste0("[empty]_", x$dec[ra_is_empty(x)])
  out[ra_is_nai(x)] <- "[nai]"
  ## the provenance travels on the printed form: a measured enclosure is
  ## marked so a reader cannot mistake a convention for a theorem
  paste0(out, ifelse(ra_prov(x) == "measured", "*", ""))
}

#' @rdname ra_show
#' @export
print.ra_ivl <- function(x, ...) {
  cat("<ra_ivl[", length(x$lo), "]>\n", sep = "")
  if (length(x$lo)) cat(format(x), sep = "\n")
  if (any(ra_prov(x) == "measured")) {
    cat("* measured provenance: fast-level slack, a declared convention",
        "over a measured error, not a theorem\n")
  }
  invisible(x)
}

#' @rdname ra_show
#' @export
as.data.frame.ra_ivl <- function(x, row.names = NULL, optional = FALSE, ...) {
  data.frame(lo = x$lo, hi = x$hi, dec = x$dec, prov = ra_prov(x),
             wid = ra_wid(x),
             row.names = row.names, stringsAsFactors = FALSE)
}

#' @rdname ra_show
#' @export
summary.ra_ivl <- function(object, ...) {
  structure(list(n = length(object$lo),
                 decorations = table(factor(object$dec,
                                            levels = names(.ra_dec_rank))),
                 n_empty = sum(ra_is_empty(object)),
                 n_entire = sum(ra_is_entire(object)),
                 n_nai = sum(ra_is_nai(object)),
                 n_measured = sum(ra_prov(object) == "measured"),
                 max_width = if (length(object$lo)) {
                   suppressWarnings(max(ra_wid(object), na.rm = TRUE))
                 } else NA_real_),
            class = "ra_ivl_summary")
}

#' @rdname ra_show
#' @export
print.ra_ivl_summary <- function(x, ...) {
  cat("Intervals: ", x$n, "\n", sep = "")
  cat("Decorations: ",
      paste(names(x$decorations), unname(x$decorations), sep = "=",
            collapse = "  "), "\n", sep = "")
  cat("Empty: ", x$n_empty, "  Entire: ", x$n_entire, "  NaI: ", x$n_nai,
      "\n", sep = "")
  cat("Provenance: theorem=", x$n - x$n_measured, "  measured=",
      x$n_measured, "\n", sep = "")
  ## a width printed short claims a narrower enclosure than the one held
  cat("Widest: ", .ra_card_up(x$max_width), "\n", sep = "")
  invisible(x)
}

#' @title Combine and subset intervals
#' @description The concatenation, length and subsetting a vector of intervals
#'   needs to behave as a vector of intervals rather than as the list underneath
#'   it.
#' @param x An object of class \code{ra_ivl}.
#' @param i An index, of any form \code{[} accepts for a numeric vector.
#' @param ... Objects of class \code{ra_ivl} to concatenate.
#' @return An object of class \code{ra_ivl}, or an integer for \code{length}.
#' @details Without these, \code{c()} on two intervals produces a list of two
#'   lists and \code{length()} reports three, the number of fields. Both would
#'   be wrong in a way that only shows up far downstream.
#' @section Methodological notes:
#'   These are written here with the class rather than added later, because a
#'   class whose vector behaviour arrives in a second pass spends the interval
#'   between the two passes producing plausible wrong numbers.
#'
#'   Chapter 13 of Wickham (2019) treats S3 vector classes and the methods
#'   they must carry.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Wickham, H. (2019). Advanced R (2nd ed.). Chapman & Hall/CRC.
#'   https://doi.org/10.1201/9781351201315
#' @examples
#' x <- c(ra_interval(1, 2), ra_interval(3, 4))
#' length(x)
#' x[2]
#' @seealso [ra_interval()].
#' @name ra_vector
NULL

#' @rdname ra_vector
#' @export
length.ra_ivl <- function(x) length(x$lo)

#' @rdname ra_vector
#' @export
c.ra_ivl <- function(...) {
  parts <- list(...)
  for (p in parts) .ra_check_ivl(p)
  structure(list(lo = unlist(lapply(parts, `[[`, "lo"), use.names = FALSE),
                 hi = unlist(lapply(parts, `[[`, "hi"), use.names = FALSE),
                 dec = unlist(lapply(parts, `[[`, "dec"), use.names = FALSE),
                 prov = unlist(lapply(parts, ra_prov), use.names = FALSE)),
            class = "ra_ivl")
}

#' @rdname ra_vector
#' @export
`[.ra_ivl` <- function(x, i) {
  structure(list(lo = x$lo[i], hi = x$hi[i], dec = x$dec[i],
                 prov = ra_prov(x)[i]),
            class = "ra_ivl")
}

#' @title Attach a decoration to an interval
#' @description Sets the decoration of an interval, repairing the combinations
#'   the standard forbids rather than producing them or refusing.
#' @param x An object of class \code{ra_ivl}.
#' @param decoration A character vector of decorations, recycled to the length
#'   of \code{x}.
#' @return An object of class \code{ra_ivl}.
#' @details Three combinations are contradictory and cannot be produced. The
#'   empty interval with \code{def}, \code{dac} or \code{com} becomes the empty
#'   interval with \code{trv}, because those three assert that the argument box
#'   was nonempty. An unbounded interval with \code{com} becomes the same
#'   interval with \code{dac}, because \code{com} asserts boundedness. Anything
#'   with \code{ill} becomes Not-an-Interval, whose interval part has no value.
#'
#'   The repairs are silent because they are definitional and not corrective:
#'   the requested decoration was not a weaker claim about the same object, it
#'   was a claim no object can carry, and the value returned is the strongest
#'   one that can be.
#' @section Methodological notes:
#'   This is where a caller who knows something the arithmetic could not deduce
#'   attaches it. The set operations, in particular, are decorated \code{trv} by
#'   the standard because no single decoration is right for every use of them;
#'   a caller who can justify a stronger one in a specific context is expected
#'   to attach it here, deliberately and in one visible place.
#'
#'   The permitted combinations and the repairing operation are subclauses 5.4
#'   and 5.5.2 of IEEE Std 1788.1-2017.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Institute of Electrical and Electronics Engineers. (2018). IEEE standard for
#'   interval arithmetic (simplified) (IEEE Std 1788.1-2017).
#'   https://doi.org/10.1109/IEEESTD.2018.8277144
#' @examples
#' ra_dec(ra_set_dec(ra_empty(), "com"))
#' ra_dec(ra_set_dec(ra_entire(), "com"))
#' ra_is_nai(ra_set_dec(ra_interval(1, 2), "ill"))
#' @seealso [ra_interval()], [ra_dec()].
#' @export
ra_set_dec <- function(x, decoration) {
  .ra_check_ivl(x)
  d <- rep_len(as.character(decoration), length(x))
  .ra_rank(d)
  lo <- x$lo
  hi <- x$hi
  ill <- d == "ill"
  lo[ill] <- NaN
  hi[ill] <- NaN
  structure(list(lo = lo, hi = hi, dec = .ra_repair_dec(lo, hi, d),
                 prov = ra_prov(x)),
            class = "ra_ivl")
}
