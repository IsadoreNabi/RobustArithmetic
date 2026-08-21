## The interval Newton operator and the paving engine.
##
## This file answers one question with three permitted words: where are the
## roots of an expression over a window. "Unique" is a certificate of
## existence and uniqueness by theorem; absence over a box is a certificate
## too; and what neither certificate reaches is "not excludable", an
## abstention that names its budget. There is no fourth word, and in
## particular there is no silence: an exhausted budget, a multiple root, two
## roots closer than the resolution -- all of them land in the abstention.
##
## The engine pavings at the fast level and never lets a card word leave it:
## with the backend present, every verdict below is re-verified at the
## rigorous level before the object is built, and the provenance the object
## carries says which of the two words backs it. That division of labour --
## fast enclosures inside the search, a theorem behind every printed word --
## is the ruling of the author on the architecture of the two levels, made
## structure.

#' @title One step of the interval Newton operator
#' @description Applies one Hansen-Sengupta step to a box: the midpoint is
#'   evaluated, the derivative is enclosed over the box, and the Newton image
#'   through extended division is intersected with the box.
#' @param e A call or expression over the closed operator table.
#' @param x An object of class \code{ra_ivl} of length one: the box.
#' @param var A character scalar naming the variable of \code{e}.
#' @param env A named list of values, interval or numeric, for the other
#'   symbols of \code{e}.
#' @param level The evaluation level, as in [ra_elem()].
#' @param precision The precision of the rigorous level, in bits.
#' @return An object of class \code{ra_ivl} with zero, one or two elements:
#'   the pieces of the Newton image intersected with the box. Zero pieces
#'   demonstrate the box holds no root. The attribute \code{ra_contracted} is
#'   \code{TRUE} when there is a single piece strictly interior to the box,
#'   and the attribute \code{ra_dspan} is \code{TRUE} when the enclosed
#'   derivative contains zero.
#' @details The step is the Hansen-Sengupta form: the extended division
#'   returns one or two pieces when the derivative straddles zero, and each
#'   piece is intersected with the box. A single piece strictly interior to
#'   the box, together with a derivative enclosure excluding zero, is the
#'   certificate that the box holds exactly one root: existence by the
#'   fixed-point argument, uniqueness by monotonicity.
#' @section Methodological notes:
#'   The uniqueness hypothesis stated here is sufficient and not minimal: the
#'   reference theorem derives the regularity of the derivative from the
#'   strict interior inclusion rather than assuming it. In one dimension the
#'   two formulations are operationally equivalent, and the package asserts
#'   the stronger antecedent because it is the one the certificate consumer
#'   can read off the returned attributes.
#' @section Dependencies:
#'   Base R at the fast level; the rigorous level requires 'Rmpfr'.
#' @references
#'   Hansen, E., & Walster, G. W. (2004). Global optimization using interval
#'   analysis (2nd ed.). Marcel Dekker.
#'
#'   Neumaier, A. (1990). Interval methods for systems of equations. Cambridge
#'   University Press. https://doi.org/10.1017/CBO9780511526473
#' @examples
#' ra_newton_step(quote(exp(x) - 2), ra_interval(0, 1))
#' @seealso [ra_solve()] for the paving that drives the step,
#'   [ra_div_extended()] for the division underneath it.
#' @export
ra_newton_step <- function(e, x, var = "x", env = list(),
                           level = c("fast", "rigorous"),
                           precision = ra_precision_ladder()[1L]) {
  level <- match.arg(level)
  x <- .ra_as_ivl(x)
  if (length(x) != 1L) {
    ra_stop("bad_argument", "`x` must be a single interval box.")
  }
  de <- stats::D(e, var)
  m <- ra_mid(x)
  fm <- ra_enclose_expr(e, ra_interval(m, m), var = var, env = env,
                        level = level, precision = precision)
  fp <- ra_enclose_expr(de, x, var = var, env = env,
                        level = level, precision = precision)
  dspan <- ra_inf(fp) <= 0 && ra_sup(fp) >= 0

  if (dspan && ra_inf(fm) <= 0 && ra_sup(fm) >= 0) {
    ## no reduction is available: the midpoint may be a root and the
    ## derivative offers no direction; the caller bisects
    out <- x
    attr(out, "ra_contracted") <- FALSE
    attr(out, "ra_dspan") <- dspan
    return(out)
  }

  q <- ra_div_extended(fm, fp)
  pieces <- list()
  for (piece in list(q$first, q$second)) {
    if (ra_is_empty(piece)) next
    n <- ra_intersect(ra_sub(ra_interval(m, m), piece), x)
    if (!ra_is_empty(n)) pieces[[length(pieces) + 1L]] <- n
  }
  out <- if (length(pieces) == 0L) {
    ra_interval(numeric(0), numeric(0))
  } else if (length(pieces) == 1L) {
    pieces[[1L]]
  } else {
    c(pieces[[1L]], pieces[[2L]])
  }
  contracted <- length(pieces) == 1L && !dspan &&
    ra_inf(out) > ra_inf(x) && ra_sup(out) < ra_sup(x)
  attr(out, "ra_contracted") <- contracted
  attr(out, "ra_dspan") <- dspan
  out
}

