## GATE 3 -- expressions against dense sampling of their own range.
##
## The claim of phase three is that the enclosure of an expression contains its
## range. The referent is the expression itself, evaluated densely at points of
## the box in ordinary arithmetic: every sampled value must be inside. That is a
## necessary condition and not a sufficient one, which is why it is run over a
## battery of expressions of different shapes rather than over a chosen few, and
## why the boxes are drawn at many widths.
##
## The battery is the set of equations the suite of QuantDialectics actually
## parses, read out of its tests, together with the three normal forms of the
## bifurcation study. What it is not is a set of expressions chosen here to suit
## the implementation: two of the equations that suite parses are refused by the
## closed table, and their refusal is part of the gate.

## The equations QuantDialectics parses in its own suite, as expressions of one
## variable, with the parameters supplied. Names kept as they are written there.
gate3_battery <- list(
  list(e = quote(a), env = list(a = 1.5)),
  list(e = quote(a * Z), env = list(a = 2)),
  list(e = quote(a * Z + 1), env = list(a = 2)),
  list(e = quote(a * Z + b * Z^2), env = list(a = 1, b = -1)),
  list(e = quote(a * Z^3), env = list(a = 0.5)),
  list(e = quote(b * Z^2), env = list(b = -1)),
  list(e = quote(r + b * Z), env = list(r = 0.3, b = -1)),
  list(e = quote(r + b * Z^2), env = list(r = 0.3, b = -1)),
  list(e = quote(r * Z), env = list(r = 0.7)),
  list(e = quote(r * Z * (1 - Z / K)), env = list(r = 0.7, K = 4)),
  list(e = quote(r * Z + b * Z^2), env = list(r = 0.7, b = -1)),
  list(e = quote(r * Z + b * Z^3), env = list(r = 0.7, b = -1)),
  ## the three normal forms with b = -1, which is how the bifurcation study
  ## writes them
  list(e = quote(r - Z^2), env = list(r = 0.5)),
  list(e = quote(r * Z - Z^2), env = list(r = 0.5)),
  list(e = quote(r * Z - Z^3), env = list(r = 0.5)),
  ## expressions exercising the elementary layer, without which this gate would
  ## test the kernel again and not phase three
  list(e = quote(exp(Z) - Z^2), env = list()),
  list(e = quote(sin(Z) * cos(Z)), env = list()),
  list(e = quote(tanh(Z) + Z), env = list()),
  list(e = quote(atan(Z) / (1 + Z^2)), env = list()),
  list(e = quote(exp(sin(Z)) - Z), env = list()),
  list(e = quote(Z * sin(Z) - cos(Z)), env = list()),
  list(e = quote(sinh(Z) - Z - Z^3 / 6), env = list()),
  list(e = quote((Z - 1) * (Z + 1) * Z), env = list()),
  list(e = quote(Z / (2 + Z^2)), env = list())
)

## The same expression as an ordinary function, for the dense sampling.
gate3_fun <- function(item) {
  function(z) eval(item$e, c(item$env, list(Z = z)))
}

