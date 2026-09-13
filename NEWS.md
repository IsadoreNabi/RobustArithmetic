# RobustArithmetic 0.1.1

- Decimal endpoint formatting now certifies containment without relying on
  `as.numeric()` to recover which side of an exact decimal a binary64 value
  falls on, including platforms where R is built without extended-precision
  long doubles. The formatter determines the side from the exact decimal
  significand and an error bound derived from scaling, and declines when that
  bound cannot certify the result. If `format()` cannot prove both containment
  and one-step width for a printed bound, it stops with an error rather than
  printing a looser bound. In the measured benchmark of 1,000 random intervals,
  median formatting time increased by 54%, from 1.171 to 1.805 seconds.

- Environment anchors now include `platform`, which is also returned by
  `ra_environment_anchor()`. An unidentified C math library or platform counts
  as an anchor mismatch. On systems where `getconf` cannot identify the C
  library, including macOS and Windows, a different-environment startup message
  is shown each time the package is attached with `library()` or `require()`.
  The tests that compare the active `sin()` route with the correctly rounded
  value now make that environment-dependent assertion only when the anchor
  supports the comparison.

- `ra_solve()` now derives verdict provenance from the evaluations supporting
  each certificate. Without Rmpfr, theorem-backed polynomial and rational
  verdicts remain `theorem`, while verdicts that depend on measured elementary
  function bounds remain `measured`. Printed cards now use the label
  `verdict provenance`. Summaries now use
  `Theorem provenance for every verdict` in place of `Rigorously verified`.