## The paving engine. Kept apart from the public wrapper so the tests can
## turn the inflation step off and prove the design lesson it answers: a
## simple root on a box boundary is never strictly interior to anything, and
## contraction alone cannot certify it.
.ra_solve_impl <- function(e, over, var = "x", env = list(),
                           min_width = NULL, max_boxes = 10000L,
                           tol = 1e-10, inflate = TRUE,
                           precision = ra_precision_ladder()[1L]) {
  ra_check_expr(e)
  over <- .ra_as_ivl(over)
  if (length(over) != 1L || ra_is_empty(over) || !all(is.finite(c(over$lo, over$hi)))) {
    ra_stop("bad_argument", "`over` must be a single bounded nonempty interval.")
  }
  if (is.null(min_width)) min_width <- 1e-6 * ra_wid(over)
  max_boxes <- as.integer(max_boxes)[1L]
  de <- stats::D(e, var)

  enc <- function(expr, X) {
    ra_enclose_expr(expr, X, var = var, env = env, level = "fast",
                    precision = precision)
  }
  contains0 <- function(iv) ra_inf(iv) <= 0 && ra_sup(iv) >= 0

  queue <- list(over)
  uniques <- list()
  noexcl <- list()
  excluded <- list()
  n_proc <- 0L

  while (length(queue) > 0L && n_proc < max_boxes) {
    X <- queue[[1L]]
    queue <- queue[-1L]
    n_proc <- n_proc + 1L

    fX <- enc(e, X)
    if (!contains0(fX)) {
      excluded[[length(excluded) + 1L]] <- X
      next
    }
    N <- ra_newton_step(e, X, var = var, env = env)
    if (length(N) == 0L) {
      excluded[[length(excluded) + 1L]] <- X
      next
    }
    if (isTRUE(attr(N, "ra_contracted"))) {
      Y <- .ra_polish(e, N, var, env, tol)
      uniques[[length(uniques) + 1L]] <- Y
      next
    }
    if (ra_wid(X) < min_width) {
      noexcl[[length(noexcl) + 1L]] <- X
      next
    }
    ## split; each piece that did not shrink enough is bisected leaving the
    ## midpoint candidate in the LARGER part, the finer cut of the reference
    ## algorithm (the candidate that resisted contraction stays interior to a
    ## piece instead of landing on a boundary again and again)
    for (k in seq_len(length(N))) {
      Z <- N[k]
      if (ra_wid(Z) <= 0.75 * ra_wid(X)) {
        queue[[length(queue) + 1L]] <- Z
      } else {
        s <- ra_inf(Z) + (2 / 3) * ra_wid(Z)
        queue[[length(queue) + 1L]] <- ra_interval(ra_inf(Z), s)
        queue[[length(queue) + 1L]] <- ra_interval(s, ra_sup(Z))
      }
    }
  }
  exhausted <- n_proc >= max_boxes && length(queue) > 0L
  ## nothing falls silent: what the budget did not reach is not excludable
  for (X in queue) noexcl[[length(noexcl) + 1L]] <- X

  ## fuse adjacent non-excludable boxes into clusters
  noexcl <- .ra_fuse(noexcl, 4 * min_width)

  ## the verification of candidates by epsilon inflation: fuse the clusters,
  ## inflate so the candidate passes to the interior, and certify there
  if (inflate && length(noexcl) > 0L) {
    kept <- list()
    for (B in noexcl) {
      got <- .ra_certify_inflated(e, de, B, var, env, min_width, tol,
                                  precision)
      if (is.null(got)) kept[[length(kept) + 1L]] <- B
      else uniques[[length(uniques) + 1L]] <- got
    }
    noexcl <- kept
  }
  uniques <- .ra_fuse(uniques, 0)

  list(e = e, var = var, env = env, window = over,
       unique = .ra_bind(uniques), not_excludable = .ra_bind(noexcl),
       excluded = .ra_bind(excluded), boxes_processed = n_proc,
       max_boxes = max_boxes, exhausted = exhausted,
       min_width = min_width, tol = tol)
}

