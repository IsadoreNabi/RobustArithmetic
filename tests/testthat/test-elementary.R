## The positive controls of phase two, written before the piece they judge.
##
## Each of these describes a way the elementary layer could be wrong, and
## arranges for the wrong version to be built and to fail. A test that only
## exercises the correct implementation reports that the code does what it does;
## these report that a specific defect would have been caught.

test_that("CP-3: a wrong monotonicity class breaks containment", {
  ## cosh has its minimum in the interior of any interval straddling zero, so
  ## treating it as increasing puts the lower endpoint at cosh(a), which is
  ## above the true minimum of 1 whenever a < 0.
  x <- ra_interval(-2, 3)
  right <- ra_elem("cosh", x)
  wrong_lo <- cosh(-2)
  expect_true(ra_inf(right) <= 1)
  expect_true(wrong_lo > 1)
  ## the true minimum is attained and is exactly one
  expect_true(ra_inf(right) <= min(cosh(seq(-2, 3, length.out = 2001))))
  expect_true(wrong_lo > min(cosh(seq(-2, 3, length.out = 2001))))
})

test_that("CP-4: ignoring interior extrema of sin breaks containment", {
  ## On [0, pi] both endpoints of sin are within a rounding step of zero and the
  ## maximum is interior. An implementation that read only the endpoints would
  ## return an interval of width about 1e-16 for a function whose range is
  ## [0, 1].
  x <- ra_interval(0, pi)
  got <- ra_elem("sin", x)
  endpoints_only_hi <- max(sin(0), sin(pi))
  expect_true(ra_sup(got) >= 1)
  expect_true(endpoints_only_hi < 1e-15)
  ## a dense sample is inside the real answer and outside the endpoint-only one
  t <- seq(0, pi, length.out = 5001)
  expect_true(all(sin(t) >= ra_inf(got) & sin(t) <= ra_sup(got)))
  expect_false(all(sin(t) <= endpoints_only_hi))
})

test_that("CP-5: an interval straddling a pole of tan is entire and trivial", {
  x <- ra_interval(1, 2)
  got <- ra_elem("tan", x)
  expect_true(ra_is_entire(got))
  expect_identical(ra_dec(got), "trv")
  ## the monotone reading would have produced an inverted pair, which is the
  ## signal that it is wrong: tan(1) is positive and tan(2) is negative.
  expect_true(tan(1) > 0 && tan(2) < 0)
  expect_error(ra_interval(tan(1), tan(2)), class = "ra_bad_endpoints")
  ## and away from the pole tan is monotone and common
  near <- ra_elem("tan", ra_interval(0.1, 1.0))
  expect_identical(ra_dec(near), "com")
  t <- seq(0.1, 1.0, length.out = 2001)
  expect_true(all(tan(t) >= ra_inf(near) & tan(t) <= ra_sup(near)))
})

test_that("CP-6: domain errors are trivial, never ill, and never NaN", {
  part <- ra_elem("log", ra_interval(-1, 2))
  expect_identical(ra_dec(part), "trv")
  expect_identical(ra_inf(part), -Inf)
  expect_true(ra_sup(part) >= log(2))
  expect_false(ra_is_nai(part))

  outside <- ra_elem("log", ra_interval(-2, -1))
  expect_true(ra_is_empty(outside))
  expect_identical(ra_dec(outside), "trv")

  wide <- ra_elem("asin", ra_interval(-2, 2))
  expect_identical(ra_dec(wide), "trv")
  expect_true(ra_inf(wide) <= -pi / 2 && ra_sup(wide) >= pi / 2)
  expect_false(anyNA(c(ra_inf(wide), ra_sup(wide))))

  inside <- ra_elem("log", ra_interval(1, 2))
  expect_identical(ra_dec(inside), "com")
})

