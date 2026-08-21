## The arithmetic of the kernel.
##
## Every operation here does the same three things: it computes the endpoints of
## the exact result from the endpoints of the arguments, it moves those
## endpoints outward by one rounding step, and it propagates the decoration by
## the rule of the standard. The first is the mathematics, the second is what
## makes the answer an enclosure rather than an estimate, and the third is what
## lets a caller find out afterwards what the operation was able to assert.

## Decoration propagation: the local decoration of the operation, met with the
## decorations arriving on the inputs, taking the weakest of them all.
.ra_prop <- function(local, ...) {
  ranks <- c(list(.ra_rank(local)), lapply(list(...), .ra_rank))
  .ra_unrank(do.call(pmin, ranks))
}

## The local decoration of an operation that is defined and continuous on the
## whole of R^k: com when everything in sight is bounded, dac when something is
## not, trv when an argument box is empty.
.ra_local_total <- function(lo, hi, empty) {
  d <- ifelse(is.infinite(lo) | is.infinite(hi), "dac", "com")
  d[empty] <- "trv"
  d
}

## Products with the convention that a zero factor annihilates an infinite one.
## Zero times an unbounded interval is the set {0}, not an indeterminate form:
## the interval [0, 0] times [1, Inf) is the set of products of 0 with a real
## number, all of which are 0, and Inf is a bound and never a member.
.ra_prod <- function(a, b) {
  p <- a * b
  z <- (a == 0 | b == 0) & !is.na(a) & !is.na(b)
  p[z] <- 0
  p
}

.ra_as_ivl <- function(x) {
  if (inherits(x, "ra_ivl")) return(x)
  if (is.numeric(x)) return(ra_interval(x, x))
  ra_stop("bad_argument",
          "Expected an ra_ivl or a numeric vector to promote to one.")
}

## Assemble a result, applying the empty and NaI rules that every arithmetic
## operation shares: NaI on any input gives NaI, and an empty input gives the
## empty interval.
.ra_assemble <- function(lo, hi, dec, empty, nai, prov) {
  lo[empty] <- Inf
  hi[empty] <- -Inf
  dec[empty] <- "trv"
  lo[nai] <- NaN
  hi[nai] <- NaN
  dec[nai] <- "ill"
  structure(list(lo = lo, hi = hi, dec = .ra_repair_dec(lo, hi, dec),
                 prov = rep_len(prov, length(lo))),
            class = "ra_ivl")
}

