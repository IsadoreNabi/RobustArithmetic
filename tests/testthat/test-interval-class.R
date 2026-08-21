## The class, its invariant, its special values and its decorations.
##
## The positive controls come first, because a harness that cannot fail cannot
## certify. Each one asserts that the kernel refuses, or widens, where a naive
## implementation would quietly succeed.

test_that("POSITIVE CONTROL: an inverted pair of endpoints must be refused", {
  expect_error(ra_interval(2, 1), class = "ra_bad_endpoints")
  expect_error(ra_interval(c(1, 5), c(2, 3)), class = "ra_bad_endpoints")
  ## And the message must say which element, because a vector of ten thousand
  ## intervals with one bad pair is the case that matters.
  msg <- tryCatch(ra_interval(c(1, 5), c(2, 3)),
                  ra_bad_endpoints = conditionMessage)
  expect_match(msg, "element 2", fixed = TRUE)
})

test_that("POSITIVE CONTROL: an infinity offered as a member must be refused", {
  ## Infinities are bounds of an interval and never members, so these two pairs
  ## do not denote nonempty intervals. An implementation that accepted them
  ## would carry a point at infinity through the arithmetic.
  expect_error(ra_interval(Inf, Inf), class = "ra_bad_endpoints")
  expect_error(ra_interval(-Inf, -Inf), class = "ra_bad_endpoints")
  expect_silent(ra_interval(-Inf, Inf))
  expect_silent(ra_interval(-Inf, 0))
  expect_silent(ra_interval(0, Inf))
})

test_that("POSITIVE CONTROL: subtracting an interval from itself must show the dependency", {
  ## [1,2] - [1,2] is [-1,1] and not [0,0]. The kernel does not know that the
  ## two operands are the same number and must not pretend to. A result of
  ## [0,0] here would mean the arithmetic had been given an identity it cannot
  ## justify, and every enclosure downstream would be suspect.
  x <- ra_interval(1, 2)
  d <- x - x
  expect_encloses(d, -1, 1)
  expect_false(ra_inf(d) == 0 && ra_sup(d) == 0)
  expect_lt(ra_inf(d), 0)
  expect_gt(ra_sup(d), 0)
})

test_that("POSITIVE CONTROL: dividing by a straddling interval must refuse when asked to", {
  x <- ra_interval(1, 2)
  y <- ra_interval(-1, 1)
  expect_error(ra_div(x, y, zero = "error"),
               class = "ra_division_straddles_zero")
  ## And the total behaviour must not pretend to a tight answer either: the
  ## hull of an unbounded set is unbounded, and it says so with trv.
  h <- ra_div(x, y)
  expect_true(ra_is_entire(h))
  expect_identical(ra_dec(h), "trv")
})

test_that("the initial decoration is the one the standard prescribes", {
  expect_identical(ra_dec(ra_interval(1, 2)), "com")
  expect_identical(ra_dec(ra_interval(-Inf, 0)), "dac")
  expect_identical(ra_dec(ra_interval(0, Inf)), "dac")
  expect_identical(ra_dec(ra_entire()), "dac")
  expect_identical(ra_dec(ra_empty()), "trv")
  expect_identical(ra_dec(ra_nai()), "ill")
})

test_that("the forbidden combinations of the standard are repaired, not produced", {
  ## An empty interval cannot carry com, dac or def, because those assert that
  ## the argument box is nonempty; an unbounded one cannot carry com, because
  ## com asserts boundedness.
  expect_identical(ra_dec(ra_set_dec(ra_empty(), "com")), "trv")
  expect_identical(ra_dec(ra_set_dec(ra_empty(), "def")), "trv")
  expect_identical(ra_dec(ra_set_dec(ra_empty(), "dac")), "trv")
  expect_identical(ra_dec(ra_set_dec(ra_entire(), "com")), "dac")
  expect_true(ra_is_nai(ra_set_dec(ra_interval(1, 2), "ill")))
  expect_error(ra_interval(1, 2, decoration = "nonesuch"),
               class = "ra_bad_decoration")
  expect_error(ra_set_dec(ra_interval(1, 2), "nonesuch"),
               class = "ra_bad_decoration")
  ## The constructor refuses an inverted pair rather than reading it as the
  ## empty interval, which is why the empty interval has a name of its own.
  expect_error(ra_interval(Inf, -Inf), class = "ra_bad_endpoints")
})