test_that("CP: com asserts a bounded argument box, not only a bounded result", {
  ## atan of the whole line is bounded, but the argument box is not, and the
  ## standard reserves com for a bounded argument box.
  got <- ra_elem("atan", ra_entire())
  expect_true(ra_inf(got) <= -pi / 2 && ra_sup(got) >= pi / 2)
  expect_identical(ra_dec(got), "dac")
  ## and the same function on a bounded box is common
  expect_identical(ra_dec(ra_elem("atan", ra_interval(-1, 1))), "com")
})

test_that("the declared monotonicity classes are verified, not asserted", {
  ## The class table is checked against the functions themselves on a mesh
  ## inside each domain, and a class deliberately set wrong must be caught.
  rep <- ra_verify_monotonicity()
  expect_true(rep$agrees)
  expect_identical(rep$disagreeing, character(0))

  wrong <- ra_verify_monotonicity(classes = c(cosh = "increasing"))
  expect_false(wrong$agrees)
  expect_true("cosh" %in% wrong$disagreeing)
})

test_that("the exact extrema carry no slack", {
  ## The supremum of sin over an interval containing a maximum is exactly one,
  ## because it is the mathematical value and not a library evaluation.
  full <- ra_elem("sin", ra_interval(0, 7))
  expect_identical(ra_inf(full), -1)
  expect_identical(ra_sup(full), 1)
  expect_identical(ra_inf(ra_elem("cosh", ra_interval(-1, 1))), 1)
  expect_identical(ra_inf(ra_elem("sqrt", ra_interval(0, 4))), 0)
})

test_that("a point interval is enclosed by its own evaluation widened by slack", {
  for (f in ra_operator_table()$fun) {
    v <- switch(f,
                log = , log2 = , log10 = , sqrt = 0.7,
                log1p = -0.3,
                asin = , acos = 0.4,
                0.3)
    got <- ra_elem(f, ra_interval(v, v))
    y <- do.call(f, list(v))
    expect_true(ra_inf(got) <= y && ra_sup(got) >= y,
                label = paste0(f, " encloses its own evaluation"))
    ## the width is the slack, spent in both directions and no more
    steps <- ra_slack(f)
    lo <- y
    hi <- y
    for (k in seq_len(steps)) {
      lo <- ra_pred(lo)
      hi <- ra_succ(hi)
    }
    expect_true(ra_inf(got) >= lo && ra_sup(got) <= hi,
                label = paste0(f, " spends no more than its declared slack"))
  }
})

test_that("the enclosure does not depend on how many intervals were passed", {
  ## R reaches the system math library by more than one route and the routes
  ## were measured not to agree to the last bit. An enclosure that changed with
  ## the batch size would be wrong in a way nothing printed would show, so the
  ## invariant is asserted rather than assumed to follow from the code.
  set.seed(80L)
  x <- c(2.5698953698477605e-08, 1e-9, 0.3, 2.7, -1.4891097021325252e-08,
         2^-30, 123.456, -0.75)
  for (f in c("sin", "cos", "tan", "exp", "tanh", "atan", "expm1")) {
    batch <- ra_elem(f, ra_interval(x, x))
    one <- vapply(x, function(v) ra_inf(ra_elem(f, ra_interval(v, v))),
                  numeric(1))
    expect_identical(ra_inf(batch), one,
                     label = paste0(f, ": batch equals one at a time"))
  }
})

test_that("the evaluation path in use is not the correctly rounded one", {
  ## This is the reason the slack is measured against the path in use instead
  ## of taken from the publication. At this argument the system math library,
  ## called from C, returns the correctly rounded sine; R returns the argument
  ## itself, one unit in the last place away. The assertion is written against
  ## the multiprecision value rather than against any internal of R, so it says
  ## what it means and does not depend on how R was compiled.
  skip_if_not(ra_has_mpfr(), "the referent needs Rmpfr")
  x <- 2.5698953698477605e-08
  exact <- Rmpfr::mpfr(x, 300L)
  z <- sin(exact)
  correct <- ra_to_double(z, "down")
  expect_identical(correct, ra_to_double(z, "up") - 2^-78)
  expect_false(identical(sin(x), correct))
  ## and the enclosure holds both, which is the claim that matters
  enc <- ra_elem("sin", ra_interval(x, x))
  expect_true(ra_inf(enc) <= correct && ra_sup(enc) >= correct)
  expect_true(ra_inf(enc) <= sin(x) && ra_sup(enc) >= sin(x))
})

