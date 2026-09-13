# CRAN comments — RobustArithmetic 0.1.1

## Test environments

- local: Fedora Linux 44, R 4.6.1, x86_64-redhat-linux-gnu, with all
  suggested packages required
- local: Fedora Linux 44, R 4.6.1, x86_64-pc-linux-gnu, built with
  `--disable-long-double`, with Rmpfr available
- local: Fedora Linux 44, R 4.6.1, x86_64-pc-linux-gnu, built with
  `--disable-long-double`, without Rmpfr, with unavailable suggested packages
  allowed

All three configurations were checked from independently built 0.1.1 source
tarballs on 2026-09-13, first in a local environment without network access and
then in an environment with network access. Remote incoming checks were disabled
for both three-configuration matrices so that their results were comparable;
the network-enabled repetitions did not disable remote clock verification.

## R CMD check results

### Three-configuration matrices

0 errors | 0 warnings | 0 notes

All six checks returned `Status: OK`. In the network-enabled repetitions, the
system R check completed in 48 seconds, the build without extended-precision
long doubles with Rmpfr completed in 40 seconds, and the same build without
Rmpfr and without required suggested packages completed in 36 seconds.

In the no-network matrix, only the remote components of the incoming checks and
the remote comparison of the system clock were disabled. Package installation,
examples, tests, vignette rebuilding, and the PDF and HTML manual checks all ran
and completed successfully in both matrices.

### Remote incoming feasibility check

0 errors | 0 warnings | 1 note

An additional check under the system R build, with network access, required
suggested packages, and remote incoming checks enabled, completed in 59 seconds
with `Status: 1 NOTE`. Its only note was:

```text
* checking CRAN incoming feasibility ... [4s/15s] NOTE
Maintainer: 'Jose Mauricio Gomez Julian <isadore.nabi@pm.me>'

Days since last update: 1
```

Version 0.1.1 corrects the check failures that CRAN reported for version 0.1.0
on 2026-09-12. The one day since the last update therefore reflects the time
between that report and this corrective release.

## Response to the check failures reported on 2026-09-12

The reported checks exercised RobustArithmetic 0.1.0. Version 0.1.1 addresses
the two causes represented in those logs.

### Decimal endpoint containment

The failures in `r-oldrel-macos-arm64`, `M1mac`, and `noLD` showed that a
formatted lower endpoint could be read back by `as.numeric()` above the
binary64 value it was intended to bound. The same conversion was used by the
test and by the formatting implementation to infer which side of the exact
decimal the parsed value occupied. On platforms where R has no
extended-precision long double, intermediate rounding made that inference
invalid and could produce printed bounds that did not contain the represented
interval.

Endpoint formatting now combines the exact decimal significand with an error
bound derived from decimal scaling and accepts a side only when that bound
certifies it. If a candidate cannot be certified, the formatter continues up
to 18 significant digits; if it cannot prove both containment and one-step
width, `format()` signals an internal error instead of printing a looser bound.
The independent test reference, rather than the formatting engine, uses exact
integer arithmetic to reconstruct the binary64 value from its hexadecimal
representation before checking containment and one-step width. The 0.1.1
source tarball returned `Status: OK` under the system R build and under the
build without extended-precision long doubles, both with Rmpfr and without
Rmpfr.

### Environment-dependent `sin()` assertions

The failures in `r-oldrel-macos-arm64` and `r-oldrel-macos-x86_64` arose because
two tests required the active `sin()` route to differ from the correctly
rounded result. On those macOS configurations the route returned that result,
so the tests had turned an observation about the environment that generated
the sentinels into an unconditional package property.

Those test assertions now apply only when the environment anchor supports the
comparison. The anchor records `platform` in addition to the R version,
just-in-time compilation level, and C math library, and
`ra_environment_anchor()` returns the new field. An unidentified C math library
or platform is treated as a mismatch. Consequently, on systems where `getconf`
cannot identify the C library, including macOS and Windows, the package emits a
different-environment startup message whenever it is attached with `library()`
or `require()`, rather than when its namespace is merely loaded. The sentinel
values, their published slack, the fast level, and the degradation rule are
unchanged.

### Results by reported configuration

- `r-oldrel-macos-arm64`: the decimal containment repair addresses
  `test-decimal.R`; the environment-dependent assertion repair addresses
  `test-elementary.R` and `test-safeguards.R`.
- `r-oldrel-macos-x86_64`: the environment-dependent assertion repair
  addresses the failures in `test-elementary.R` and `test-safeguards.R`.
- `M1mac`: the decimal containment repair addresses the failure in
  `test-decimal.R`.
- `noLD`: the decimal containment repair addresses the failure in
  `test-decimal.R`; the repaired path was checked in a matching R build both
  with Rmpfr and without Rmpfr.

## Additional user-visible correction

`ra_solve()` now derives each verdict's provenance from the evaluation that
supports its certificate. Without Rmpfr, theorem-backed polynomial and
rational verdicts remain `theorem`, while verdicts that depend on measured
elementary-function bounds remain `measured`. Printed cards now use
`verdict provenance`, and summaries use `Theorem provenance for every verdict`
in place of `Rigorously verified`.