#' @title Interval arithmetic through the ordinary operators
#' @description The four arithmetic operators and unary negation, applied to
#'   intervals, returning enclosures of the exact set of results.
#' @param e1,e2 Objects of class \code{ra_ivl}, or numeric vectors, which are
#'   promoted to intervals of zero width. Lengths are recycled.
#' @return An object of class \code{ra_ivl}.
#' @details Addition, subtraction and multiplication are computed from the
#'   endpoints and then widened by one rounding step in each direction, which is
#'   what makes the result contain the exact set. Multiplication takes the four
#'   endpoint products and keeps their extremes; a zero endpoint meeting an
#'   infinite one contributes zero rather than an indeterminate form, because an
#'   infinity here is a bound and never a member of the interval.
#'
#'   Division follows the set-based definition of the standard: the result is
#'   the tightest interval containing every quotient that is defined. When the
#'   divisor contains zero the set of quotients is generally not an interval,
#'   and the result is its hull, which is valid but wide, and carries the
#'   \code{trv} decoration to say that nothing was asserted about the function.
#'   The operation that keeps the two pieces apart instead of hulling them is
#'   [ra_div_extended()], and the one that refuses rather than widening is
#'   \code{ra_div(x, y, zero = "error")}.
#'
#'   An empty argument gives an empty result, and Not-an-Interval propagates
#'   through everything.
#' @section Methodological notes:
#'   The excess width of these operations is one-sided and that is what makes
#'   them usable. Evaluating an expression in which a variable occurs more than
#'   once treats the occurrences as if they could take different values, so the
#'   result is wider than the true range; it is never narrower. A conclusion
#'   drawn from an enclosure that excludes zero therefore holds, while a failure
#'   to exclude zero proves nothing, and the package never reads it as if it
#'   did.
#'
#'   The operations are subclause 4.5.2 and Table 4.1 of IEEE Std 1788.1-2017;
#'   chapters 2 and 4 of Moore et al. (2009) are the textbook treatment.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Institute of Electrical and Electronics Engineers. (2018). IEEE standard for
#'   interval arithmetic (simplified) (IEEE Std 1788.1-2017).
#'   https://doi.org/10.1109/IEEESTD.2018.8277144
#'
#'   Moore, R. E., Kearfott, R. B., & Cloud, M. J. (2009). Introduction to interval
#'   analysis. Society for Industrial and Applied Mathematics.
#'   https://doi.org/10.1137/1.9780898717716
#' @examples
#' x <- ra_interval(1, 2)
#' y <- ra_interval(3, 4)
#' x + y
#' x * y
#' x - x
#' x / y
#' -x
#' @seealso [ra_div_extended()], [ra_sqr()], [ra_pown()].
#' @export
Ops.ra_ivl <- function(e1, e2) {
  op <- .Generic
  if (missing(e2)) {
    if (identical(op, "-")) return(ra_neg(e1))
    if (identical(op, "+")) return(.ra_as_ivl(e1))
    ra_stop("unsupported_operator",
            paste0("Unary `", op, "` is not defined on intervals."),
            operator = op)
  }
  switch(op,
         "+" = ra_add(e1, e2),
         "-" = ra_sub(e1, e2),
         "*" = ra_mul(e1, e2),
         "/" = ra_div(e1, e2),
         ra_stop("unsupported_operator",
                 paste0("`", op, "` is not defined on intervals. The kernel ",
                        "provides + - * / and unary minus; comparisons and ",
                        "logical operators are refused because the order they ",
                        "would suggest is not the order of sets."),
                 operator = op))
}

#' @title The named arithmetic operations
#' @description The same operations as the operators, available under names, so
#'   that they can be passed to other functions and so that division can be
#'   asked to behave differently when the divisor contains zero.
#' @param x,y Objects of class \code{ra_ivl}, or numeric vectors.
#' @param zero A character scalar saying what division should do when the
#'   divisor contains zero: \code{"hull"}, the default and the behaviour of the
#'   standard, returns the tightest interval containing every defined quotient;
#'   \code{"error"} raises \code{ra_division_straddles_zero}.
#' @return An object of class \code{ra_ivl}.
#' @details The \code{"error"} option exists because in some settings a divisor
#'   straddling zero is a sign that the caller has lost track of a domain
#'   condition, and returning the whole line lets the run continue on an answer
#'   that is valid and empty of content. In the paving engine the opposite is
#'   true, and the default is the total behaviour of the standard.
#' @section Methodological notes:
#'   The two behaviours differ in what they treat as a failure, not in what they
#'   treat as true. Neither ever returns an interval that fails to contain the
#'   exact result.
#'
#'   Table 4.1 of IEEE Std 1788.1-2017 gives the division its domain: the
#'   plane minus the axis where the divisor vanishes.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Institute of Electrical and Electronics Engineers. (2018). IEEE standard for
#'   interval arithmetic (simplified) (IEEE Std 1788.1-2017).
#'   https://doi.org/10.1109/IEEESTD.2018.8277144
#' @examples
#' ra_add(ra_interval(1, 2), ra_interval(3, 4))
#' ra_div(ra_interval(1, 2), ra_interval(-1, 1))
#' tryCatch(ra_div(ra_interval(1, 2), ra_interval(-1, 1), zero = "error"),
#'          ra_division_straddles_zero = function(cnd) "refused")
#' @seealso [Ops.ra_ivl()].
#' @name ra_arith
NULL

#' @rdname ra_arith
#' @export
ra_neg <- function(x) {
  x <- .ra_as_ivl(x)
  .ra_assemble(-x$hi, -x$lo, x$dec, ra_is_empty(x), ra_is_nai(x),
               ra_prov(x))
}