test_that("the error of the path in use is measured against the publication", {
  skip_if_not(ra_has_mpfr(), "the measurement needs Rmpfr")
  m <- ra_measure_library_error(n = 3000L)
  expect_identical(nrow(m), 16L)
  expect_true(all(c("observed", "published", "slack", "used") %in% names(m)))
  ## The claim -- that the declared slack covers what the path in use actually
  ## does -- is a claim about THIS MACHINE, and the slack was measured on
  ## another one. So it is asserted where it can be true, and where it cannot,
  ## what is asserted instead is the thing that must never fail: that the
  ## package NOTICED. A library that breaks the published bound and a package
  ## that does not say so is the only outcome this test exists to forbid.
  covers <- all(is.na(m$observed) | m$observed <= m$slack)
  if (covers) {
    expect_true(covers)
  } else {
    suppressWarnings(try(ra_elem("exp", ra_interval(0, 1)), silent = TRUE))
    expect_true(isTRUE(.ra_state$fast_degraded))
  }
  ## and the measurement resolves fractions of a unit, which is what it is for
  expect_true(any(!is.na(m$observed) & m$observed %% 1 != 0))
})

test_that("empty and Not-an-Interval propagate through the elementary layer", {
  expect_true(ra_is_empty(ra_elem("exp", ra_empty())))
  expect_identical(ra_dec(ra_elem("exp", ra_empty())), "trv")
  expect_true(ra_is_nai(ra_elem("exp", ra_nai())))
  expect_identical(ra_dec(ra_elem("exp", ra_nai())), "ill")
})

test_that("a symbol outside the closed table is refused by name", {
  expect_error(ra_elem("gamma", ra_interval(1, 2)),
               class = "ra_symbol_not_in_table")
  expect_error(ra_elem("floor", ra_interval(1, 2)),
               class = "ra_symbol_not_in_table")
})

test_that("the elementary layer is vectorised over intervals", {
  x <- c(ra_interval(0, 1), ra_interval(2, 3), ra_empty())
  got <- ra_elem("exp", x)
  expect_identical(length(got), 3L)
  expect_true(ra_inf(got)[1] <= 1 && ra_sup(got)[1] >= exp(1))
  expect_true(ra_is_empty(got)[3])
})

test_that("the periodic frontier is set by the format, not by the reduction", {
  ## Pre-registered in dev/PREREGISTRO_FASE_2.md, section 4-bis: the magnitude
  ## at which the sine of a box stops resolving below the whole range is
  ## governed by the width of the box against the period, not by the precision
  ## of the argument reduction. The criterion can fail in both directions.
  fr <- ra_periodic_frontier(rel_width = 2^-20)
  expect_false(is.na(fr$fast_exponent))
  expect_true(abs(fr$fast_exponent - fr$granularity_exponent) <= 1L)
  ## below the frontier the enclosure is strictly narrower than [-1, 1]
  a <- fr$fast_witness
  expect_false(is.na(a))
  narrow <- ra_elem("sin", ra_interval(a, ra_succ(a + a * 2^-20)))
  expect_true(ra_wid(narrow) < 2)
})

