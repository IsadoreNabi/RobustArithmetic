## Fixed point certificates over a norm ball, and the two spectral assemblers
## that let a caller build their inputs without factorising anything.
##
## This file answers one question with two permitted words: does the map send
## the ball into itself, and is it a contraction there. The two are certified
## SEPARATELY and they are not the same statement -- confinement certifies
## enclosure and existence, and says nothing about what happens inside; the
## contraction adds uniqueness and convergence. A refusal is not a third word:
## the hypotheses are sufficient and not necessary, so a map this file declines
## to certify may still have a fixed point in the ball. There is no word of
## demonstrated absence here, and that is a declared non-objective.
##
## The whole certificate is a scalar inequality. That is the point of the
## design: a fixed point in R^n is certified without interval matrices, without
## factorisations and without an interval spectral decomposition, because the
## norm collapses the dimension into three numbers the caller can bound by any
## means they can defend.

## The upper bound a certificate consumes: intervals are taken at their
## supremum, because everything this file proves is proved against the worst
## case the caller admits.
.ra_upper <- function(x, nombre) {
  if (inherits(x, "ra_ivl")) {
    if (length(x$lo) != 1L) {
      ra_stop("bad_argument", sprintf("`%s` must be a single interval.", nombre))
    }
    v <- x$hi
    p <- ra_prov(x)
  } else if (is.numeric(x) && length(x) == 1L) {
    v <- as.numeric(x)
    p <- "theorem"
  } else {
    ra_stop("bad_argument",
            sprintf("`%s` must be a single numeric or a single ra_ivl.", nombre))
  }
  if (is.na(v) || !is.finite(v) || v < 0) {
    ra_stop("bad_argument",
            sprintf("`%s` must be a finite non-negative upper bound.", nombre))
  }
  list(v = v, prov = p)
}

## The minimal certifiable radius, rounded so that it is never too small: the
## residual upwards, the 1 - L downwards. Returns NA when no radius can be
## certified at this precision, and the reason why.
##
## WHY THE INEQUALITY IS NOT RE-EVALUATED. (T4) makes `r >= rho/(1-L)`
## EQUIVALENT to `L r + rho <= r`, so comparing against this radius decides the
## Lipschitz route exactly. Evaluating `L r + rho <= r` in floating point
## instead would round its left side up twice and refuse cases that hold with
## equality -- measured: rho = 0.2, L = 0.5, r = 0.4, where the three doubles
## satisfy the inequality EXACTLY and two successors break it. That refusal is
## conservative and therefore not unsound, but it is a false negative, and a
## false negative on the boundary is what makes a certificate look weaker than
## its theorem.
.ra_minimal_radius <- function(rho_v, L_v) {
  if (is.na(L_v)) return(list(r = NA_real_, reason = ""))
  if (rho_v == 0 && L_v <= 1) {
    ## The centre is already a fixed point: the degenerate ball is carried into
    ## itself by any map that fixes it, contraction or not.
    return(list(r = 0, reason = ""))
  }
  if (L_v >= 1) {
    return(list(r = NA_real_,
                reason = sprintf("L = %.17g is not below one, so there is no contraction.", L_v)))
  }
  den <- ra_pred(1 - L_v)
  if (den <= 0) {
    return(list(r = NA_real_, reason = sprintf(
      "1 - L rounds to zero at L = %.17g: no radius can be certified at this precision.", L_v)))
  }
  r <- ra_succ(rho_v / den)
  if (!is.finite(r)) {
    return(list(r = NA_real_,
                reason = "the minimal radius overflows: no radius can be certified."))
  }
  list(r = r, reason = "")
}