#' @rdname ra_arith
#' @export
ra_add <- function(x, y) {
  x <- .ra_as_ivl(x)
  y <- .ra_as_ivl(y)
  n <- max(length(x), length(y))
  x <- x[rep_len(seq_len(length(x)), n)]
  y <- y[rep_len(seq_len(length(y)), n)]
  empty <- ra_is_empty(x) | ra_is_empty(y)
  nai <- ra_is_nai(x) | ra_is_nai(y)
  lo <- ra_pred(x$lo + y$lo)
  hi <- ra_succ(x$hi + y$hi)
  local <- .ra_local_total(lo, hi, empty)
  .ra_assemble(lo, hi, .ra_prop(local, x$dec, y$dec), empty, nai,
               .ra_prov2(ra_prov(x), ra_prov(y)))
}

#' @rdname ra_arith
#' @export
ra_sub <- function(x, y) {
  x <- .ra_as_ivl(x)
  y <- .ra_as_ivl(y)
  n <- max(length(x), length(y))
  x <- x[rep_len(seq_len(length(x)), n)]
  y <- y[rep_len(seq_len(length(y)), n)]
  empty <- ra_is_empty(x) | ra_is_empty(y)
  nai <- ra_is_nai(x) | ra_is_nai(y)
  lo <- ra_pred(x$lo - y$hi)
  hi <- ra_succ(x$hi - y$lo)
  local <- .ra_local_total(lo, hi, empty)
  .ra_assemble(lo, hi, .ra_prop(local, x$dec, y$dec), empty, nai,
               .ra_prov2(ra_prov(x), ra_prov(y)))
}

#' @rdname ra_arith
#' @export
ra_mul <- function(x, y) {
  x <- .ra_as_ivl(x)
  y <- .ra_as_ivl(y)
  n <- max(length(x), length(y))
  x <- x[rep_len(seq_len(length(x)), n)]
  y <- y[rep_len(seq_len(length(y)), n)]
  empty <- ra_is_empty(x) | ra_is_empty(y)
  nai <- ra_is_nai(x) | ra_is_nai(y)
  p1 <- .ra_prod(x$lo, y$lo)
  p2 <- .ra_prod(x$lo, y$hi)
  p3 <- .ra_prod(x$hi, y$lo)
  p4 <- .ra_prod(x$hi, y$hi)
  lo <- ra_pred(pmin(p1, p2, p3, p4))
  hi <- ra_succ(pmax(p1, p2, p3, p4))
  local <- .ra_local_total(lo, hi, empty)
  .ra_assemble(lo, hi, .ra_prop(local, x$dec, y$dec), empty, nai,
               .ra_prov2(ra_prov(x), ra_prov(y)))
}

#' @rdname ra_arith
#' @export
ra_div <- function(x, y, zero = c("hull", "error")) {
  zero <- match.arg(zero)
  x <- .ra_as_ivl(x)
  y <- .ra_as_ivl(y)
  n <- max(length(x), length(y))
  x <- x[rep_len(seq_len(length(x)), n)]
  y <- y[rep_len(seq_len(length(y)), n)]
  empty <- ra_is_empty(x) | ra_is_empty(y)
  nai <- ra_is_nai(x) | ra_is_nai(y)

  straddles <- !empty & !nai & y$lo <= 0 & y$hi >= 0
  if (identical(zero, "error") && any(straddles)) {
    i <- which(straddles)[1L]
    ra_stop("division_straddles_zero",
            paste0("The divisor of element ", i, " contains zero, so the set ",
                   "of quotients is unbounded and generally not an interval. ",
                   "Use ra_div_extended() to keep its two pieces apart, or ",
                   "the default zero = \"hull\" to take their hull."),
            index = i)
  }

  ## The divisor is bounded away from zero: four quotients and their extremes.
  q1 <- x$lo / y$lo
  q2 <- x$lo / y$hi
  q3 <- x$hi / y$lo
  q4 <- x$hi / y$hi
  lo <- ra_pred(pmin(q1, q2, q3, q4))
  hi <- ra_succ(pmax(q1, q2, q3, q4))

  ## The divisor contains zero: the hull of what the extended division would
  ## return, which is the whole line unless the divisor touches zero only at an
  ## endpoint and the numerator is bounded away from zero.
  if (any(straddles)) {
    ext <- .ra_div_pieces(x[straddles], y[straddles])
    lo[straddles] <- ext$hull_lo
    hi[straddles] <- ext$hull_hi
  }

  local <- .ra_local_total(lo, hi, empty)
  local[straddles] <- "trv"
  ## A numerator known to be zero divided by anything defined is zero, and the
  ## divisor containing zero makes the operation undefined somewhere in the box
  ## regardless, so the trv above stands.
  .ra_assemble(lo, hi, .ra_prop(local, x$dec, y$dec), empty, nai,
               .ra_prov2(ra_prov(x), ra_prov(y)))
}

