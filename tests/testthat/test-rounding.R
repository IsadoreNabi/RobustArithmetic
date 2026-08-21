## The outward-rounding layer, judged against the bit-level reference.
##
## This file is the probe of session 78 turned into a permanent gate. What it
## asserts is validity, which is what the enclosures depend on: the successor
## returned must be strictly above the argument and no lower than the true
## immediate successor, and the mirror image for the predecessor. Tightness is
## reported but not required, because a value one step too far widens an
## enclosure and cannot invalidate one.

test_that("the bit reference is right on values whose neighbours are known in closed form", {
  expect_identical(ra_next_up_bits(1), 1 + 2^-52)
  expect_identical(ra_next_down_bits(1), 1 - 2^-53)
  expect_identical(ra_next_up_bits(2^-1074), 2^-1073)
  expect_identical(ra_next_up_bits(0), 2^-1074)
  expect_identical(ra_next_down_bits(-1), -(1 + 2^-52))
  expect_identical(ra_next_up_bits(-2^-1074), 0)
  expect_identical(ra_next_up_bits(.Machine$double.xmax), Inf)
})

test_that("the constants are the ones of the theorem and not a decimal transcription", {
  k <- ra_constants()
  expect_identical(k[["u"]], 2^-53)
  expect_identical(k[["phi"]], 2^-53 * (1 + 2^-52))
  expect_identical(k[["eta"]], 2^-1074)
  ## phi is the successor of u, which is the whole point: the naive factor u is
  ## what fails, and it fails at ordinary arguments.
  expect_identical(k[["phi"]], ra_next_up_bits(k[["u"]]))
})

test_that("succ and pred are valid on the whole sweep of the probe", {
  skip_on_cran()
  xs <- ra_bit_test_set()
  expect_gt(length(xs), 100000L)

  nu <- ra_next_up_bits(xs)
  nd <- ra_next_down_bits(xs)
  s <- ra_succ(xs)
  p <- ra_pred(xs)

  expect_true(all(s > xs))
  expect_true(all(p < xs))
  expect_true(all(s >= nu))
  expect_true(all(p <= nd))

  ## Tightness is asserted structurally rather than as a proportion, because
  ## the paper proves where the looseness can be and not merely how rare it is.
  ## Theorem 2.2 states that the computed values equal the true neighbours for
  ## every finite argument outside the band |c| in [u^-1 eta / 2, 2 u^-1 eta],
  ## which for binary64 is the two binades [2^-1022, 2^-1020] around the
  ## subnormal threshold, and that inside the band the result is one bit off.
  ## A proportion could stay high while the exceptions moved somewhere the
  ## theorem forbids; this cannot.
  band_lo <- 2^-1022
  band_hi <- 2^-1020
  loose <- which(s != nu | p != nd)
  expect_true(all(abs(xs[loose]) >= band_lo & abs(xs[loose]) <= band_hi))
  ## And the excess, where it occurs, is one step and never two.
  if (length(loose)) {
    steps <- vapply(loose, function(i) {
      z <- nu[i]
      n <- 0L
      while (z < s[i] && n < 5L) {
        z <- ra_next_up_bits(z)
        n <- n + 1L
      }
      n
    }, integer(1L))
    expect_lte(max(steps), 1L)
  }
  ## Corroboration, reported rather than demanded: 8 loose points out of 180092
  ## on this machine, all of them at 2^-1022 and 2^-1021 and their negatives.
  expect_gt(mean(s == nu & p == nd), 0.999)
})

test_that("the ends of the range are handled and not left as NaN", {
  ## The formula alone produces NaN at these two arguments. Both are the
  ## saturation the floating-point standard prescribes for nextUp and nextDown.
  expect_identical(ra_succ(-Inf), -.Machine$double.xmax)
  expect_identical(ra_pred(Inf), .Machine$double.xmax)
  ## Overflow upward is a valid upper bound and is how the arithmetic leaves the
  ## finite range without inventing a finite answer.
  expect_identical(ra_succ(.Machine$double.xmax), Inf)
  expect_identical(ra_pred(-.Machine$double.xmax), -Inf)
  expect_identical(ra_succ(Inf), Inf)
  expect_identical(ra_pred(-Inf), -Inf)
  expect_true(is.nan(ra_succ(NaN)))
  expect_true(is.nan(ra_pred(NaN)))
  expect_true(is.na(ra_succ(NA_real_)))
})

test_that("POSITIVE CONTROL: the naive widening factor must violate validity", {
  ## Rump, Zimmermann, Boldo and Melquiond exist because the obvious factor does
  ## not work. If this ever stops failing, the harness has stopped measuring
  ## what it claims to measure and the sweep above proves nothing.
  naive_succ <- function(x) x + (2^-53 * abs(x) + 2^-1074)
  expect_false(naive_succ(1) > 1)

  skip_on_cran()
  xs <- ra_bit_test_set()
  bad <- which(!(naive_succ(xs) > xs & naive_succ(xs) >= ra_next_up_bits(xs)))
  expect_gt(length(bad), 0L)
  expect_true(1 %in% xs[bad])
})

test_that("POSITIVE CONTROL: dropping the subnormal term must break the sweep at zero", {
  ## The additive term is what makes the formula work where the multiplicative
  ## one vanishes. Without it, succ(0) is 0, which is not strictly above 0.
  no_eta_succ <- function(x) x + 2^-53 * (1 + 2^-52) * abs(x)
  expect_false(no_eta_succ(0) > 0)
  expect_true(ra_succ(0) > 0)
})

test_that("the outward step widens in both directions and never narrows", {
  vals <- c(0.1, -0.1, 1, -1, 1e-300, 1e300, 0)
  w <- ra_round_out(vals, vals)
  expect_true(all(w$lo < vals))
  expect_true(all(w$hi > vals))
  expect_error(ra_round_out(1:3, 1:2), class = "ra_bad_argument")
})