#' @title Certify a fixed point over a ball in a norm
#' @description Certifies, from three scalar upper bounds, that a continuous
#'   map sends a closed ball into itself (confinement, and hence existence of
#'   a fixed point by Brouwer) and, separately, that it is a contraction there
#'   (uniqueness and convergence by Banach).
#' @param rho An upper bound on the residual at the centre,
#'   \code{||Phi(c) - c||}, as a numeric of length one or an \code{ra_ivl}.
#' @param lipschitz An upper bound on a Lipschitz constant of \code{Phi} over
#'   the ball, in the same norm. Optional: without it there is no contraction
#'   verdict and no minimal radius, and \code{radius} together with
#'   \code{image_radius} must be supplied.
#' @param radius The radius of the ball to verify. When \code{NULL} and
#'   \code{lipschitz} is below one, the minimal certifiable radius
#'   \code{rho / (1 - L)} is computed instead.
#' @param image_radius An optional upper bound on
#'   \code{sup ||Phi(x) - c||} over the ball: the direct route to confinement,
#'   which needs no Lipschitz constant and is genuinely weaker than
#'   contraction.
#' @param norm A character label naming the norm the three bounds are measured
#'   in. It is carried, never checked: see the details.
#' @return An object of class \code{ra_certificate}, a list with the logical
#'   verdicts \code{confined} and \code{contraction}, the route that decided
#'   the confinement, the certified \code{radius}, the \code{error_bound} on
#'   the centre, the bounds used, the norm label, the provenance and, when a
#'   verdict is withheld, the \code{reason}.
#' @details The three bounds must all be measured in the SAME norm, and the
#'   package cannot check that: the label travels with the object and the
#'   responsibility is the caller's. Mixing norms silently would be a mode of
#'   failure indistinguishable from a valid certificate at run time.
#'
#'   The Lipschitz constant must hold over the WHOLE ball and not at its
#'   centre. A caller who bounds the derivative at the centre alone receives a
#'   certificate that means nothing, and no arithmetic can detect it. In one
#'   dimension the package closes that loop itself:
#'   [ra_certify_fixed_point()] derives both bounds over the ball from the
#'   expression.
#'
#'   Confinement is reached by either of two theorems, and the object says
#'   which. Through the direct route, an image radius no larger than the ball
#'   radius is confinement by definition. Through the Lipschitz route, the
#'   triangle inequality gives \code{||Phi(x) - c|| <= L r + rho}, so
#'   \code{L r + rho <= r} suffices; note that with a positive residual this
#'   forces \code{L < 1}, which is why the direct route is not redundant.
#'
#'   Every comparison is evaluated with the rounding that makes an affirmative
#'   verdict provable: the left side of the confinement test is rounded up and
#'   the right side down, and the minimal radius divides an upward-rounded
#'   residual by a downward-rounded \code{1 - L}. When \code{L} is within an
#'   ulp of one that denominator can round to zero; the certificate is then
#'   withheld with its reason, never returned as an infinite radius.
#' @section Non-objectives: A refusal certifies nothing. The hypotheses are
#'   sufficient and not necessary, and there is no test of exclusion here, so
#'   this file has no word of demonstrated absence. Nothing is claimed about
#'   the basin of attraction outside the ball, about periodic orbits, or about
#'   what happens inside a confined ball that is not a contraction.
#' @references
#'   Granas, A., & Dugundji, J. (2003). Fixed point theory. Springer.
#'   https://doi.org/10.1007/978-0-387-21593-8
#'
#'   Neumaier, A. (1990). Interval methods for systems of equations. Cambridge
#'   University Press. https://doi.org/10.1017/CBO9780511526473
#'
#'   Rump, S. M. (2010). Verification methods: Rigorous results using
#'   floating-point arithmetic. Acta Numerica, 19, 287-449.
#'   https://doi.org/10.1017/S096249291000005X
#' @examples
#' ra_ball_certificate(0.2, 0.5)
#' ra_ball_certificate(0.24, 1.6, radius = 0.4, image_radius = 0.4)
#' @seealso [ra_certify_fixed_point()] for the univariate door that derives
#'   the bounds itself, [ra_gershgorin()] and [ra_spectral_sum()] for
#'   assembling them in the matrix case.
#' @export
ra_ball_certificate <- function(rho, lipschitz = NULL, radius = NULL,
                                image_radius = NULL, norm = "unspecified") {
  if (!(is.character(norm) && length(norm) == 1L && !is.na(norm))) {
    ra_stop("bad_argument", "`norm` must be a single character label.")
  }
  r_ <- .ra_upper(rho, "rho")
  prov <- r_$prov
  rho_v <- r_$v

  L_v <- NA_real_
  if (!is.null(lipschitz)) {
    l_ <- .ra_upper(lipschitz, "lipschitz")
    L_v <- l_$v
    prov <- .ra_prov2(prov, l_$prov)
  }
  img_v <- NA_real_
  if (!is.null(image_radius)) {
    i_ <- .ra_upper(image_radius, "image_radius")
    img_v <- i_$v
    prov <- .ra_prov2(prov, i_$prov)
  }
  if (is.na(L_v) && is.na(img_v)) {
    ra_stop("bad_argument",
            "Give a `lipschitz` bound, an `image_radius`, or both: with neither there is nothing to certify.")
  }
  if (!is.null(radius)) {
    if (!(is.numeric(radius) && length(radius) == 1L && is.finite(radius) && radius >= 0)) {
      ra_stop("bad_argument", "`radius` must be a single finite non-negative number.")
    }
    radius <- as.numeric(radius)
  }
  if (is.null(radius) && is.na(L_v)) {
    ra_stop("bad_argument",
            "Without a `lipschitz` bound there is no minimal radius to compute: supply `radius`.")
  }

  mr <- .ra_minimal_radius(rho_v, L_v)
  r_star <- mr$r
  reason <- mr$reason

  r_use <- if (!is.null(radius)) radius else r_star
  confined <- FALSE
  route <- NA_character_
  if (!is.na(r_use)) {
    ## TWO ROUTES, EACH ONE A THEOREM, AND THE FIRST THAT REACHES DECIDES. The
    ## direct one needs no Lipschitz constant and is genuinely weaker than the
    ## contraction; the Lipschitz one is decided against the minimal radius,
    ## which is (T4) and is exact where re-evaluating (T1) would not be.
    if (!is.na(img_v) && img_v <= r_use) {
      confined <- TRUE
      route <- "image"
    } else if (!is.na(r_star) && r_use >= r_star) {
      confined <- TRUE
      route <- "lipschitz"
    }
  }
  contraction <- isTRUE(confined) && !is.na(L_v) && L_v < 1
  if (!confined && !nzchar(reason)) {
    reason <- if (is.na(r_use)) {
      "no radius was supplied and none could be computed."
    } else {
      sprintf("the ball of radius %.17g is not carried into itself by either route.", r_use)
    }
  }
  ## The error bound on the centre is (T4) and needs the contraction: without
  ## uniqueness there may be several fixed points in the ball and the distance
  ## to "the" fixed point is not defined.
  err <- if (contraction && !is.na(r_star)) min(r_star, r_use) else NA_real_

  structure(list(confined = confined,
                 contraction = contraction,
                 route = route,
                 radius = if (confined) r_use else NA_real_,
                 error_bound = err,
                 rho = rho_v,
                 lipschitz = L_v,
                 image_radius = img_v,
                 minimal_radius = r_star,
                 norm = norm,
                 prov = prov,
                 reason = reason),
            class = "ra_certificate")
}