## Iterate the contracting step to tighten a certified enclosure. The width
## must shrink at every pass or the loop stops; sixty passes bound it.
.ra_polish <- function(e, Y, var, env, tol) {
  for (k in 1:60) {
    N <- ra_newton_step(e, Y, var = var, env = env)
    if (length(N) != 1L) break
    NN <- ra_intersect(N, Y)
    if (ra_is_empty(NN) || ra_wid(NN) >= ra_wid(Y)) break
    Y <- NN
    if (ra_wid(Y) < tol) break
  }
  attr(Y, "ra_contracted") <- NULL
  attr(Y, "ra_dspan") <- NULL
  Y
}

## Certify one fused cluster by epsilon inflation: three rounds of inflating
## beyond the cluster and asking for a strictly interior Newton image with a
## derivative excluding zero. A multiple root keeps its derivative astride
## zero and stays honestly non-excludable; NULL says so.
.ra_certify_inflated <- function(e, de, B, var, env, min_width, tol,
                                 precision) {
  Y <- B
  for (round in 1:3) {
    mid <- ra_mid(Y)
    rad <- ra_wid(Y) / 2
    Y <- ra_interval(ra_pred(mid - 1.1 * rad - min_width),
                     ra_succ(mid + 1.1 * rad + min_width))
    N <- ra_newton_step(e, Y, var = var, env = env)
    if (isTRUE(attr(N, "ra_dspan"))) return(NULL)
    if (length(N) == 1L &&
        ra_inf(N) > ra_inf(Y) && ra_sup(N) < ra_sup(Y)) {
      return(.ra_polish(e, N, var, env, tol))
    }
  }
  NULL
}

## Fuse a list of length-one intervals whose gaps are at most `gap`.
.ra_fuse <- function(boxes, gap) {
  if (length(boxes) <= 1L) return(boxes)
  lo <- vapply(boxes, ra_inf, numeric(1))
  ord <- order(lo)
  boxes <- boxes[ord]
  out <- list(boxes[[1L]])
  for (B in boxes[-1L]) {
    L <- out[[length(out)]]
    if (ra_inf(B) <= ra_sup(L) + gap) {
      out[[length(out)]] <- ra_interval(min(ra_inf(L), ra_inf(B)),
                                        max(ra_sup(L), ra_sup(B)))
    } else {
      out[[length(out) + 1L]] <- B
    }
  }
  out
}

## Bind a list of length-one intervals into one ra_ivl vector.
.ra_bind <- function(boxes) {
  if (length(boxes) == 0L) return(ra_interval(numeric(0), numeric(0)))
  do.call(c, boxes)
}