## The pieces of an extended division, and their hull. The divisor is assumed to
## contain zero and neither argument to be empty or NaI.
.ra_div_pieces <- function(x, y) {
  n <- length(x)
  lo1 <- rep(-Inf, n)
  hi1 <- rep(Inf, n)
  lo2 <- rep(Inf, n)
  hi2 <- rep(-Inf, n)

  zero_num <- x$lo <= 0 & x$hi >= 0
  y_zero <- y$lo == 0 & y$hi == 0

  ## Numerator straddles zero as well, or the divisor is exactly {0}: nothing is
  ## excluded. When the divisor is exactly zero the set of defined quotients is
  ## empty, and the empty set is enclosed by anything; the hull is reported as
  ## the whole line so that no caller reads emptiness as a proof.
  ## Otherwise the two half-lines of the interval Newton step.
  pos <- !zero_num & x$lo > 0
  neg <- !zero_num & x$hi < 0
  c_zero <- y$lo == 0
  d_zero <- y$hi == 0

  ## Numerator strictly positive.
  i <- pos & !y_zero & c_zero
  lo1[i] <- x$lo[i] / y$hi[i]
  hi1[i] <- Inf
  lo2[i] <- Inf
  hi2[i] <- -Inf
  i <- pos & !y_zero & d_zero
  lo1[i] <- -Inf
  hi1[i] <- x$lo[i] / y$lo[i]
  i <- pos & !y_zero & !c_zero & !d_zero
  lo1[i] <- -Inf
  hi1[i] <- x$lo[i] / y$lo[i]
  lo2[i] <- x$lo[i] / y$hi[i]
  hi2[i] <- Inf

  ## Numerator strictly negative: the mirror image.
  i <- neg & !y_zero & c_zero
  lo1[i] <- -Inf
  hi1[i] <- x$hi[i] / y$hi[i]
  lo2[i] <- Inf
  hi2[i] <- -Inf
  i <- neg & !y_zero & d_zero
  lo1[i] <- x$hi[i] / y$lo[i]
  hi1[i] <- Inf
  i <- neg & !y_zero & !c_zero & !d_zero
  lo1[i] <- -Inf
  hi1[i] <- x$hi[i] / y$hi[i]
  lo2[i] <- x$hi[i] / y$lo[i]
  hi2[i] <- Inf

  ## Whether a second piece exists is decided on the sentinel pair before any
  ## rounding touches it, so that the answer does not depend on what the
  ## outward step happens to do to an infinite endpoint.
  second <- lo2 <= hi2

  ## Outward rounding of the finite endpoints. The infinite ones are already
  ## bounds and need no step.
  lo1 <- ra_pred(lo1)
  hi1 <- ra_succ(hi1)
  lo2 <- ifelse(second, ra_pred(lo2), Inf)
  hi2 <- ifelse(second, ra_succ(hi2), -Inf)

  list(lo1 = lo1, hi1 = hi1, lo2 = lo2, hi2 = hi2, second = second,
       hull_lo = ifelse(second, pmin(lo1, lo2), lo1),
       hull_hi = ifelse(second, pmax(hi1, hi2), hi1))
}