#' @title Certify a fixed point of a univariate expression over a ball
#' @description Derives both bounds the certificate needs -- the residual at
#'   the centre and a Lipschitz constant over the whole ball -- by interval
#'   evaluation of the expression and of its derivative, and then certifies.
#' @param e A call or expression over the closed operator table, in one
#'   variable.
#' @param centre A numeric of length one: the centre of the ball.
#' @param radius A numeric of length one: the radius of the ball.
#' @param var A character scalar naming the variable of \code{e}.
#' @param env A named list of values for the other symbols of \code{e}.
#' @param level The evaluation level, as in [ra_elem()].
#' @param precision The precision of the rigorous level, in bits.
#' @return An object of class \code{ra_certificate}, as
#'   [ra_ball_certificate()], with the norm labelled \code{"abs"}.
#' @details This is the door that closes the loop: the Lipschitz constant is
#'   the supremum of the absolute value of the enclosed derivative over the
#'   ball, so a caller cannot certify on a constant measured at the centre.
#'   The image radius is enclosed directly as well, so the confinement can be
#'   certified by the direct route when the map is not a contraction.
#'
#'   In one variable the ball is the interval \code{[c - r, c + r]}, and the
#'   three bounds are exactly what [ra_enclose_expr()] returns for the
#'   expression and for \code{stats::D} of the expression.
#' @references
#'   Granas, A., & Dugundji, J. (2003). Fixed point theory. Springer.
#'   https://doi.org/10.1007/978-0-387-21593-8
#' @examples
#' ra_certify_fixed_point(quote(x / 2 + 1), centre = 1.9, radius = 0.5)
#' @seealso [ra_ball_certificate()] for the general case,
#'   [ra_enclose_expr()] for the enclosure underneath.
#' @export
ra_certify_fixed_point <- function(e, centre, radius, var = "x", env = list(),
                                   level = c("fast", "rigorous"),
                                   precision = ra_precision_ladder()[1L]) {
  level <- match.arg(level)
  if (!(is.numeric(centre) && length(centre) == 1L && is.finite(centre))) {
    ra_stop("bad_argument", "`centre` must be a single finite number.")
  }
  if (!(is.numeric(radius) && length(radius) == 1L && is.finite(radius) && radius > 0)) {
    ra_stop("bad_argument", "`radius` must be a single finite positive number.")
  }
  bola <- ra_interval(ra_pred(centre - radius), ra_succ(centre + radius))
  cen <- ra_interval(centre, centre)

  fc <- ra_enclose_expr(e, cen, var = var, env = env, level = level,
                        precision = precision)
  rho <- ra_mag(ra_sub(fc, cen))

  fb <- ra_enclose_expr(e, bola, var = var, env = env, level = level,
                        precision = precision)
  img <- ra_mag(ra_sub(fb, cen))

  de <- stats::D(e, var)
  dfb <- ra_enclose_expr(de, bola, var = var, env = env, level = level,
                         precision = precision)
  L <- ra_mag(dfb)

  prov <- .ra_prov2(.ra_prov2(ra_prov(fc), ra_prov(fb)), ra_prov(dfb))
  cert <- ra_ball_certificate(ra_succ(rho), ra_succ(L), radius = radius,
                              image_radius = ra_succ(img), norm = "abs")
  cert$prov <- .ra_prov2(cert$prov, prov)
  cert
}