#' @title Certified enclosure of the roots of an expression over a window
#' @description Paves the window, drives the interval Newton operator over
#'   the paving, and returns every root region with one of three words:
#'   \code{unique}, a certificate of exactly one root; absence, demonstrated
#'   over everything excluded; or \code{not excludable}, the abstention.
#' @param e A call or expression over the closed operator table.
#' @param over An object of class \code{ra_ivl} of length one: the window.
#' @param var A character scalar naming the variable of \code{e}.
#' @param env A named list of values for the other symbols of \code{e}.
#' @param min_width The width below which a box that resists every test
#'   becomes an abstention. The default is declared, not calibrated: one
#'   millionth of the window width.
#' @param max_boxes The budget of the paving, in boxes. At the budget the
#'   engine stops and says so; what it did not reach is reported not
#'   excludable, never dropped.
#' @param tol The width at which a certified enclosure stops being tightened.
#' @param precision The starting precision of the rigorous verification, in
#'   bits; it climbs the declared ladder when a verification cannot decide.
#' @return An object of class \code{ra_paving}: a list with the certified
#'   roots (\code{unique}), the abstentions (\code{not_excludable}), the
#'   excluded cover (\code{excluded}), the budget spent, and the provenance
#'   of the verdicts. Its \code{print()} is the card.
#' @details The search runs at the fast level. No card word leaves it: when
#'   the multiprecision backend is present, every uniqueness certificate is
#'   re-established at the rigorous level, where the enclosure is a theorem,
#'   and every excluded box is re-excluded there; a verification that cannot
#'   decide climbs the precision ladder and, at the top, moves its box to the
#'   abstention with the budget in the message. When the backend is absent
#'   the verdicts keep the measured provenance of the fast level and the card
#'   labels them so.
#'
#'   The certificate behind \code{unique} is the Hansen-Sengupta one: a
#'   Newton image strictly interior to its box with a derivative enclosure
#'   excluding zero proves exactly one root there. Boxes where no certificate
#'   and no exclusion is reached are fused, inflated so that a root sitting
#'   exactly on a box boundary passes to the interior, and certified there;
#'   without that step every simple root on a representable boundary point
#'   would remain uncertifiable forever, which is the measured lesson this
#'   design carries from its probe.
#' @section Methodological notes:
#'   A multiple root has no certificate by this route: its derivative
#'   enclosure contains zero, no theorem applies, and pretending otherwise
#'   would manufacture a verdict. It stays not excludable, tight around the
#'   root. Likewise two roots closer than \code{min_width} cannot be
#'   separated and produce the abstention rather than a guess. The split of
#'   a box that resists contraction leaves the resisting candidate in the
#'   larger part, which is the finer cut of the reference algorithm.
#' @section Dependencies:
#'   Base R at the fast level. The rigorous verification requires 'Rmpfr',
#'   which is in \code{Suggests}; without it the verdicts are labeled with
#'   their measured provenance.
#' @references
#'   Hansen, E., & Walster, G. W. (2004). Global optimization using interval
#'   analysis (2nd ed.). Marcel Dekker.
#'
#'   Neumaier, A. (1990). Interval methods for systems of equations. Cambridge
#'   University Press. https://doi.org/10.1017/CBO9780511526473
#'
#'   Rump, S. M. (2010). Verification methods: Rigorous results using
#'   floating-point arithmetic. Acta Numerica, 19, 287-449.
#'   https://doi.org/10.1017/S096249291000005X
#' @examples
#' ra_solve(quote(x^2 - 2), ra_interval(0, 3))
#' @seealso [ra_newton_step()] for one step of the operator,
#'   [ra_enclose_expr()] for the enclosures underneath.
#' @export
ra_solve <- function(e, over, var = "x", env = list(), min_width = NULL,
                     max_boxes = 10000L, tol = 1e-10,
                     precision = ra_precision_ladder()[1L]) {
  res <- .ra_solve_impl(e, over, var = var, env = env,
                        min_width = min_width, max_boxes = max_boxes,
                        tol = tol, inflate = TRUE, precision = precision)
  .ra_finish_paving(res, precision)
}