#' @title Extended division, keeping the two pieces apart
#' @description Divides by an interval that may contain zero and returns the
#'   result as one or two intervals instead of hulling them together, which is
#'   what makes the gap in the middle usable.
#' @param x,y Objects of class \code{ra_ivl}, or numeric vectors. \code{y} may
#'   contain zero.
#' @return A list with two elements, \code{first} and \code{second}, both of
#'   class \code{ra_ivl} and of the length of the recycled arguments. Where the
#'   result has only one piece, the corresponding element of \code{second} is
#'   the empty interval.
#' @details When the divisor contains zero in its interior and the numerator
#'   does not contain zero, the set of quotients is the union of two half-lines
#'   with a gap between them. Hulling them gives the whole real line and throws
#'   away the only piece of information the division produced, which is the gap.
#'   Keeping them apart is what allows the Newton step to split a box into two
#'   at exactly the place where the derivative vanishes, which is the place a
#'   bisection at the midpoint would have to find by luck.
#'
#'   When the divisor touches zero only at one endpoint the result is a single
#'   half-line; when the numerator also contains zero nothing is excluded and
#'   the result is the whole line in one piece; when the divisor is exactly the
#'   zero interval no quotient is defined, and the result is reported as the
#'   whole line rather than as the empty set, so that nobody reads a vacuous
#'   division as a proof of exclusion.
#' @section Methodological notes:
#'   This is the operation that separates the Hansen-Sengupta operator from the
#'   Krawczyk operator, and it is why the design chose the former. Neumaier's
#'   argument is that the iteration with extended division is never weaker than
#'   Krawczyk's and splits the box exactly where the derivative contains zero,
#'   which is the multiple root that motivates the whole path.
#'
#'   The case table implemented here is equations (9.2.3) and (9.2.4) in
#'   section 9.2 of Hansen and Walster (2004); the comparison with the
#'   Krawczyk operator is section 5.1 of Neumaier (1990).
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Hansen, E., & Walster, G. W. (2004). Global optimization using interval
#'   analysis (2nd ed.). Marcel Dekker.
#'
#'   Neumaier, A. (1990). Interval methods for systems of equations. Cambridge
#'   University Press. https://doi.org/10.1017/CBO9780511526473
#' @examples
#' ra_div_extended(ra_interval(1, 1), ra_interval(-1, 2))
#' ra_div_extended(ra_interval(1, 1), ra_interval(0, 2))
#' @seealso [ra_div()].
#' @export
ra_div_extended <- function(x, y) {
  x <- .ra_as_ivl(x)
  y <- .ra_as_ivl(y)
  n <- max(length(x), length(y))
  x <- x[rep_len(seq_len(length(x)), n)]
  y <- y[rep_len(seq_len(length(y)), n)]
  empty <- ra_is_empty(x) | ra_is_empty(y)
  nai <- ra_is_nai(x) | ra_is_nai(y)
  straddles <- !empty & !nai & y$lo <= 0 & y$hi >= 0

  plain <- ra_div(x, y, zero = "hull")
  first_lo <- plain$lo
  first_hi <- plain$hi
  second_lo <- rep(Inf, n)
  second_hi <- rep(-Inf, n)

  if (any(straddles)) {
    pieces <- .ra_div_pieces(x[straddles], y[straddles])
    first_lo[straddles] <- pieces$lo1
    first_hi[straddles] <- pieces$hi1
    second_lo[straddles] <- ifelse(pieces$second, pieces$lo2, Inf)
    second_hi[straddles] <- ifelse(pieces$second, pieces$hi2, -Inf)
  }

  dec <- .ra_prop(ifelse(straddles, "trv",
                         .ra_local_total(first_lo, first_hi, empty)),
                  x$dec, y$dec)
  pv <- .ra_prov2(ra_prov(x), ra_prov(y))
  list(first = .ra_assemble(first_lo, first_hi, dec, empty, nai, pv),
       second = .ra_assemble(second_lo, second_hi,
                             rep("trv", n), empty | second_lo > second_hi,
                             nai, pv))
}

