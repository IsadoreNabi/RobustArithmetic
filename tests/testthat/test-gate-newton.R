## Gate 4 -- the gate of the whole design.
##
## The fixture is the table of probe 4 of session 78: the three normal forms
## of Strogatz, nine values of r each, 27 rows. Every row is contrasted
## against the algebra: the certified roots must match the algebraic ones in
## number and in value (checked in multiprecision), the degenerate rows must
## abstain around the multiple root, and the windows without roots must come
## out demonstrated empty. A single row off means the architecture of the
## route, not a detail, is wrong.

test_that("gate 4: 27 of 27 rows against the algebra of the normal forms", {
  skip_on_cran()
  skip_if_not(ra_has_mpfr(), "the referent needs Rmpfr")

  forms <- list(
    saddle = list(
      e = quote(r - x^2),
      roots = function(r) {
        if (r > 0) c(-sqrt(r), sqrt(r)) else if (r == 0) NA else numeric(0)
      }),
    transcritical = list(
      e = quote(r * x - x^2),
      roots = function(r) if (r != 0) sort(c(0, r)) else NA),
    pitchfork = list(
      e = quote(r * x - x^3),
      roots = function(r) {
        if (r > 0) sort(c(-sqrt(r), 0, sqrt(r)))
        else if (r == 0) NA else 0
      })
  )
  rs <- seq(-1, 1, by = 0.25)
  rows_ok <- 0L

  for (nm in names(forms)) {
    for (r in rs) {
      res <- ra_solve(forms[[nm]]$e, ra_interval(-3, 3), env = list(r = r))
      alg <- forms[[nm]]$roots(r)
      expect_false(res$exhausted,
                   label = paste(nm, "r =", r, "exhausted its budget"))

      if (length(alg) == 1L && is.na(alg)) {
        ## degenerate row: a multiple root at 0; the only honest words are
        ## the abstention, tight around the root, containing it
        ok_row <-
          length(res$unique) == 0L &&
          length(res$not_excludable) >= 1L &&
          all(ra_inf(res$not_excludable) >= -1e-3 &
              ra_sup(res$not_excludable) <= 1e-3) &&
          any(ra_inf(res$not_excludable) <= 0 &
              ra_sup(res$not_excludable) >= 0)
        expect_true(ok_row, label = paste(nm, "r =", r, "(degenerate)"))
      } else {
        ## plain row: as many uniqueness certificates as algebraic roots,
        ## no abstention, and every algebraic root inside its enclosure,
        ## checked in multiprecision because sqrt(r) in double would put a
        ## rounded referent inside an exact claim
        ok_count <- length(res$unique) == length(alg) &&
          length(res$not_excludable) == 0L
        ok_row <- ok_count
        if (ok_count && length(alg)) {
          u <- res$unique
          for (i in seq_along(alg)) {
            v <- if (nm == "saddle" && alg[i] != 0) {
              (if (alg[i] < 0) -1 else 1) * sqrt(Rmpfr::mpfr(abs(r), 300L))
            } else if (nm == "pitchfork" && alg[i] != 0) {
              (if (alg[i] < 0) -1 else 1) * sqrt(Rmpfr::mpfr(abs(r), 300L))
            } else {
              Rmpfr::mpfr(alg[i], 300L)
            }
            inside <- (Rmpfr::mpfr(ra_inf(u[i]), 300L) <= v) &&
              (v <= Rmpfr::mpfr(ra_sup(u[i]), 300L))
            tight <- ra_wid(u[i]) <= 1e-8
            ok_row <- ok_row && inside && tight
          }
        }
        expect_true(ok_row, label = paste(nm, "r =", r))
      }
      if (ok_row) rows_ok <- rows_ok + 1L
    }
  }
  ## the whole-design assertion: 27 of 27, said once with its number
  expect_identical(rows_ok, 27L)
})

test_that("gate 4: the empty windows of the saddle are demonstrated, not sampled", {
  skip_on_cran()
  for (r in c(-1, -0.75, -0.5, -0.25)) {
    res <- ra_solve(quote(r - x^2), ra_interval(-3, 3), env = list(r = r))
    expect_identical(length(res$unique), 0L)
    expect_identical(length(res$not_excludable), 0L)
    out <- paste(capture.output(print(res)), collapse = "\n")
    expect_match(out, "absence demonstrated")
  }
})