## The rigorous verification pass and the assembly of the ra_paving object.
## This is where the ruling on the two levels becomes structure: no word of
## the card leaves the fast level when there is a rigorous level to hold it.
.ra_finish_paving <- function(res, precision) {
  verified <- ra_has_mpfr()
  budget_note <- character(0)
  if (verified) {
    enc_r <- function(expr, X, p) {
      ra_enclose_expr(expr, X, var = res$var, env = res$env,
                      level = "rigorous", precision = p)
    }
    de <- stats::D(res$e, res$var)
    ladder <- ra_precision_ladder()
    ladder <- ladder[ladder >= as.integer(precision)]

    kept <- list()
    if (length(res$unique) > 0L) {
      for (i in seq_len(length(res$unique))) {
        Y <- res$unique[i]
        ## re-establish the certificate on the SAME inflation the fast path
        ## certified on. The polished enclosure is far tighter than the noise
        ## floor of the binary64 kernel arithmetic of the expression layer,
        ## and climbing the precision ladder cannot lower that floor, so a
        ## verification on the polished box would fail for a reason that has
        ## nothing to do with the root. The rigorous Newton image N is what
        ## the theorem certifies, and N is what the card reports.
        rad <- ra_wid(Y) / 2
        Y2 <- ra_interval(
          ra_pred(ra_mid(Y) - 1.1 * rad - res$min_width),
          ra_succ(ra_mid(Y) + 1.1 * rad + res$min_width))
        ok <- NULL
        for (p in ladder) {
          fp <- enc_r(de, Y2, p)
          if (ra_inf(fp) <= 0 && ra_sup(fp) >= 0) break
          m <- ra_mid(Y2)
          fm <- enc_r(res$e, ra_interval(m, m), p)
          q <- ra_div_extended(fm, fp)
          N <- ra_intersect(ra_sub(ra_interval(m, m), q$first), Y2)
          if (!ra_is_empty(N) && ra_inf(N) > ra_inf(Y2) &&
              ra_sup(N) < ra_sup(Y2)) {
            ok <- N
            break
          }
        }
        if (is.null(ok)) {
          res$not_excludable <- c(res$not_excludable, Y)
          budget_note <- c(budget_note,
                           paste0("a uniqueness verification reached no ",
                                  "verdict at this budget (",
                                  ladder[length(ladder)], " bits)"))
        } else {
          kept[[length(kept) + 1L]] <- ok
        }
      }
    }
    res$unique <- if (length(kept)) do.call(c, kept) else
      ra_interval(numeric(0), numeric(0))
    ## re-exclude every excluded box rigorously; the rigorous enclosure of a
    ## truly root-free box excludes zero at some rung, and one that does not
    ## is honestly moved to the abstention
    if (length(res$excluded) > 0L) {
      still <- rep(TRUE, length(res$excluded))
      for (i in seq_len(length(res$excluded))) {
        L <- res$excluded[i]
        ok <- FALSE
        for (p in ladder) {
          fL <- enc_r(res$e, L, p)
          if (!(ra_inf(fL) <= 0 && ra_sup(fL) >= 0)) {
            ok <- TRUE
            break
          }
        }
        if (!ok) {
          still[i] <- FALSE
          res$not_excludable <- c(res$not_excludable, L)
          budget_note <- c(budget_note,
                           paste0("an exclusion verification reached no ",
                                  "verdict at this budget (",
                                  ladder[length(ladder)], " bits)"))
        }
      }
      res$excluded <- res$excluded[which(still)]
    }
  }
  prov <- if (verified) "theorem" else "measured"
  if (length(res$unique) > 0L) {
    res$unique$prov <- rep(prov, length(res$unique))
  }
  res$verified <- verified
  res$budget_note <- budget_note
  structure(res, class = "ra_paving")
}