#' @title Square, absolute value and integer powers
#' @description Operations whose interval version is tighter than the same
#'   expression written with multiplication, because the argument occurs once in
#'   the mathematics even though it occurs twice in the formula.
#' @param x An object of class \code{ra_ivl}, or a numeric vector.
#' @param p An integer scalar exponent, which may be negative.
#' @return An object of class \code{ra_ivl}.
#' @details The square of \code{[-1, 2]} is \code{[0, 4]} and not \code{[-2, 4]}
#'   as \code{x * x} gives: multiplication cannot know that the two factors are
#'   the same number, so it allows one to be negative while the other is
#'   positive. This is the dependency problem in its smallest form, and
#'   providing the operation separately is the cheapest of its mitigations.
#'
#'   Integer powers are computed by repeated squaring of intervals, so that
#'   every intermediate product carries its own outward step and the result is
#'   an enclosure by construction. The alternative, raising the endpoints with
#'   the power operator of R and widening by one step, is wrong and not merely
#'   loose: for an integer exponent R multiplies repeatedly, so its error grows
#'   with the exponent and a single outward step stops covering it somewhere
#'   above the cube.
#'
#'   The price of doing it this way is width, and the width is bounded rather
#'   than assumed. The bound is linear in the exponent even though the number of
#'   operations is logarithmic in it, and the reason is worth stating: the
#'   relative error of each rounded operation is carried into the next and
#'   multiplied by it, so squaring one's way to the \code{p}-th power
#'   accumulates a relative error of about \code{p} times the unit roundoff,
#'   which is about \code{p} steps in units in the last place of the result.
#'   Measured here: one step at \code{p = 2}, three at \code{p = 3}, five at
#'   \code{p = 5}, nine at \code{p = 8} and fifteen at \code{p = 16}. For the
#'   exponents this package meets in practice, which are small, that is
#'   negligible against the widths involved; for a large exponent the rigorous
#'   level is the place to go.
#' @section Methodological notes:
#'   The exponent zero returns the point interval one, including for an argument
#'   containing zero, which is the convention of the standard for the
#'   integer-power operation. It is a convention and it is stated rather than
#'   assumed: the alternative reading, that zero to the zero has no value,
#'   belongs to the two-argument power and not to this one.
#'
#'   The entries for the square, the absolute value and the integer power are
#'   in Table 4.1 of IEEE Std 1788.1-2017; chapter 5 of Moore et al. (2009)
#'   treats the dependency these forms avoid.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Institute of Electrical and Electronics Engineers. (2018). IEEE standard for
#'   interval arithmetic (simplified) (IEEE Std 1788.1-2017).
#'   https://doi.org/10.1109/IEEESTD.2018.8277144
#'
#'   Moore, R. E., Kearfott, R. B., & Cloud, M. J. (2009). Introduction to interval
#'   analysis. Society for Industrial and Applied Mathematics.
#'   https://doi.org/10.1137/1.9780898717716
#' @examples
#' ra_sqr(ra_interval(-1, 2))
#' ra_interval(-1, 2) * ra_interval(-1, 2)
#' ra_abs(ra_interval(-3, 1))
#' ra_pown(ra_interval(2, 3), 3L)
#' ra_pown(ra_interval(2, 3), -1L)
#' @seealso [Ops.ra_ivl()].
#' @name ra_powers
NULL

#' @rdname ra_powers
#' @export
ra_sqr <- function(x) {
  x <- .ra_as_ivl(x)
  empty <- ra_is_empty(x)
  nai <- ra_is_nai(x)
  mg <- pmax(abs(x$lo), abs(x$hi))
  mi <- pmin(abs(x$lo), abs(x$hi))
  mi[x$lo <= 0 & x$hi >= 0] <- 0
  lo <- ra_pred(mi * mi)
  hi <- ra_succ(mg * mg)
  lo[!empty & !nai & lo < 0] <- 0
  local <- .ra_local_total(lo, hi, empty)
  .ra_assemble(lo, hi, .ra_prop(local, x$dec), empty, nai, ra_prov(x))
}

#' @rdname ra_powers
#' @export
ra_abs <- function(x) {
  x <- .ra_as_ivl(x)
  empty <- ra_is_empty(x)
  nai <- ra_is_nai(x)
  hi <- pmax(abs(x$lo), abs(x$hi))
  lo <- pmin(abs(x$lo), abs(x$hi))
  lo[x$lo <= 0 & x$hi >= 0] <- 0
  local <- .ra_local_total(lo, hi, empty)
  .ra_assemble(lo, hi, .ra_prop(local, x$dec), empty, nai, ra_prov(x))
}

