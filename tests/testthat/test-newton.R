## The interval Newton operator and the paving engine.
##
## The controls here are written before the piece, and each one can fail for
## the thing it watches: the inflation step can be turned off and must then
## fail to certify a boundary root; the budget can be exhausted and must then
## speak; a multiple root must never receive a uniqueness certificate.

test_that("one Hansen-Sengupta step contracts toward a simple root", {
  restore_fast_level <- hold_fast_level_open()
  on.exit(restore_fast_level(), add = TRUE)
  ## exp(x) - 2 has its only root at log(2), interior to [0, 1]
  got <- ra_newton_step(quote(exp(x) - 2), ra_interval(0, 1))
  expect_s3_class(got, "ra_ivl")
  expect_identical(length(got), 1L)
  expect_true(ra_inf(got) <= log(2) && ra_sup(got) >= log(2))
  ## strictly interior contraction is the existence-and-uniqueness signal
  expect_true(ra_inf(got) > 0 && ra_sup(got) < 1)
})

test_that("the step splits through a straddling derivative", {
  ## x^2 - 1 on [-2, 2]: the derivative spans zero, extended division applies
  ## and the step returns pieces that keep both roots
  got <- ra_newton_step(quote(x^2 - 1), ra_interval(-2, 2))
  expect_true(length(got) >= 1L)
  covers <- function(v) any(ra_inf(got) <= v & ra_sup(got) >= v)
  expect_true(covers(-1) && covers(1))
})

test_that("the solver certifies the two roots of a well-separated case", {
  res <- ra_solve(quote(r * x - x^2), ra_interval(-3, 3),
                  env = list(r = 0.5))
  expect_s3_class(res, "ra_paving")
  expect_identical(length(res$unique), 2L)
  expect_identical(length(res$not_excludable), 0L)
  for (v in c(0, 0.5)) {
    expect_true(any(ra_inf(res$unique) <= v & ra_sup(res$unique) >= v))
  }
  expect_true(all(ra_wid(res$unique) <= 1e-8))
  expect_false(res$exhausted)
})

test_that("absence over the whole window is demonstrated, not assumed", {
  res <- ra_solve(quote(r - x^2), ra_interval(-3, 3), env = list(r = -0.5))
  expect_identical(length(res$unique), 0L)
  expect_identical(length(res$not_excludable), 0L)
  out <- paste(capture.output(print(res)), collapse = "\n")
  expect_match(out, "absence demonstrated")
})

test_that("a multiple root is never certified unique", {
  ## the saddle-node at r = 0: f(x) = -x^2, a double root at 0
  res <- ra_solve(quote(r - x^2), ra_interval(-3, 3), env = list(r = 0))
  expect_identical(length(res$unique), 0L)
  expect_true(length(res$not_excludable) >= 1L)
  expect_true(any(ra_inf(res$not_excludable) <= 0 &
                  ra_sup(res$not_excludable) >= 0))
  ## and the clusters are tight around the root, not smeared over the window
  expect_true(all(ra_inf(res$not_excludable) >= -1e-3 &
                  ra_sup(res$not_excludable) <= 1e-3))
  out <- paste(capture.output(print(res)), collapse = "\n")
  expect_match(out, "not excludable")
})

test_that("CP: without candidate inflation, a boundary root is not certified", {
  ## the root at 0 sits exactly on the window edge, so it is never strictly
  ## interior to any box and contraction alone cannot certify it: this is the
  ## measured lesson of probe 4, and the reason the inflation step exists
  bare <- .ra_solve_impl(quote(r * x - x^2), ra_interval(0, 3),
                         env = list(r = 0.5), inflate = FALSE)
  expect_true(length(bare$unique) < 2L)
  expect_true(length(bare$not_excludable) >= 1L)
  ## with the step on, both roots are certified: the watchman can fail and
  ## the repair repairs
  full <- ra_solve(quote(r * x - x^2), ra_interval(0, 3),
                   env = list(r = 0.5))
  expect_identical(length(full$unique), 2L)
  expect_identical(length(full$not_excludable), 0L)
})

