## The bridge back from multiprecision, and the conversion that must not be used.
##
## This file is the second probe of session 78 turned into a permanent gate. Its
## point is not that the bridge works; it is that the obvious alternative fails,
## and fails silently, so that anyone who replaces the bridge with the obvious
## alternative is stopped here rather than at the boundary of some paving three
## layers up.

test_that("the probe answers without raising whether or not the backend is there", {
  expect_type(ra_has_mpfr(), "logical")
  expect_length(ra_has_mpfr(), 1L)
})

test_that("the clean planting names the backend, what is lost and what still works", {
  msg <- ra_message_no_mpfr("the escalation of exp() to 212 bits")
  expect_match(msg, "Rmpfr", fixed = TRUE)
  expect_match(msg, "fast level answered instead", fixed = TRUE)
  expect_match(msg, "enclosure is valid", fixed = TRUE)
  expect_match(msg, "the escalation of exp() to 212 bits", fixed = TRUE)
})

test_that("without the backend the bridge refuses by name instead of guessing", {
  skip_if(ra_has_mpfr(), "the backend is installed, so this path is unreachable")
  expect_error(ra_to_double(1), class = "ra_no_mpfr")
})

test_that("the directed bridge brackets a value that no double represents", {
  skip_if_not(ra_has_mpfr(), "needs Rmpfr")
  third <- Rmpfr::mpfr("1", 120L) / 3
  lo <- ra_to_double(third, "down")
  hi <- ra_to_double(third, "up")
  ## The two endpoints are adjacent doubles, so the enclosure is the tightest a
  ## pair of doubles can be. Their difference is exact by Sterbenz: subtracting
  ## neighbours never rounds.
  expect_identical(hi - lo, 2^-54)
  expect_identical(hi, ra_next_up_bits(lo))
})

test_that("the bridge respects the subnormal range and saturates outward", {
  skip_if_not(ra_has_mpfr(), "needs Rmpfr")
  tiny <- Rmpfr::mpfr(2, 120L)^-1080
  big <- Rmpfr::mpfr(2, 120L)^1030
  ## Upward from a positive value below the smallest subnormal: the smallest
  ## subnormal, not zero. Zero would be a lower bound offered as an upper one.
  expect_identical(ra_to_double(tiny, "up"), 2^-1074)
  ## Downward: zero is a valid lower bound of a positive number.
  expect_identical(ra_to_double(tiny, "down"), 0)
  ## Beyond the finite range: the largest finite double downward, infinity
  ## upward. Both are valid bounds and neither pretends the value is finite.
  expect_identical(ra_to_double(big, "down"), .Machine$double.xmax)
  expect_identical(ra_to_double(big, "up"), Inf)
})

test_that("POSITIVE CONTROL: as.numeric must fail the subnormal test the bridge passes", {
  ## This is the assertion the file exists for. as.numeric underflows to zero
  ## and overflows to infinity with no signal, so it returns a lower bound where
  ## an upper one was asked for and cannot say that it did.
  skip_if_not(ra_has_mpfr(), "needs Rmpfr")
  tiny <- Rmpfr::mpfr(2, 120L)^-1080
  big <- Rmpfr::mpfr(2, 120L)^1030
  expect_identical(as.numeric(tiny), 0)
  expect_false(identical(as.numeric(tiny), 2^-1074))
  expect_identical(as.numeric(big), Inf)
  expect_false(identical(as.numeric(big), .Machine$double.xmax))
})

test_that("POSITIVE CONTROL: the arithmetic operators of the backend ignore a rounding mode", {
  ## Measured, not assumed. The path of the rigorous level is built around this
  ## fact: evaluate to nearest at high precision, then round once in the wanted
  ## direction. If the operators ever begin to honour the argument, this test
  ## fails and the path can be simplified.
  skip_if_not(ra_has_mpfr(), "needs Rmpfr")
  a <- Rmpfr::mpfr("1", 60L)
  b <- Rmpfr::mpfr("3", 60L)
  down <- tryCatch(`/`(a, b, rnd.mode = "D"), error = function(e) NULL)
  expect_null(down)
})

test_that("the enclosure of a multiprecision value contains it and is one step wide", {
  skip_if_not(ra_has_mpfr(), "needs Rmpfr")
  e <- ra_enclose_mpfr(exp(Rmpfr::mpfr("1", 200L)))
  expect_true(e$lo < exp(1) || e$lo == exp(1))
  expect_true(e$hi > exp(1) || e$hi == exp(1))
  expect_true(e$hi == e$lo || identical(e$hi, ra_next_up_bits(e$lo)))
})

test_that("the ladder doubles and starts above binary64", {
  lad <- ra_precision_ladder()
  expect_true(all(diff(lad) == lad[-length(lad)]))
  expect_gt(lad[1L], 53L)
  expect_identical(lad, c(106L, 212L, 424L, 848L))
})