#' @rdname ra_powers
#' @export
ra_pown <- function(x, p) {
  x <- .ra_as_ivl(x)
  if (!is.numeric(p) || length(p) != 1L || is.na(p) || p != trunc(p)) {
    ra_stop("bad_argument",
            "`p` must be a single integer-valued number.")
  }
  p <- as.integer(p)
  n <- length(x)
  if (p == 0L) {
    out <- ra_interval(rep(1, n), rep(1, n))
    out$dec <- .ra_prop(rep("com", n), x$dec)
    out$dec[ra_is_empty(x)] <- "trv"
    return(.ra_assemble(out$lo, out$hi, out$dec, ra_is_empty(x),
                        prov = ra_prov(x),
                        ra_is_nai(x)))
  }
  q <- abs(p)
  ## Repeated squaring on intervals, with the parity of the exponent respected
  ## by the square operation rather than by a case analysis on the endpoints.
  acc <- NULL
  base <- x
  e <- q
  while (e > 0L) {
    if (bitwAnd(e, 1L) == 1L) {
      acc <- if (is.null(acc)) base else ra_mul(acc, base)
    }
    e <- e %/% 2L
    if (e > 0L) base <- ra_sqr(base)
  }
  ## Repeated squaring loses the parity information that x^even is nonnegative
  ## and that x^odd is monotone, so the tight endpoints are recomputed and
  ## intersected with what the squaring produced; both are valid enclosures.
  tight <- .ra_pown_tight(x, q)
  acc <- ra_intersect(acc, tight)
  ## The intersection is a set operation and the standard decorates those trv.
  ## That is right for the operation and wrong for this result, which is an
  ## interval extension of a point function and carries the decoration that
  ## function earns; the intersection here is an internal tightening step and
  ## not something the caller asked for.
  empty <- ra_is_empty(x)
  nai <- ra_is_nai(x)
  local <- .ra_local_total(acc$lo, acc$hi, empty)
  if (p < 0L) local[!empty & !nai & x$lo <= 0 & x$hi >= 0] <- "trv"
  acc <- .ra_assemble(acc$lo, acc$hi, .ra_prop(local, x$dec), empty, nai,
                      ra_prov(x))
  if (p > 0L) return(acc)
  out <- ra_div(ra_interval(rep(1, n), rep(1, n)), acc)
  .ra_assemble(out$lo, out$hi, .ra_prop(local, x$dec), empty, nai,
               ra_prov(x))
}

## The power of a point, as an interval, by repeated squaring. The endpoints of
## a monotone power cannot be computed with the power operator of R and then
## widened by one step: for an integer exponent R multiplies repeatedly, so the
## error grows with the exponent and a single outward step stops covering it
## somewhere above the cube. Doing the repeated multiplication in interval
## arithmetic instead makes every intermediate carry its own step, and the
## result is an enclosure by construction with no accuracy assumption at all.
.ra_pow_point <- function(v, q) {
  v <- as.numeric(v)
  base <- structure(list(lo = v, hi = v,
                         dec = rep("com", length(v)),
                         prov = rep("theorem", length(v))), class = "ra_ivl")
  acc <- NULL
  e <- q
  while (e > 0L) {
    if (bitwAnd(e, 1L) == 1L) {
      acc <- if (is.null(acc)) base else ra_mul(acc, base)
    }
    e <- e %/% 2L
    if (e > 0L) base <- ra_sqr(base)
  }
  acc
}