#' @title Enclose the spectrum of a symmetric matrix by Gershgorin discs
#' @description Returns an interval containing every eigenvalue of a real
#'   symmetric matrix, computed from its entries alone and without any
#'   factorisation.
#' @param A A real symmetric matrix, or the matrix of lower endpoints when
#'   \code{hi} is given.
#' @param hi An optional matrix of upper endpoints, for entries known only to
#'   an interval.
#' @param discs Logical: when \code{TRUE} the per-row discs are returned as an
#'   attribute \code{ra_discs}.
#' @return An object of class \code{ra_ivl} of length one enclosing the whole
#'   spectrum.
#' @details Every eigenvalue of a symmetric \code{A} lies in the union of the
#'   discs centred at \code{a_ii} with radius the sum of the absolute values
#'   of the off-diagonal entries of row \code{i}. The enclosure returned is
#'   the hull of those discs, computed with outward rounding, so it is a
#'   superset of the spectrum: it can widen, it cannot lose an eigenvalue.
#'
#'   On a diagonal matrix the radii are zero and the enclosure is exactly the
#'   extreme diagonal entries, which is the case where the bound is tight.
#' @references
#'   Horn, R. A., & Johnson, C. R. (2013). Matrix analysis (2nd ed.).
#'   Cambridge University Press.
#' @examples
#' ra_gershgorin(matrix(c(4, 1, 1, 3), 2, 2))
#' @seealso [ra_spectral_sum()] for combining two spectra,
#'   [ra_ball_certificate()] for what these bounds are usually assembled for.
#' @export
ra_gershgorin <- function(A, hi = NULL, discs = FALSE) {
  lo <- A
  if (is.null(hi)) hi <- A
  if (!(is.matrix(lo) && is.matrix(hi) && is.numeric(lo) && is.numeric(hi))) {
    ra_stop("bad_argument", "`A` and `hi` must be numeric matrices.")
  }
  if (nrow(lo) != ncol(lo) || !identical(dim(lo), dim(hi))) {
    ra_stop("bad_argument", "`A` must be square and `hi` of the same shape.")
  }
  if (any(!is.finite(lo)) || any(!is.finite(hi)) || any(hi < lo)) {
    ra_stop("bad_argument", "the entries must be finite with `hi` above `A`.")
  }
  ## Symmetry is a hypothesis of the theorem, not a convenience: an asymmetric
  ## matrix has complex eigenvalues and a real enclosure would be a lie.
  if (max(abs(lo - t(lo))) > 0 || max(abs(hi - t(hi))) > 0) {
    ra_stop("bad_argument",
            "`A` must be symmetric: Gershgorin over the reals needs a real spectrum.")
  }
  m <- nrow(lo)
  mag <- pmax(abs(lo), abs(hi))
  diag_lo <- diag(lo)
  diag_hi <- diag(hi)
  radios <- if (m == 1L) 0 else ra_succ(rowSums(mag) - pmin(abs(diag_lo), abs(diag_hi)))
  ## The radius must never be understated: the row sum is rounded up and the
  ## diagonal magnitude subtracted at its smallest.
  radios <- pmax(radios, 0)
  d_lo <- ra_pred(diag_lo - radios)
  d_hi <- ra_succ(diag_hi + radios)
  out <- ra_interval(min(d_lo), max(d_hi))
  if (isTRUE(discs)) {
    attr(out, "ra_discs") <- data.frame(row = seq_len(m), lo = d_lo, hi = d_hi)
  }
  out
}