test_that("CP: an exhausted budget speaks with its number", {
  res <- ra_solve(quote(r * x - x^3), ra_interval(-3, 3),
                  env = list(r = 0.5), max_boxes = 3L)
  expect_true(res$exhausted)
  out <- paste(capture.output(print(res)), collapse = "\n")
  expect_match(out, "budget")
  expect_match(out, "3", fixed = TRUE)
  ## nothing falls silent: what was not processed is not excludable
  expect_true(length(res$not_excludable) >= 1L)
})

test_that("two roots closer than the resolution produce abstention, not a lie", {
  ## r * x - x^2 with r = 2^-60: roots at 0 and 2^-60, far below min_width;
  ## no box can separate them, so no uniqueness certificate is possible and
  ## the honest word is the abstention
  res <- ra_solve(quote(r * x - x^2), ra_interval(-1, 1),
                  env = list(r = 2^-60))
  expect_identical(length(res$unique), 0L)
  expect_true(length(res$not_excludable) >= 1L)
})

test_that("arithmetic verdicts retain theorem provenance", {
  res <- ra_solve(quote(r * x - x^2), ra_interval(-3, 3), env = list(r = 0.5))
  expect_true(res$verified)
  expect_true(all(ra_prov(res$unique) == "theorem"))
  out <- paste(capture.output(print(res)), collapse = "\n")
  expect_match(out, "verdict provenance: theorem", fixed = TRUE)
})

test_that("fast verdict provenance follows the operations actually evaluated", {
  restore_fast_level <- hold_fast_level_open()
  on.exit(restore_fast_level(), add = TRUE)
  local_mocked_bindings(ra_has_mpfr = function() FALSE,
                        .package = "RobustArithmetic")

  arithmetic <- ra_solve(quote(x^2 - 2), ra_interval(0, 3))
  elementary <- ra_solve(quote(sin(x) - 0.5), ra_interval(0, 1))
  arithmetic_absence <- ra_solve(quote(-1 - x^2), ra_interval(-3, 3))
  elementary_absence <- ra_solve(quote(-1 - exp(x)), ra_interval(-3, 3))
  arithmetic_abstention <- ra_solve(quote(-x^2), ra_interval(-1, 1))

  expect_true(arithmetic$verified)
  expect_identical(unique(as.data.frame(arithmetic)$prov), "theorem")
  expect_false(elementary$verified)
  expect_identical(unique(as.data.frame(elementary)$prov), "measured")

  expect_true(arithmetic_absence$verified)
  expect_false(elementary_absence$verified)
  expect_true(arithmetic_abstention$verified)
  expect_identical(unique(as.data.frame(arithmetic_abstention)$prov), "theorem")

  arithmetic_card <- paste(format(arithmetic_absence), collapse = "\n")
  elementary_card <- paste(format(elementary_absence), collapse = "\n")
  arithmetic_summary <- paste(capture.output(print(summary(arithmetic))),
                              collapse = "\n")
  elementary_summary <- paste(capture.output(print(summary(elementary))),
                              collapse = "\n")
  expect_match(arithmetic_card, "verdict provenance: theorem", fixed = TRUE)
  expect_match(elementary_card, "verdict provenance: measured", fixed = TRUE)
  expect_match(elementary_card, "NOT re-verified rigorously", fixed = TRUE)
  expect_match(arithmetic_summary,
               "Theorem provenance for every verdict: yes", fixed = TRUE)
  expect_match(elementary_summary,
               "Theorem provenance for every verdict: no", fixed = TRUE)
})

test_that("everything the class carries is written together", {
  res <- ra_solve(quote(x^2 - 2), ra_interval(0, 3))
  expect_s3_class(res, "ra_paving")
  df <- as.data.frame(res)
  expect_true(all(c("lo", "hi", "verdict") %in% names(df)))
  expect_no_error(format(res))
  s <- summary(res)
  expect_no_error(print(s))
})
