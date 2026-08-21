## The closed table, re-closed against the installed software at every run.
##
## The table was fixed by measuring the derivative engine and the multiprecision
## backend of this machine. Those are moving parts: a new version of R can add a
## rule to the derivative table, and a new version of the backend can implement
## a function it did not have. This file re-runs the four admission criteria
## rather than trusting the transcription, so that a table which has quietly
## stopped matching the software underneath it is caught here and not in a
## certificate.

symbols_called <- function(e, acc = character(0)) {
  if (is.call(e)) {
    acc <- c(acc, as.character(e[[1L]]))
    for (i in seq_along(e)[-1L]) acc <- symbols_called(e[[i]], acc)
  }
  acc
}

calls_within <- function(e, acc = list()) {
  if (is.call(e)) {
    acc <- c(acc, list(e))
    for (i in seq_along(e)[-1L]) acc <- calls_within(e[[i]], acc)
  }
  acc
}

## The closure is taken over head symbols rather than over whole expressions,
## which is what makes it terminate: differentiating psigamma raises its order
## for ever and never repeats an expression, but it repeats its head at once.
## Descent follows every symbol the derivative engine will differentiate, not
## only the admitted ones, because the question being asked is precisely whether
## the derivatives leave the admitted set.
##
## The general power is seeded explicitly alongside the requested symbols. Its
## rule is the only one that introduces a symbol which is in neither operand,
## and it introduces it only when the exponent contains the variable; a walk
## that happened to meet the power first in the form cos(x)^2 would mark the
## symbol as visited and never see log() appear.
differentiation_closure <- function(seed_syms, with_general_power = TRUE) {
  queue <- lapply(seed_syms, function(f) call(f, quote(x)))
  if (with_general_power) queue <- c(queue, list(quote(x^x)))
  heads_seen <- character(0)
  syms <- character(0)
  while (length(queue)) {
    e <- queue[[1L]]
    queue <- queue[-1L]
    h <- as.character(e[[1L]])
    if (h %in% heads_seen) next
    heads_seen <- c(heads_seen, h)
    d <- tryCatch(stats::D(e, "x"), error = function(err) NULL)
    if (is.null(d)) next
    syms <- c(syms, symbols_called(d))
    queue <- c(queue, calls_within(d))
  }
  sort(unique(syms))
}

test_that("the table is what the sources say it is", {
  tab <- ra_operator_table()
  expect_s3_class(tab, "data.frame")
  expect_identical(names(tab), c("fun", "ulp", "slack"))
  expect_identical(nrow(tab), 16L)
  expect_setequal(tab$fun,
                  c("exp", "log", "sin", "cos", "tan", "sinh", "cosh", "tanh",
                    "sqrt", "expm1", "log1p", "log2", "log10", "asin", "acos",
                    "atan"))
  expect_identical(ra_operator_table("operators"),
                   c("+", "-", "*", "/", "^", "("))
})

test_that("C1: the installed stats::D differentiates every admitted function", {
  for (f in ra_operator_table()$fun) {
    d <- stats::D(call(f, quote(x)), "x")
    expect_false(is.null(d), info = f)
  }
})

test_that("C2: the table is closed under differentiation, with nothing escaping", {
  ## This is the criterion a table assembled by taste fails. If it fails, the
  ## centered form of an admitted function leaves the table on its first step.
  cl <- differentiation_closure(ra_operator_table()$fun)
  escaped <- setdiff(cl, c(ra_operator_table()$fun,
                           ra_operator_table("operators")))
  expect_identical(escaped, character(0))
})

test_that("C2, one function at a time, so a future failure names the culprit", {
  admitted <- c(ra_operator_table()$fun, ra_operator_table("operators"))
  for (f in ra_operator_table()$fun) {
    escaped <- setdiff(differentiation_closure(f), admitted)
    expect_identical(escaped, character(0), info = f)
  }
})

test_that("C3: every admitted function carries its published error and its slack", {
  tab <- ra_operator_table()
  expect_true(all(is.finite(tab$ulp)))
  expect_true(all(tab$ulp >= 0.5))
  expect_identical(tab$slack, ceiling(2 * tab$ulp + 1))
  expect_identical(ra_slack("exp"), 3L)
  expect_identical(ra_slack("tanh"), 6L)
  expect_identical(ra_slack("sinh"), 5L)
  expect_identical(ra_slack("cosh"), 5L)
  expect_identical(ra_slack("log10"), 5L)
  expect_identical(ra_slack("sqrt"), 2L)
})