#' @title Bound the spectrum of a sum of symmetric matrices
#' @description Combines enclosures of the spectra of two symmetric matrices
#'   into an enclosure of the spectrum of their sum, by Weyl's inequalities.
#' @param a An \code{ra_ivl} of length one enclosing the spectrum of the first
#'   matrix, or a numeric pair.
#' @param b The same for the second matrix.
#' @return An object of class \code{ra_ivl} of length one enclosing the
#'   spectrum of the sum.
#' @details Weyl's inequalities give
#'   \code{lambda_min(A + B) >= lambda_min(A) + lambda_min(B)} and
#'   \code{lambda_max(A + B) <= lambda_max(A) + lambda_max(B)}, so the sum of
#'   the enclosures encloses the spectrum of the sum. The addition is rounded
#'   outwards.
#'
#'   The bound is what lets a caller combine a summand whose spectrum is known
#'   in closed form with one that is only bounded, which is the usual shape of
#'   a metric built as a constant part plus a state-dependent one.
#' @references
#'   Horn, R. A., & Johnson, C. R. (2013). Matrix analysis (2nd ed.).
#'   Cambridge University Press.
#' @examples
#' ra_spectral_sum(ra_interval(1, 3), ra_interval(-1, 2))
#' @seealso [ra_gershgorin()] for obtaining each enclosure.
#' @export
ra_spectral_sum <- function(a, b) {
  a <- .ra_as_ivl(a)
  b <- .ra_as_ivl(b)
  if (length(a$lo) != 1L || length(b$lo) != 1L) {
    ra_stop("bad_argument", "`a` and `b` must be single intervals.")
  }
  ra_add(a, b)
}

## ---------------------------------------------------------------------------
## Everything a class drags, written together.
## ---------------------------------------------------------------------------

#' @title Format a fixed point certificate
#' @description Renders the certificate as the lines of its card.
#' @param x An object of class \code{ra_certificate}.
#' @param ... Ignored, present for consistency with the generic.
#' @return A character vector, one element per line.
#' @details The card names both words and never lets one stand for the other.
#'   A confined ball that is not a contraction says so, and says that what
#'   happens inside is not claimed, which is the doctrinal boundary of the
#'   certificate.
#' @references
#'   Granas, A., & Dugundji, J. (2003). Fixed point theory. Springer.
#'   https://doi.org/10.1007/978-0-387-21593-8
#' @examples
#' format(ra_ball_certificate(0.2, 0.5))
#' @seealso [ra_ball_certificate()].
#' @export
format.ra_certificate <- function(x, ...) {
  ln <- character(0)
  ln <- c(ln, sprintf("fixed point certificate over a ball in the %s norm", x$norm))
  if (x$confined) {
    ln <- c(ln, sprintf("  confinement : certified by the %s route, radius %.6g",
                        x$route, x$radius))
  } else {
    ln <- c(ln, "  confinement : not certified")
  }
  if (x$contraction) {
    ln <- c(ln, sprintf("  contraction : certified, the fixed point is unique in the ball"))
    ln <- c(ln, sprintf("  the centre is within %.6g of it", x$error_bound))
  } else if (x$confined) {
    ln <- c(ln, "  contraction : not certified, so what happens inside is not claimed")
  } else {
    ln <- c(ln, "  contraction : not certified")
  }
  if (nzchar(x$reason)) ln <- c(ln, paste0("  reason      : ", x$reason))
  ln <- c(ln, sprintf("  bounds used : rho %.6g, L %s, image %s", x$rho,
                      if (is.na(x$lipschitz)) "not given" else sprintf("%.6g", x$lipschitz),
                      if (is.na(x$image_radius)) "not given" else sprintf("%.6g", x$image_radius)))
  ln <- c(ln, sprintf("  provenance  : %s", x$prov))
  ln
}