test_that("CP-7: the ladder resolves what the fast level cannot, and abstains at the top", {
  skip_if_not(ra_has_mpfr(), "the rigorous level needs Rmpfr")
  ## the fast level is held open: this test is about the LADDER -- that it
  ## climbs when the fast level cannot settle a question, and that it abstains
  ## with its budget printed when no precision can. Where the gate has degraded
  ## the fast level, the first rung is already the rigorous one, there is
  ## nothing for the ladder to climb from, and the test would be measuring the
  ## machine's library instead of the ladder. The widths asserted below come
  ## from the declared slack steps and not from the library's accuracy.
  old_degraded <- .ra_state$fast_degraded
  on.exit(assign("fast_degraded", old_degraded, envir = .ra_state), add = TRUE)
  assign("fast_degraded", FALSE, envir = .ra_state)

  ## A question the fast level cannot settle: an enclosure of sin(1) narrower
  ## than one unit in the last place. The fast level spends three slack steps
  ## per side and so returns six, and no amount of slack can be undone; the
  ## rigorous level returns one by theorem.
  decide <- function(iv) ra_wid(iv) < 2^-52
  fast <- ra_elem("sin", ra_interval(1, 1))
  expect_false(decide(fast))

  got <- ra_elem_escalate("sin", ra_interval(1, 1), decide)
  expect_true(got$decided)
  expect_true(got$bits %in% ra_precision_ladder())

  ## A question no precision can settle, because the range of sin over [0, 1]
  ## has positive width: the ladder must reach the top and say so with the
  ## budget printed, rather than force a verdict or fall silent.
  impossible <- function(iv) ra_wid(iv) == 0
  top <- ra_elem_escalate("sin", ra_interval(0, 1), impossible)
  expect_false(top$decided)
  expect_identical(top$bits, max(ra_precision_ladder()))
  expect_match(top$word, "no verdict at this budget \\(848 bits\\)")
})

test_that("the rigorous level encloses and is no wider than the fast one", {
  skip_if_not(ra_has_mpfr(), "the rigorous level needs Rmpfr")
  set.seed(80L)
  for (f in c("exp", "log", "sin", "cos", "tan", "tanh", "sqrt", "atan")) {
    v <- switch(f, log = , sqrt = runif(50, 0.1, 3), runif(50, -1, 1))
    x <- ra_interval(v, v)
    fast <- ra_elem(f, x, level = "fast")
    rig <- ra_elem(f, x, level = "rigorous", precision = 106L)
    expect_true(all(ra_wid(rig) <= ra_wid(fast)),
                label = paste0(f, ": rigorous is no wider than fast"))
    ## and the rigorous enclosure is inside the fast one, which is the
    ## statement that the two levels agree about where the answer is
    expect_true(all(ra_inf(rig) >= ra_inf(fast) & ra_sup(rig) <= ra_sup(fast)),
                label = paste0(f, ": rigorous sits inside fast"))
  }
})

test_that("the rigorous level does not move the periodic frontier", {
  ## The second pre-registered prediction of section 4-bis, and the one that
  ## would expose a sloppy fast reduction if it were wrong: more bits in the
  ## reduction buy at most one exponent, because the box width and not the
  ## rounding is what puts an integer in the index interval.
  skip_if_not(ra_has_mpfr(), "the rigorous level needs Rmpfr")
  fr <- ra_periodic_frontier(rel_width = 2^-20)
  expect_false(is.na(fr$rigorous_exponent))
  expect_true((fr$rigorous_exponent - fr$fast_exponent) %in% c(0L, 1L))
})

test_that("without the backend the rigorous level says what is lost", {
  msg <- ra_message_no_mpfr("the escalation of sin() to 212 bits")
  expect_match(msg, "Rmpfr")
  expect_match(msg, "valid")
})

test_that("the escalation object carries everything its class needs", {
  skip_if_not(ra_has_mpfr(), "the rigorous level needs Rmpfr")
  got <- ra_elem_escalate("exp", ra_interval(1, 1), function(iv) TRUE)
  expect_s3_class(got, "ra_escalation")
  expect_match(format(got), "exp")
  expect_output(print(got), "exp")
  d <- as.data.frame(got)
  expect_true(all(c("fun", "lo", "hi", "dec", "bits", "decided", "word") %in%
                    names(d)))
  s <- summary(got)
  expect_s3_class(s, "ra_escalation_summary")
  expect_output(print(s), "exp")
})