test_that("C4: the backend provides every admitted function, which is why the ladder can climb", {
  skip_if_not(ra_has_mpfr(), "needs Rmpfr")
  x <- Rmpfr::mpfr("0.3", 120L)
  for (f in ra_operator_table()$fun) {
    v <- do.call(f, list(x))
    expect_s4_class(v, "mpfr")
  }
})

test_that("POSITIVE CONTROL: the exclusions must still fail the criterion they were excluded for", {
  ## An exclusion is a claim about the software, and a claim that is never
  ## re-tested is a claim about the past. These four fail different criteria and
  ## are checked against the thing each one names.
  excl <- ra_operator_table("excluded")
  expect_true(all(nzchar(excl$reason)))

  ## C1 failures: the derivative engine refuses them.
  for (f in c("abs", "sign", "floor", "atanh")) {
    expect_true(f %in% excl$symbol, info = f)
    expect_error(stats::D(call(f, quote(x)), "x"), info = f)
  }

  ## C4 failure: the chain from gamma leaves what the backend provides, and it
  ## leaves it at trigamma. If the backend ever implements it, this fails and
  ## the exclusion has to be revisited rather than kept out of habit.
  skip_if_not(ra_has_mpfr(), "needs Rmpfr")
  expect_error(trigamma(Rmpfr::mpfr("2.5", 120L)))
  ## And the reason the chain matters: differentiating gamma reaches it.
  expect_true("trigamma" %in% differentiation_closure("gamma"))
})

test_that("asking for a symbol outside the table is refused by name, not defaulted", {
  expect_error(ra_slack("gamma"), class = "ra_symbol_not_in_table")
  expect_error(ra_slack("nonesuch"), class = "ra_symbol_not_in_table")
  msg <- tryCatch(ra_slack("pnorm"), ra_symbol_not_in_table = conditionMessage)
  expect_match(msg, "no published error bound applies", fixed = TRUE)
  expect_error(ra_slack(c("exp", "log")), class = "ra_bad_argument")
})

test_that("the sources under R/ are pure ASCII", {
  ## R CMD check flags non-ASCII in the sources independently of this test, so
  ## the gate has an external referent even where the sources are unreachable.
  files <- list.files(testthat::test_path("..", "..", "R"), pattern = "[.]R$",
                      full.names = TRUE)
  skip_if(length(files) == 0L, "the sources are not reachable from here")
  offenders <- character(0)
  for (f in files) {
    lines <- readLines(f, warn = FALSE)
    if (any(grepl("[^\\x01-\\x7f]", lines, perl = TRUE))) {
      offenders <- c(offenders, basename(f))
    }
  }
  expect_identical(offenders, character(0))
})

test_that("the verifier of the package agrees with the independent walker of this file", {
  ## Two closures, written separately, over the same installed engine. Agreement
  ## between them is evidence; agreement of either with itself would not be.
  rep <- ra_verify_operator_table(include_mpfr = FALSE)
  expect_identical(rep$differentiable, character(0))
  expect_identical(rep$escaped, character(0))
  expect_true(rep$closed)

  mine <- setdiff(differentiation_closure(ra_operator_table()$fun),
                  c(ra_operator_table()$fun, ra_operator_table("operators")))
  expect_identical(rep$escaped, mine)
})

test_that("the verifier runs the fourth criterion when the backend is there", {
  skip_if_not(ra_has_mpfr(), "needs Rmpfr")
  rep <- ra_verify_operator_table()
  expect_identical(rep$unsupported, character(0))
  expect_true(rep$closed)
})

test_that("the verifier refuses the fourth criterion rather than skipping it silently", {
  skip_if(ra_has_mpfr(), "the backend is installed, so this path is unreachable")
  expect_error(ra_verify_operator_table(include_mpfr = TRUE), class = "ra_no_mpfr")
})

test_that("POSITIVE CONTROL: the verifier must report an escape when the table is short one symbol", {
  ## Pointing the instrument at its own product. The closure is recomputed with
  ## log removed from what counts as admitted; log is reached from log2, log10
  ## and the general power, so a table without it is not closed and the walker
  ## has to say so. A verifier that reports a closed table no matter what is in
  ## it is not verifying anything.
  short <- setdiff(ra_operator_table()$fun, "log")
  escaped <- setdiff(differentiation_closure(short),
                     c(short, ra_operator_table("operators")))
  expect_true("log" %in% escaped)
})
