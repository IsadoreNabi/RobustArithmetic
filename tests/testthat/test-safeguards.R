## The safeguards of the fast level.
##
## The threat they answer: an insufficient slack would produce an invalid
## enclosure indistinguishable from a valid one at run time. Nothing printed
## would show it. The safeguards turn that invisible failure mode into a trip
## wire tested on this machine, on the route in use, at every load; and every
## test here follows the rule that a watchman that cannot fail for the thing
## it watches is not a watchman.

test_that("the sentinel table is present, complete and self-consistent", {
  s <- ra_sentinels()
  expect_true(all(ra_operator_table("functions")$fun %in% s$fun))
  expect_true(all(is.finite(s$x)))
  ## the true value is irrational at every sentinel, so the bracketing pair
  ## is a pair of adjacent doubles and the correctly rounded value is one of
  ## the two
  expect_true(all(s$dn < s$up))
  expect_true(all(s$up <= ra_succ(s$dn)))
  expect_true(all(s$cr == s$dn | s$cr == s$up))
  ## the route-discrepancy sentinel of sin is the point session 80 isolated
  ## and verified outside R (a C program, MPFR, and a Taylor series)
  i <- s$fun == "sin" & s$role == "route_discrepancy"
  expect_identical(s$x[i], 2.5698953698477605e-08)
  ## at that point the ordinary route returns a double different from the
  ## correctly rounded one in the anchored environment. If it stops being true
  ## there, the sentinels must be regenerated rather than inherited. The table
  ## invariants above remain unconditional on every machine.
  if (!length(ra_environment_anchor()$mismatch)) {
    expect_false(identical(sin(s$x[i]), s$cr[i]))
  }
})

test_that("S1: the sentinels pass on the healthy route", {
  chk <- ra_check_sentinels()
  expect_true(all(!is.na(chk$steps_needed)))
  expect_true(all(chk$ok))
  expect_true(all(chk$steps_needed <= chk$slack))
  ## and the check is not vacuous: at least one sentinel needs at least one
  ## outward step, otherwise the route would be correctly rounded everywhere
  ## and the measured discrepancy of session 80 would have vanished
  expect_true(any(chk$steps_needed >= 1L))
})

test_that("S5: a slack of zero must trip the check", {
  chk <- ra_check_sentinels(slack = 0L)
  expect_true(any(!chk$ok))
})

test_that("S5: a degraded fast level speaks, never silence", {
  old <- .ra_state$fast_degraded
  on.exit(assign("fast_degraded", old, envir = .ra_state), add = TRUE)
  assign("fast_degraded", TRUE, envir = .ra_state)
  if (ra_has_mpfr()) {
    ## with the backend present the call escalates to the rigorous level and
    ## says so; the enclosure it returns is the rigorous one
    expect_warning(got <- ra_elem("exp", ra_interval(0, 1)),
                   class = "ra_fast_level_unsafe")
    expect_s3_class(got, "ra_ivl")
    expect_identical(ra_prov(got), "theorem")
  } else {
    expect_error(ra_elem("exp", ra_interval(0, 1)),
                 class = "ra_fast_level_unsafe")
  }
  ## the rigorous level is not touched by the degradation
  if (ra_has_mpfr()) {
    expect_silent(ra_elem("exp", ra_interval(0, 1), level = "rigorous"))
  }
})

test_that("S2: with the backend present, the first fast use audits the route", {
  skip_if_not(ra_has_mpfr(), "the audit needs Rmpfr")
  ## the degradation flag is saved and cleared along with the audit flags:
  ## the gate only audits while the fast level is not already degraded, so a
  ## session that degraded earlier -- which is what happens wherever the
  ## sentinels do not describe the machine -- would never reach the code this
  ## test is about. The measurement itself is not forced to any outcome: what
  ## is restored afterwards is exactly what was found.
  old_audited <- .ra_state$fast_audited
  old_audit <- .ra_state$fast_audit
  old_degraded <- .ra_state$fast_degraded
  on.exit({
    assign("fast_audited", old_audited, envir = .ra_state)
    assign("fast_audit", old_audit, envir = .ra_state)
    assign("fast_degraded", old_degraded, envir = .ra_state)
  }, add = TRUE)
  assign("fast_audited", FALSE, envir = .ra_state)
  assign("fast_audit", NULL, envir = .ra_state)
  assign("fast_degraded", FALSE, envir = .ra_state)
  suppressWarnings(invisible(ra_elem("exp", ra_interval(0, 1))))
  expect_true(.ra_state$fast_audited)
  m <- .ra_state$fast_audit
  expect_true(is.data.frame(m) && nrow(m) == 16L)
  ## cached: a second use must not re-measure (the object is the same one)
  suppressWarnings(invisible(ra_elem("log", ra_interval(1, 2))))
  expect_identical(.ra_state$fast_audit, m)
})