test_that("the decoration propagates by the weakest of the operation and its inputs", {
  a <- ra_interval(1, 2)
  b <- ra_interval(3, 4, decoration = "def")
  expect_identical(ra_dec(a + a), "com")
  expect_identical(ra_dec(a + b), "def")
  expect_identical(ra_dec(a + ra_entire()), "dac")
  expect_identical(ra_dec(a + ra_empty()), "trv")
  expect_identical(ra_dec(a + ra_nai()), "ill")
})

test_that("empty and Not-an-Interval propagate through the arithmetic", {
  a <- ra_interval(1, 2)
  for (f in list(ra_add, ra_sub, ra_mul, ra_div)) {
    expect_true(ra_is_empty(f(a, ra_empty())))
    expect_true(ra_is_empty(f(ra_empty(), a)))
    expect_true(ra_is_nai(f(a, ra_nai())))
    expect_true(ra_is_nai(f(ra_nai(), a)))
  }
  expect_true(ra_is_empty(ra_neg(ra_empty())))
  expect_true(ra_is_nai(ra_sqr(ra_nai())))
})

test_that("zero times an unbounded interval is zero and not an indeterminate form", {
  ## Inf is a bound and never a member, so every product in the set is 0.
  z <- ra_interval(0, 0)
  r <- z * ra_interval(1, Inf)
  expect_encloses(r, 0, 0)
  expect_false(is.nan(ra_inf(r)))
  r2 <- z * ra_entire()
  expect_encloses(r2, 0, 0)
})

test_that("the square is tighter than the product and never wider", {
  x <- ra_interval(-1, 2)
  expect_encloses(ra_sqr(x), 0, 4)
  expect_encloses(x * x, -2, 4)
  expect_true(ra_inf(ra_sqr(x)) >= ra_inf(x * x))
  expect_true(ra_sup(ra_sqr(x)) <= ra_sup(x * x))
  ## The absolute value has the same shape, and is exact: no arithmetic runs.
  expect_identical(c(ra_inf(ra_abs(x)), ra_sup(ra_abs(x))), c(0, 2))
  expect_identical(c(ra_inf(ra_abs(ra_interval(-3, -1))),
                     ra_sup(ra_abs(ra_interval(-3, -1)))), c(1, 3))
})

test_that("integer powers respect parity and the sign of the exponent", {
  ## The tightness a power can claim is the one its construction allows, and
  ## the bound is linear in the exponent even though the number of operations
  ## is logarithmic in it: the relative error of each rounded operation is
  ## carried into the next and multiplied by it, so after squaring one's way to
  ## the p-th power the accumulated relative error is about p times the unit
  ## roundoff, which is about p steps in units of the last place of the result.
  ## Measured on this machine: 1 step at p = 2, 3 at p = 3, 3 at p = 4, 5 at
  ## p = 5, 9 at p = 8 and 15 at p = 16. Asserting one step would be asserting
  ## that the intermediate roundings had been skipped.
  steps_for <- function(p) as.integer(abs(p)) + 1L
  expect_encloses(ra_pown(ra_interval(2, 3), 3L), 8, 27, steps_for(3L))
  expect_encloses(ra_pown(ra_interval(-3, 2), 2L), 0, 9, steps_for(2L))
  expect_encloses(ra_pown(ra_interval(-3, -2), 3L), -27, -8, steps_for(3L))
  expect_encloses(ra_pown(ra_interval(2, 3), 5L), 32, 243, steps_for(5L))
  ## The exponent zero is the point interval one, by the convention of the
  ## standard for the integer power. It runs no arithmetic and is exact.
  expect_identical(c(ra_inf(ra_pown(ra_interval(-3, 2), 0L)),
                     ra_sup(ra_pown(ra_interval(-3, 2), 0L))), c(1, 1))
  ## A negative exponent over an interval containing zero is undefined
  ## somewhere in the box, so the decoration falls to trv.
  expect_identical(ra_dec(ra_pown(ra_interval(-1, 2), -1L)), "trv")
  expect_identical(ra_dec(ra_pown(ra_interval(2, 3), -1L)), "com")
  expect_error(ra_pown(ra_interval(1, 2), 1.5), class = "ra_bad_argument")
})

test_that("extended division keeps the gap that the hull would fill in", {
  e <- ra_div_extended(ra_interval(1, 1), ra_interval(-1, 2))
  expect_identical(ra_inf(e$first), -Inf)
  expect_encloses(e$first, -Inf, -1)
  expect_encloses(e$second, 0.5, Inf)
  expect_identical(ra_sup(e$second), Inf)
  ## The hull of the two pieces is the whole line, which is what the plain
  ## division returns and what makes the plain division useless here.
  expect_true(ra_is_entire(ra_div(ra_interval(1, 1), ra_interval(-1, 2))))

  ## A divisor touching zero at one endpoint gives one piece, not two.
  one <- ra_div_extended(ra_interval(1, 1), ra_interval(0, 2))
  expect_encloses(one$first, 0.5, Inf)
  expect_true(ra_is_empty(one$second))

  ## A numerator that also contains zero excludes nothing.
  none <- ra_div_extended(ra_interval(-1, 1), ra_interval(-1, 1))
  expect_true(ra_is_entire(none$first))
  expect_true(ra_is_empty(none$second))
})

