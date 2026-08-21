## Asserting an enclosure, which is two claims and not one.
##
## Containment is the claim that matters: the exact endpoints must be inside
## what the operation returned. Tightness is the second claim: the operation
## must not have widened by more than the outward steps its design allows. A
## test that asserted equality with the exact endpoints would be testing that
## the outward rounding had been forgotten.
expect_encloses <- function(x, lo, hi, steps = 1L) {
  expect_true(all(ra_inf(x) <= lo),
              label = paste0("lower endpoint encloses (", format(ra_inf(x)),
                             " <= ", format(lo), ")"))
  expect_true(all(ra_sup(x) >= hi),
              label = paste0("upper endpoint encloses (", format(ra_sup(x)),
                             " >= ", format(hi), ")"))
  ## An infinite exact endpoint is attained exactly and admits no step beyond
  ## it, so tightness there is the equality and not a widened bound.
  tl <- lo
  th <- hi
  fin_lo <- is.finite(lo)
  fin_hi <- is.finite(hi)
  for (k in seq_len(steps)) {
    tl[fin_lo] <- ra_next_down_bits(tl[fin_lo])
    th[fin_hi] <- ra_next_up_bits(th[fin_hi])
  }
  expect_true(all(ra_inf(x) >= tl),
              label = paste0("lower endpoint is tight to ", steps, " step(s)"))
  expect_true(all(ra_sup(x) <= th),
              label = paste0("upper endpoint is tight to ", steps, " step(s)"))
}
