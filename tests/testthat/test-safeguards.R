## Session safeguards for the included correctly rounded evaluator.
##
## The external sentinel oracle proves where the expected values came from.
## These tests prove the package-side mechanism: complete coverage, bitwise
## comparison, a control that breaks the evaluator, re-entrant loading, one
## warning per degraded transition, queryable state and first-use auditing.

test_that("the sentinel table covers every function with independent cases", {
  sentinels <- ra_sentinels()
  functions <- ra_operator_table("functions")$fun

  expect_true(is.data.frame(sentinels))
  expect_true(all(c("fun", "x", "cr", "role", "source", "source_index") %in%
                    names(sentinels)))
  expect_setequal(sentinels$fun, functions)
  expect_true(all(table(sentinels$fun) == 8L))
  expect_true(all(is.finite(sentinels$x)))
  expect_false(anyNA(sentinels$cr))
  expect_false(any(grepl("route", sentinels$role, ignore.case = TRUE)))
  expect_true(all(sentinels$role[sentinels$fun == "sqrt"] == "sample_case"))
  expect_true(all(sentinels$role[sentinels$fun != "sqrt"] == "hard_case"))
})

test_that("S1: the included evaluator matches every sentinel bit for bit", {
  check <- ra_check_sentinels()

  expect_identical(nrow(check), 128L)
  expect_true(all(check$ok))
  expect_identical(check$expected_bits, check$observed_bits)
  expect_true(all(table(check$fun) == 8L))
})

test_that("S1 control: a perturbed evaluator fails only where it was changed", {
  check_sentinels <- ra_check_sentinels
  namespace <- asNamespace("RobustArithmetic")
  evaluator <- get(".ra_cr", envir = namespace)
  successor <- get("ra_succ", envir = namespace)
  mocked <- new.env(parent = environment(check_sentinels))
  mocked$.ra_cr <- function(fun, x) {
    value <- evaluator(fun, x)
    if (identical(fun, "sin")) {
      finite <- is.finite(value)
      value[finite] <- successor(value[finite])
    }
    value
  }
  environment(check_sentinels) <- mocked

  check <- check_sentinels()
  expect_true(all(!check$ok[check$fun == "sin"]))
  expect_true(all(check$ok[check$fun != "sin"]))
})

test_that("D1 and D2: loading is re-entrant and degradation speaks once", {
  restore_state <- preserve_fast_level_state()
  on.exit(restore_state(), add = TRUE)

  namespace <- asNamespace("RobustArithmetic")
  evaluator <- get(".ra_cr", envir = namespace)
  successor <- get("ra_succ", envir = namespace)
  locked <- bindingIsLocked(".ra_cr", namespace)
  set_evaluator <- function(value) {
    if (bindingIsLocked(".ra_cr", namespace)) unlockBinding(".ra_cr", namespace)
    assign(".ra_cr", value, envir = namespace)
    if (locked) lockBinding(".ra_cr", namespace)
  }
  on.exit(set_evaluator(evaluator), add = TRUE)

  broken <- function(fun, x) {
    value <- evaluator(fun, x)
    if (identical(fun, "sin")) {
      finite <- is.finite(value)
      value[finite] <- successor(value[finite])
    }
    value
  }

  set_evaluator(broken)
  get(".onLoad", envir = namespace)("", "RobustArithmetic")
  status <- ra_fast_level_status()
  expect_true(status$degraded)
  expect_match(status$reason, "sin", fixed = TRUE)
  expect_true(any(status$sentinels$fun == "sin" & !status$sentinels$ok))
  expect_null(status$audit)
  expect_message(
    get(".onAttach", envir = namespace)("", "RobustArithmetic"),
    "DEGRADED.*sin"
  )

  if (ra_has_mpfr()) {
    expect_warning(
      result <- ra_elem("sin", ra_interval(0.2, 0.3)),
      class = "ra_fast_level_unsafe"
    )
    expect_identical(ra_prov(result), "theorem")
    expect_silent(second <- ra_elem("sin", ra_interval(0.4, 0.5)))
    expect_identical(ra_prov(second), "theorem")
  } else {
    expect_error(ra_elem("sin", ra_interval(0.2, 0.3)),
                 class = "ra_fast_level_unsafe")
    expect_error(ra_elem("sin", ra_interval(0.4, 0.5)),
                 class = "ra_fast_level_unsafe")
  }

  set_evaluator(evaluator)
  get(".onLoad", envir = namespace)("", "RobustArithmetic")
  healthy <- ra_fast_level_status()
  expect_false(healthy$degraded)
  expect_identical(healthy$reason, character(0))
  expect_true(all(healthy$sentinels$ok))
  expect_null(healthy$audit)
  expect_message(
    get(".onAttach", envir = namespace)("", "RobustArithmetic"),
    NA
  )
})

test_that("the public status replaces the environment anchor", {
  exports <- getNamespaceExports("RobustArithmetic")
  expect_true("ra_fast_level_status" %in% exports)
  expect_false("ra_environment_anchor" %in% exports)
  expect_identical(length(exports), 60L)

  status <- ra_fast_level_status()
  expect_identical(names(status),
                   c("degraded", "reason", "sentinels", "audit"))
  expect_type(status$degraded, "logical")
  expect_type(status$reason, "character")
  expect_true(is.null(status$sentinels) || is.data.frame(status$sentinels))
  expect_true(is.null(status$audit) || is.data.frame(status$audit))
})