#' @title Show a paving of certified roots
#' @description The card of a paving: its window, its certified roots with
#'   their provenance, its abstentions, whether absence holds on the rest,
#'   and the budget spent -- each verdict a word, never a silence.
#' @param x,object An object of class \code{ra_paving}.
#' @param row.names,optional,... Passed along as in the generics.
#' @return \code{print()} returns its argument invisibly;
#'   \code{format()} a character vector; \code{as.data.frame()} a data frame
#'   with one row per verdict and columns \code{lo}, \code{hi},
#'   \code{verdict} and \code{prov}; \code{summary()} an object of class
#'   \code{ra_paving_summary} with its own \code{print()}.
#' @details The card never prints a verdict without its provenance: verdicts
#'   re-verified at the rigorous level say theorem, and verdicts that could
#'   not be (because the backend is absent) say measured, loudly. Absence
#'   over the remainder of the window is only claimed when the paving
#'   completed within its budget.
#' @section Methodological notes:
#'   These methods are written together with the class rather than added
#'   later, because a class whose vector behaviour arrives in a second pass
#'   spends the interval between the two passes producing plausible wrong
#'   numbers.
#' @section Dependencies:
#'   Base R.
#' @references
#'   Wickham, H. (2019). Advanced R (2nd ed.). Chapman & Hall/CRC.
#'   https://doi.org/10.1201/9781351201315
#' @examples
#' print(ra_solve(quote(x^2 - 2), ra_interval(0, 3)))
#' @seealso [ra_solve()].
#' @name ra_paving_show
NULL

#' @rdname ra_paving_show
#' @export
format.ra_paving <- function(x, ...) {
  prov_word <- if (x$verified) "theorem" else {
    "measured -- package 'Rmpfr' absent, verdicts NOT re-verified rigorously"
  }
  out <- c(
    paste0("<ra_paving> roots of ", deparse(x$e), " over ",
           format(x$window)),
    paste0("  unique roots: ", length(x$unique),
           if (length(x$unique)) paste0("  (provenance: ", prov_word, ")")
           else ""))
  if (length(x$unique)) {
    out <- c(out, paste0("    ", format(x$unique), "  unique"))
  }
  out <- c(out, paste0("  not excludable: ", length(x$not_excludable)))
  if (length(x$not_excludable)) {
    out <- c(out, paste0("    ", format(x$not_excludable),
                         "  not excludable"))
  }
  if (!x$exhausted) {
    out <- c(out, paste0("  absence demonstrated over the rest of the ",
                         "window (", length(x$excluded), " excluded boxes",
                         if (x$verified) ", re-verified rigorously" else
                           ", measured provenance", ")"))
    out <- c(out, paste0("  budget: ", x$boxes_processed, " of ",
                         x$max_boxes, " boxes"))
  } else {
    out <- c(out, paste0("  budget EXHAUSTED at ", x$max_boxes, " boxes; ",
                         "unprocessed boxes are reported not excludable ",
                         "and absence is NOT claimed"))
  }
  for (note in unique(x$budget_note)) out <- c(out, paste0("  ", note))
  out
}

#' @rdname ra_paving_show
#' @export
print.ra_paving <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' @rdname ra_paving_show
#' @export
as.data.frame.ra_paving <- function(x, row.names = NULL, optional = FALSE,
                                    ...) {
  n_u <- length(x$unique)
  n_n <- length(x$not_excludable)
  data.frame(
    lo = c(x$unique$lo, x$not_excludable$lo),
    hi = c(x$unique$hi, x$not_excludable$hi),
    verdict = c(rep("unique", n_u), rep("not excludable", n_n)),
    prov = c(ra_prov(x$unique), rep("measured", n_n)),
    row.names = row.names, stringsAsFactors = FALSE)
}

#' @rdname ra_paving_show
#' @export
summary.ra_paving <- function(object, ...) {
  structure(list(n_unique = length(object$unique),
                 n_not_excludable = length(object$not_excludable),
                 n_excluded = length(object$excluded),
                 exhausted = object$exhausted,
                 verified = object$verified,
                 boxes = object$boxes_processed),
            class = "ra_paving_summary")
}

#' @rdname ra_paving_show
#' @export
print.ra_paving_summary <- function(x, ...) {
  cat("Unique roots: ", x$n_unique, "  Not excludable: ",
      x$n_not_excludable, "\n", sep = "")
  cat("Excluded boxes: ", x$n_excluded, "  Boxes processed: ", x$boxes,
      "\n", sep = "")
  cat("Budget exhausted: ", if (x$exhausted) "yes" else "no",
      "  Rigorously verified: ", if (x$verified) "yes" else "no", "\n",
      sep = "")
  invisible(x)
}