#' @title Print a fixed point certificate
#' @description Prints the card of the certificate.
#' @param x An object of class \code{ra_certificate}.
#' @param ... Ignored, present for consistency with the generic.
#' @return \code{x}, invisibly.
#' @details Printing is the card and nothing else; the numbers behind it are
#'   the elements of the list and [as.data.frame()] gives them in one row.
#' @references
#'   Granas, A., & Dugundji, J. (2003). Fixed point theory. Springer.
#'   https://doi.org/10.1007/978-0-387-21593-8
#' @examples
#' print(ra_ball_certificate(0.2, 0.5))
#' @seealso [format.ra_certificate()].
#' @export
print.ra_certificate <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' @title Coerce a fixed point certificate to a data frame
#' @description Returns the certificate as a single row.
#' @param x An object of class \code{ra_certificate}.
#' @param row.names Passed to the data frame constructor.
#' @param optional Passed to the data frame constructor.
#' @param ... Ignored, present for consistency with the generic.
#' @return A data frame of one row.
#' @details The row carries the verdicts, the route, the radius and the error
#'   bound, the three bounds used, the norm label and the provenance, so that
#'   a batch of certificates can be stacked and read as a table.
#' @references
#'   Granas, A., & Dugundji, J. (2003). Fixed point theory. Springer.
#'   https://doi.org/10.1007/978-0-387-21593-8
#' @examples
#' as.data.frame(ra_ball_certificate(0.2, 0.5))
#' @seealso [ra_ball_certificate()].
#' @export
as.data.frame.ra_certificate <- function(x, row.names = NULL, optional = FALSE, ...) {
  data.frame(confined = x$confined, contraction = x$contraction,
             route = ifelse(is.na(x$route), NA_character_, x$route),
             radius = x$radius, error_bound = x$error_bound,
             rho = x$rho, lipschitz = x$lipschitz, image_radius = x$image_radius,
             norm = x$norm, prov = x$prov, reason = x$reason,
             row.names = row.names, stringsAsFactors = FALSE)
}

#' @title Summarise a fixed point certificate
#' @description Reduces the certificate to the two verdicts and the numbers a
#'   reader needs to act on them.
#' @param object An object of class \code{ra_certificate}.
#' @param ... Ignored, present for consistency with the generic.
#' @return An object of class \code{ra_summary_certificate}.
#' @details The summary carries no verdict the certificate did not carry: it
#'   is the same two words with the radius and the error bound.
#' @references
#'   Granas, A., & Dugundji, J. (2003). Fixed point theory. Springer.
#'   https://doi.org/10.1007/978-0-387-21593-8
#' @examples
#' summary(ra_ball_certificate(0.2, 0.5))
#' @seealso [ra_ball_certificate()].
#' @export
summary.ra_certificate <- function(object, ...) {
  structure(list(confined = object$confined, contraction = object$contraction,
                 radius = object$radius, error_bound = object$error_bound,
                 norm = object$norm, prov = object$prov),
            class = "ra_summary_certificate")
}

#' @title Format the summary of a fixed point certificate
#' @description Renders the summary as its lines.
#' @param x An object of class \code{ra_summary_certificate}.
#' @param ... Ignored, present for consistency with the generic.
#' @return A character vector, one element per line.
#' @details The summary prints the two words in the same order the card does,
#'   so that a reader who has seen one recognises the other.
#' @references
#'   Granas, A., & Dugundji, J. (2003). Fixed point theory. Springer.
#'   https://doi.org/10.1007/978-0-387-21593-8
#' @examples
#' format(summary(ra_ball_certificate(0.2, 0.5)))
#' @seealso [summary.ra_certificate()].
#' @export
format.ra_summary_certificate <- function(x, ...) {
  c(sprintf("summary of a fixed point certificate (%s norm, %s)", x$norm, x$prov),
    sprintf("  confinement %s, contraction %s",
            if (x$confined) "certified" else "not certified",
            if (x$contraction) "certified" else "not certified"),
    if (x$confined) sprintf("  radius %.6g", x$radius) else "  no radius certified")
}

#' @title Print the summary of a fixed point certificate
#' @description Prints the lines of the summary.
#' @param x An object of class \code{ra_summary_certificate}.
#' @param ... Ignored, present for consistency with the generic.
#' @return \code{x}, invisibly.
#' @details Printing is the summary and nothing else.
#' @references
#'   Granas, A., & Dugundji, J. (2003). Fixed point theory. Springer.
#'   https://doi.org/10.1007/978-0-387-21593-8
#' @examples
#' print(summary(ra_ball_certificate(0.2, 0.5)))
#' @seealso [format.ra_summary_certificate()].
#' @export
print.ra_summary_certificate <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}
