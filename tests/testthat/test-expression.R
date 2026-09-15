## Phase three: expressions, and the dependence problem it refuses to hide.

test_that("CP: x - x over [-1, 1] is [-2, 2], and the choice is deliberate", {
  ## The control the design names by hand. The natural extension must
  ## overestimate here, because concealing it would mean rewriting expressions,
  ## and a package that is exact on the expressions it happens to recognise is
  ## unpredictable on the ones it does not.
  x <- ra_interval(-1, 1)
  got <- ra_eval_natural(quote(x - x), list(x = x))
  expect_true(ra_inf(got) <= -2 && ra_sup(got) >= 2)
  expect_true(ra_wid(got) >= 4)
  ## and the true range is the single point zero, which the enclosure contains
  expect_true(ra_inf(got) <= 0 && ra_sup(got) >= 0)
})

test_that("a symbol outside the closed table is refused, by name", {
  expect_error(ra_check_expr(quote(besselJ(Z, 1))),
               class = "ra_symbol_not_in_table")
  expect_error(ra_check_expr(quote(noexiste(x))),
               class = "ra_symbol_not_in_table")
  expect_error(ra_eval_natural(quote(gamma(x)), list(x = ra_interval(1, 2))),
               class = "ra_symbol_not_in_table")
  ## and an admitted one is not
  expect_identical(ra_check_expr(quote(r * Z + b * Z^3)), c("r", "Z", "b"))
})

test_that("an unbound variable is a typed refusal and not a silent NA", {
  expect_error(ra_eval_natural(quote(x + y), list(x = ra_interval(0, 1))),
               class = "ra_unbound_variable")
})

test_that("the three routes are all valid and the intersection is no wider", {
  ## The box is above the turning point of the derivative, which sits at the
  ## square root of two thirds, so all three routes apply and can be compared.
  e <- quote(x^3 - 2 * x)
  x <- ra_interval(0.9, 1.3)
  nat <- ra_enclose_expr(e, x, methods = "natural")
  mv <- ra_enclose_expr(e, x, methods = "mean_value")
  mono <- ra_enclose_expr(e, x, methods = "monotonic")
  all3 <- ra_enclose_expr(e, x)

  t <- seq(0.9, 1.3, length.out = 4001)
  y <- t^3 - 2 * t
  for (nm in c("nat", "mv", "mono", "all3")) {
    iv <- get(nm)
    expect_true(all(y >= ra_inf(iv) & y <= ra_sup(iv)),
                label = paste0(nm, " contains the sampled range"))
  }
  expect_true(ra_wid(all3) <= ra_wid(nat))
  expect_true(ra_wid(all3) <= ra_wid(mv))
  expect_identical(attr(all3, "ra_routes"),
                   c("natural", "mean_value", "monotonic"))
})

test_that("the monotonicity route stands down when the derivative spans zero", {
  ## On a box containing the turning point of x^2 the derivative contains zero,
  ## so the route must not be used; claiming it would put the range at the hull
  ## of the endpoints and lose the minimum.
  got <- ra_enclose_expr(quote(x^2), ra_interval(-1, 2))
  expect_false("monotonic" %in% attr(got, "ra_routes"))
  expect_true(ra_inf(got) <= 0)
  t <- seq(-1, 2, length.out = 3001)
  expect_true(all(t^2 >= ra_inf(got) & t^2 <= ra_sup(got)))

  ## and it stands up when the box is on one side of it
  right <- ra_enclose_expr(quote(x^2), ra_interval(0.5, 2))
  expect_true("monotonic" %in% attr(right, "ra_routes"))
})

test_that("the centered form beats the natural one on a narrow box", {
  ## This is the reason the centered form exists, and it is asserted rather
  ## than assumed: on a narrow box the dependence overestimate of the natural
  ## extension grows with the number of occurrences and the centered form does
  ## not.
  e <- quote(x * x - x)
  x <- ra_interval(2, 2 + 2^-20)
  nat <- ra_enclose_expr(e, x, methods = "natural")
  mv <- ra_enclose_expr(e, x, methods = "mean_value")
  expect_true(ra_wid(mv) < ra_wid(nat))
})

test_that("the general power needs a positive base and says so by decoration", {
  restore_fast_level <- hold_fast_level_open()
  on.exit(restore_fast_level(), add = TRUE)
  ok <- ra_eval_natural(quote(x^0.5), list(x = ra_interval(1, 4)))
  expect_identical(ra_dec(ok), "com")
  expect_true(ra_inf(ok) <= 1 && ra_sup(ok) >= 2)

  bad <- ra_eval_natural(quote(x^0.5), list(x = ra_interval(-1, 4)))
  expect_identical(ra_dec(bad), "trv")
  expect_false(ra_is_nai(bad))

  ## an integer exponent takes the tight route and handles a base spanning zero
  spanning <- ra_eval_natural(quote(x^2), list(x = ra_interval(-1, 4)))
  expect_identical(ra_dec(spanning), "com")
  expect_true(ra_inf(spanning) <= 0 && ra_sup(spanning) >= 16)
})

test_that("division by an interval containing zero widens and weakens", {
  got <- ra_eval_natural(quote(1 / x), list(x = ra_interval(-1, 1)))
  expect_true(ra_is_entire(got))
  expect_identical(ra_dec(got), "trv")
})

test_that("the rigorous level of an expression is no wider than the fast one", {
  skip_if_not(ra_has_mpfr(), "the rigorous level needs Rmpfr")
  e <- quote(exp(x) - sin(x) * log(x))
  x <- ra_interval(0.5, 0.6)
  fast <- ra_enclose_expr(e, x, level = "fast")
  rig <- ra_enclose_expr(e, x, level = "rigorous", precision = 106L)
  expect_true(ra_wid(rig) <= ra_wid(fast))
  t <- seq(0.5, 0.6, length.out = 2001)
  y <- exp(t) - sin(t) * log(t)
  expect_true(all(y >= ra_inf(rig) & y <= ra_sup(rig)))
})