test_that("S2 control: an audit above slack degrades and warns once", {
  skip_if_not(ra_has_mpfr(), "the audit needs Rmpfr")
  restore_state <- preserve_fast_level_state()
  on.exit(restore_state(), add = TRUE)

  namespace <- asNamespace("RobustArithmetic")
  on_load <- get(".onLoad", envir = namespace)
  on_load("", "RobustArithmetic")

  real_measurement <- get("ra_measure_library_error", envir = namespace)
  locked <- bindingIsLocked("ra_measure_library_error", namespace)
  set_measurement <- function(value) {
    if (bindingIsLocked("ra_measure_library_error", namespace)) {
      unlockBinding("ra_measure_library_error", namespace)
    }
    assign("ra_measure_library_error", value, envir = namespace)
    if (locked) lockBinding("ra_measure_library_error", namespace)
  }
  on.exit(set_measurement(real_measurement), add = TRUE)

  failed_measurement <- function(n = 20000L, seed = NULL, bits = 300L) {
    functions <- ra_operator_table("functions")$fun
    slack <- vapply(functions, ra_slack, integer(1L))
    observed <- rep(0.25, length(functions))
    observed[functions == "sin"] <- slack[functions == "sin"] + 1
    data.frame(
      fun = functions,
      n = rep(as.integer(n), length(functions)),
      observed = observed,
      published = rep(0.5, length(functions)),
      slack = unname(slack),
      used = observed / slack,
      stringsAsFactors = FALSE
    )
  }
  expect_identical(names(formals(failed_measurement)),
                   names(formals(real_measurement)))
  set_measurement(failed_measurement)

  expect_warning(
    result <- ra_elem("sin", ra_interval(0.2, 0.3)),
    class = "ra_fast_level_unsafe"
  )
  expect_identical(ra_prov(result), "theorem")
  status <- ra_fast_level_status()
  expect_true(status$degraded)
  expect_match(status$reason, "session audit")
  expect_match(status$reason, "sin", fixed = TRUE)
  expect_true(is.data.frame(status$audit))
  expect_silent(second <- ra_elem("cos", ra_interval(0.2, 0.3)))
  expect_identical(ra_prov(second), "theorem")
})

test_that("S2: the first healthy fast use audits once and caches the result", {
  skip_if_not(ra_has_mpfr(), "the audit needs Rmpfr")
  restore_state <- preserve_fast_level_state()
  on.exit(restore_state(), add = TRUE)

  namespace <- asNamespace("RobustArithmetic")
  get(".onLoad", envir = namespace)("", "RobustArithmetic")
  expect_silent(ra_elem("exp", ra_interval(0, 1)))
  first <- ra_fast_level_status()
  expect_false(first$degraded)
  expect_true(is.data.frame(first$audit))
  expect_identical(nrow(first$audit), 16L)

  expect_silent(ra_elem("log", ra_interval(1, 2)))
  second <- ra_fast_level_status()
  expect_identical(second$audit, first$audit)
})

test_that("S3: provenance is carried, propagated by weakness, and printed", {
  restore_fast_level <- hold_fast_level_open()
  on.exit(restore_fast_level(), add = TRUE)
  theorem <- ra_interval(1, 2)
  expect_identical(ra_prov(theorem), "theorem")
  measured <- ra_elem("exp", theorem)
  expect_identical(ra_prov(measured), "measured")
  expect_identical(ra_prov(theorem + theorem), "theorem")
  expect_identical(ra_prov(theorem + measured), "measured")
  expect_identical(ra_prov(measured * measured), "measured")

  both <- c(theorem, measured)
  expect_identical(ra_prov(both), c("theorem", "measured"))
  expect_identical(ra_prov(both[2L]), "measured")
  expect_match(paste(capture.output(print(measured)), collapse = "\n"),
               "measured")
  expect_no_match(paste(capture.output(print(theorem)), collapse = "\n"),
                  "measured")
  expect_match(paste(capture.output(print(summary(both))), collapse = "\n"),
               "measured")
  expect_true("prov" %in% names(as.data.frame(both)))
  if (ra_has_mpfr()) {
    rigorous <- ra_elem("exp", theorem, level = "rigorous")
    expect_identical(ra_prov(rigorous), "theorem")
  }
})

test_that("S3: the weakest provenance also flows through expressions", {
  restore_fast_level <- hold_fast_level_open()
  on.exit(restore_fast_level(), add = TRUE)
  result <- ra_enclose_expr(quote(exp(x) + 1), ra_interval(0, 1))
  expect_identical(ra_prov(result), "measured")
  if (ra_has_mpfr()) {
    rigorous <- ra_enclose_expr(
      quote(exp(x) + 1), ra_interval(0, 1), level = "rigorous"
    )
    expect_identical(ra_prov(rigorous), "theorem")
  }
})