test_that("extended division encloses the quotients it claims to exclude nothing of", {
  ## Sampling against the pieces: every defined quotient must lie in one of the
  ## two, and the gap must contain none of them.
  set.seed(11L)
  num <- ra_interval(1, 2)
  den <- ra_interval(-3, 4)
  e <- ra_div_extended(num, den)
  a <- runif(20000L, 1, 2)
  b <- runif(20000L, -3, 4)
  b <- b[abs(b) > 1e-12]
  q <- a[seq_along(b)] / b
  inside <- (q >= ra_inf(e$first) & q <= ra_sup(e$first)) |
    (q >= ra_inf(e$second) & q <= ra_sup(e$second))
  expect_true(all(inside))
})

test_that("the set operations are exact and decorate trv as the standard says", {
  i <- ra_intersect(ra_interval(0, 2), ra_interval(1, 3))
  expect_identical(c(ra_inf(i), ra_sup(i)), c(1, 2))
  ## Exact: the endpoints of the result are endpoints of the arguments.
  expect_identical(ra_dec(i), "trv")
  expect_true(ra_is_empty(ra_intersect(ra_interval(0, 1), ra_interval(2, 3))))
  h <- ra_hull(ra_interval(0, 1), ra_interval(2, 3))
  expect_identical(c(ra_inf(h), ra_sup(h)), c(0, 3))
  ## The hull with an empty argument is the other argument, not a widening.
  h2 <- ra_hull(ra_interval(0, 1), ra_empty())
  expect_identical(c(ra_inf(h2), ra_sup(h2)), c(0, 1))
})

test_that("the derived quantities are outward bounds where they claim to be", {
  x <- ra_interval(0.1, 0.3)
  expect_true(ra_wid(x) >= 0.3 - 0.1)
  expect_true(ra_mid(x) >= ra_inf(x) && ra_mid(x) <= ra_sup(x))
  expect_true(ra_rad(x) >= (0.3 - 0.1) / 2)
  expect_identical(ra_mag(ra_interval(-3, 1)), 3)
  expect_identical(ra_mig(ra_interval(-3, 1)), 0)
  expect_identical(ra_mig(ra_interval(2, 5)), 2)
  expect_true(is.nan(ra_wid(ra_empty())))
  expect_true(is.nan(ra_mid(ra_nai())))
  ## The midpoint of the whole line is a point of it and not a missing value.
  expect_identical(ra_mid(ra_entire()), 0)
})

test_that("the midpoint does not overflow on an interval that spans the range", {
  ## Computing (lo + hi) / 2 would overflow here; the kernel halves first.
  x <- ra_interval(-.Machine$double.xmax, .Machine$double.xmax)
  expect_true(is.finite(ra_mid(x)))
  expect_identical(ra_mid(x), 0)
})

test_that("the class behaves as a vector and not as the list underneath it", {
  x <- c(ra_interval(1, 2), ra_interval(3, 4), ra_empty())
  expect_identical(length(x), 3L)
  expect_identical(ra_inf(x[2]), 3)
  expect_identical(length(x[c(1, 3)]), 2L)
  d <- as.data.frame(x)
  expect_identical(nrow(d), 3L)
  expect_identical(names(d), c("lo", "hi", "dec", "prov", "wid"))
  s <- summary(x)
  expect_s3_class(s, "ra_ivl_summary")
  expect_identical(s$n, 3L)
  expect_identical(s$n_empty, 1L)
  expect_output(print(x), "empty")
  expect_output(print(s), "Decorations")
})

test_that("the special values print as their names and not as their encoding", {
  expect_match(format(ra_empty()), "empty", fixed = TRUE)
  expect_match(format(ra_nai()), "nai", fixed = TRUE)
  expect_false(grepl("Inf", format(ra_empty()), fixed = TRUE))
})

test_that("comparisons are refused rather than answered with the wrong order", {
  x <- ra_interval(1, 2)
  expect_error(x < x, class = "ra_unsupported_operator")
  expect_error(x == x, class = "ra_unsupported_operator")
})