test_that("GATE 3: every sampled value of the range is inside the enclosure", {
  skip_on_cran()
  n_box <- as.integer(Sys.getenv("RA_GATE3_BOXES", "400"))
  n_in <- as.integer(Sys.getenv("RA_GATE3_POINTS", "2000"))

  worst <- data.frame(expr = character(0), routes = character(0),
                      max_wid = numeric(0), stringsAsFactors = FALSE)

  for (k in seq_along(gate3_battery)) {
    item <- gate3_battery[[k]]
    f <- gate3_fun(item)
    set.seed(3000L + k)
    centre <- stats::runif(n_box, -3, 3)
    half <- 2^stats::runif(n_box, -30, 1.5)
    violations <- 0L
    widths <- numeric(n_box)
    routes <- character(0)

    for (j in seq_len(n_box)) {
      a <- centre[j] - half[j]
      b <- centre[j] + half[j]
      got <- ra_enclose_expr(item$e, ra_interval(a, b), var = "Z",
                             env = item$env)
      routes <- union(routes, attr(got, "ra_routes"))
      widths[j] <- ra_wid(got)
      t <- c(a, b, seq(a, b, length.out = n_in))
      y <- f(t)
      y <- y[is.finite(y)]
      if (!length(y)) next
      violations <- violations +
        sum(y < ra_inf(got) | y > ra_sup(got), na.rm = TRUE)
    }
    expect_identical(violations, 0L,
                     label = paste0("GATE 3 ", deparse(item$e),
                                    ": sampled values outside the enclosure (",
                                    n_box, " boxes x ", n_in + 2L, " points)"))
    worst <- rbind(worst, data.frame(
      expr = deparse(item$e),
      routes = paste(routes, collapse = "+"),
      max_wid = max(widths[is.finite(widths)]),
      stringsAsFactors = FALSE))
  }

  cat("\nGATE 3 routes that contributed, and the widest enclosure met:\n")
  print(worst, row.names = FALSE, digits = 4)
  ## every expression of the battery had at least the natural route, and the
  ## derivative routes fired on more than a handful, which is what makes the
  ## gate a test of phase three and not of the kernel
  expect_true(all(grepl("natural", worst$routes)))
  expect_gt(sum(grepl("mean_value", worst$routes)), 15L)
  expect_gt(sum(grepl("monotonic", worst$routes)), 5L)
})

test_that("GATE 3: the two equations the closed table refuses are refused", {
  ## Read from the same suite as the rest of the battery. A gate whose battery
  ## contained only what the package accepts would not be testing the table.
  expect_error(ra_check_expr(quote(r * besselJ(Z, 1) + b)),
               class = "ra_symbol_not_in_table")
  expect_error(ra_check_expr(quote(noexiste(x))),
               class = "ra_symbol_not_in_table")
})

test_that("GATE 3: a narrow box gives a narrow enclosure, so the gate is not vacuous", {
  ## Containment over a box the enclosure had widened to the whole line would
  ## be trivially true. The width is therefore checked to shrink with the box.
  skip_on_cran()
  for (k in seq_along(gate3_battery)) {
    item <- gate3_battery[[k]]
    if (identical(item$e, quote(a))) next  ## a constant has no box to shrink
    wide <- ra_wid(ra_enclose_expr(item$e, ra_interval(0.4, 1.4), var = "Z",
                                   env = item$env))
    narrow <- ra_wid(ra_enclose_expr(item$e, ra_interval(0.9, 0.9 + 2^-20),
                                     var = "Z", env = item$env))
    expect_true(narrow < wide,
                label = paste0("GATE 3 ", deparse(item$e),
                               ": the enclosure shrinks with the box"))
    expect_true(narrow < 1e-3,
                label = paste0("GATE 3 ", deparse(item$e),
                               ": a box of width 2^-20 gives a narrow answer"))
  }
})

test_that("GATE 3: the rigorous level contains the fast one on the battery", {
  skip_on_cran()
  skip_if_not(ra_has_mpfr(), "the gate needs Rmpfr")
  for (k in seq_along(gate3_battery)) {
    item <- gate3_battery[[k]]
    x <- ra_interval(0.3, 0.8)
    fast <- ra_enclose_expr(item$e, x, var = "Z", env = item$env)
    rig <- ra_enclose_expr(item$e, x, var = "Z", env = item$env,
                           level = "rigorous", precision = 106L)
    f <- gate3_fun(item)
    t <- seq(0.3, 0.8, length.out = 5001)
    y <- f(t)
    y <- y[is.finite(y)]
    expect_true(all(y >= ra_inf(rig) & y <= ra_sup(rig)),
                label = paste0("GATE 3 rigorous ", deparse(item$e),
                               ": contains the sampled range"))
    expect_true(ra_wid(rig) <= ra_wid(fast) * (1 + 1e-9),
                label = paste0("GATE 3 rigorous ", deparse(item$e),
                               ": no wider than fast"))
  }
})