test_that("S4: the environment anchor is named and the comparison can fail", {
  a <- ra_environment_anchor()
  expect_true(all(c("libm", "r_version", "jit_level", "platform") %in%
                    names(a$anchor)))
  ## WHETHER the current environment matches is a fact about the machine and
  ## not about this package, so it is not asserted: the sentinels were
  ## generated somewhere, and everywhere else the honest answer is a mismatch.
  ## What IS asserted is that a mismatch, when there is one, names the field
  ## it is about -- the anchor has to explain and not merely flag.
  expect_type(a$mismatch, "character")
  for (one in a$mismatch) {
    expect_true(any(vapply(names(a$anchor),
                           function(k) grepl(k, one, fixed = TRUE),
                           logical(1L))))
  }
  ## and the comparator can fail for what it watches: a doctored anchor must
  ## be reported, and the report must NAME what differs
  fake <- .ra_anchor
  fake$r_version <- "0.0"
  mm <- .ra_compare_anchor(fake)
  expect_true(length(mm) >= 1L)
  expect_match(paste(mm, collapse = " "), "0.0", fixed = TRUE)
})

test_that("S4: an unidentifiable C library is a mismatch", {
  compare <- .ra_compare_anchor
  mocked <- new.env(parent = environment(compare))
  mocked$system2 <- function(...) stop("getconf is unavailable")
  environment(compare) <- mocked
  mm <- compare(.ra_anchor)
  expect_true(any(grepl("libm", mm, fixed = TRUE)))
})

test_that("S3: provenance is carried, propagated by weakness, and printed", {
  ## the fast level is held open for the length of this test. What is under
  ## test here is the BOOKKEEPING -- that "measured" is attached, propagated by
  ## weakness, carried through subsetting and printed -- and that is a property
  ## of this package, not of the accuracy of the machine's library. Where the
  ## library does not honour the declared slack the gate escalates to the
  ## rigorous level, every enclosure comes back a theorem, and there would be
  ## no measured provenance left to propagate: the test would be measuring the
  ## machine instead of the code. The degradation itself is tested in S5.
  restore_fast_level <- hold_fast_level_open()
  on.exit(restore_fast_level(), add = TRUE)
  a <- ra_interval(1, 2)
  expect_identical(ra_prov(a), "theorem")
  f <- ra_elem("exp", a)
  expect_identical(ra_prov(f), "measured")
  ## kernel arithmetic preserves what it received and weakens on mixture
  expect_identical(ra_prov(a + a), "theorem")
  expect_identical(ra_prov(a + f), "measured")
  expect_identical(ra_prov(f * f), "measured")
  ## subsetting and concatenation carry it element by element
  both <- c(a, f)
  expect_identical(ra_prov(both), c("theorem", "measured"))
  expect_identical(ra_prov(both[2L]), "measured")
  ## the printed form says it, so a reader cannot mistake a convention for a
  ## theorem; the theorem-only print stays clean
  expect_match(paste(capture.output(print(f)), collapse = "\n"), "measured")
  expect_no_match(paste(capture.output(print(a)), collapse = "\n"), "measured")
  ## summary counts it
  expect_match(paste(capture.output(print(summary(both))), collapse = "\n"),
               "measured")
  ## and the data frame form exposes the column
  expect_true("prov" %in% names(as.data.frame(both)))
  if (ra_has_mpfr()) {
    r <- ra_elem("exp", a, level = "rigorous")
    expect_identical(ra_prov(r), "theorem")
  }
})

test_that("S3: the weakest provenance also flows through expressions", {
  ## held open for the same reason as the test above
  restore_fast_level <- hold_fast_level_open()
  on.exit(restore_fast_level(), add = TRUE)
  got <- ra_enclose_expr(quote(exp(x) + 1), ra_interval(0, 1))
  expect_identical(ra_prov(got), "measured")
  if (ra_has_mpfr()) {
    rig <- ra_enclose_expr(quote(exp(x) + 1), ra_interval(0, 1),
                           level = "rigorous")
    expect_identical(ra_prov(rig), "theorem")
  }
})