.ra_pown_tight <- function(x, q) {
  empty <- ra_is_empty(x)
  nai <- ra_is_nai(x)
  masked <- empty | nai
  if (q %% 2L == 1L) {
    a <- x$lo
    b <- x$hi
    a[masked] <- 0
    b[masked] <- 0
    lo <- .ra_pow_point(a, q)$lo
    hi <- .ra_pow_point(b, q)$hi
  } else {
    mg <- pmax(abs(x$lo), abs(x$hi))
    mi <- pmin(abs(x$lo), abs(x$hi))
    mi[x$lo <= 0 & x$hi >= 0] <- 0
    mi[masked] <- 0
    mg[masked] <- 0
    lo <- .ra_pow_point(mi, q)$lo
    hi <- .ra_pow_point(mg, q)$hi
    lo[!masked & lo < 0] <- 0
  }
  local <- .ra_local_total(lo, hi, empty)
  .ra_assemble(lo, hi, .ra_prop(local, x$dec), empty, nai, ra_prov(x))
}

#' @title Set operations on intervals
#' @description The intersection of two intervals and the interval hull of their
#'   union.
#' @param x,y Objects of class \code{ra_ivl}, or numeric vectors.
#' @return An object of class \code{ra_ivl}.
#' @details Both are exact: they need no outward step, because the endpoints of
#'   the result are endpoints of the arguments and no arithmetic is performed.
#'   The intersection of two intervals that do not meet is the empty interval,
#'   which is a value and not a failure; it is how the Newton step proves that a
#'   box contains no root.
#'
#'   The hull of the union is not the union: the union of two disjoint intervals
#'   is not an interval, and the hull fills in the gap between them. Filling in
#'   the gap is a loss of information and never a loss of validity.
#' @section Methodological notes:
#'   The standard classes these as operations that are not interval extensions
#'   of point functions and prescribes that their results carry the \code{trv}
#'   decoration, because no single decoration would be informative in every
#'   context in which they are used. The package follows that, and a caller who
#'   can justify a stronger decoration in a particular use is expected to attach
#'   it deliberately rather than receive it by default.
#'
#'   The classification and its decoration rule are subclauses 4.5.4 and 5.7.1
#'   of IEEE Std 1788.1-2017.
#' @section Dependencies:
#'   Base R only.
#' @references
#'   Institute of Electrical and Electronics Engineers. (2018). IEEE standard for
#'   interval arithmetic (simplified) (IEEE Std 1788.1-2017).
#'   https://doi.org/10.1109/IEEESTD.2018.8277144
#' @examples
#' ra_intersect(ra_interval(0, 2), ra_interval(1, 3))
#' ra_is_empty(ra_intersect(ra_interval(0, 1), ra_interval(2, 3)))
#' ra_hull(ra_interval(0, 1), ra_interval(2, 3))
#' @seealso [ra_div_extended()], which produces the pieces these combine.
#' @name ra_sets
NULL

#' @rdname ra_sets
#' @export
ra_intersect <- function(x, y) {
  x <- .ra_as_ivl(x)
  y <- .ra_as_ivl(y)
  n <- max(length(x), length(y))
  x <- x[rep_len(seq_len(length(x)), n)]
  y <- y[rep_len(seq_len(length(y)), n)]
  nai <- ra_is_nai(x) | ra_is_nai(y)
  lo <- pmax(x$lo, y$lo)
  hi <- pmin(x$hi, y$hi)
  empty <- !nai & lo > hi
  .ra_assemble(lo, hi, rep("trv", n), empty, nai,
               .ra_prov2(ra_prov(x), ra_prov(y)))
}

#' @rdname ra_sets
#' @export
ra_hull <- function(x, y) {
  x <- .ra_as_ivl(x)
  y <- .ra_as_ivl(y)
  n <- max(length(x), length(y))
  x <- x[rep_len(seq_len(length(x)), n)]
  y <- y[rep_len(seq_len(length(y)), n)]
  nai <- ra_is_nai(x) | ra_is_nai(y)
  ex <- ra_is_empty(x)
  ey <- ra_is_empty(y)
  lo <- pmin(x$lo, y$lo)
  hi <- pmax(x$hi, y$hi)
  lo[ex] <- y$lo[ex]
  hi[ex] <- y$hi[ex]
  lo[ey] <- x$lo[ey]
  hi[ey] <- x$hi[ey]
  .ra_assemble(lo, hi, rep("trv", n), ex & ey, nai,
               .ra_prov2(ra_prov(x), ra_prov(y)))
}
