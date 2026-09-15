# RobustArithmetic 0.2.0

Version 0.1.1 was never published; its changes are included here and this
release is described against 0.1.0.

## Correctly rounded kernels included in the package

- The fast level evaluates `exp`, `log`, `sin`, `cos`, `tan`, `sinh`, `cosh`,
  `tanh`, `expm1`, `log1p`, `log2`, `log10`, `asin`, `acos` and `atan` with
  fifteen CORE-MATH binary64 kernels compiled into the package (MIT license,
  pinned commit 1ab68b70b90f807fd2bc9cf20ec295d49ae09592), and `sqrt` with the
  hardware square root. Correct rounding of these functions no longer depends
  on the math library of the platform. The package now contains compiled code; origin, copyright holders,
  local changes and license texts are listed in `inst/COPYRIGHTS`.
- The two operations on which correct rounding of those kernels depends, `fma`
  and `roundeven`, come from `src/ra_portable_math.h`: the FMA instruction
  where the compiler guarantees it, otherwise the `fma` of musl (MIT) with an
  exact final scaling, and a bitwise `roundeven` everywhere.
- Every fast-level enclosure is widened by a slack of two outward steps for all
  sixteen functions, from the pre-registered formula `ceiling(2e + 1)` with the
  half-unit error bound `e = 0.5` of correct rounding. Fast-level provenance
  remains `measured`.
- `ra_measure_library_error()` measures the included route against MPFR.

## Safeguards

- At load, 128 sentinels (eight hard cases per function, with values computed
  independently with MPFR) are compared bit for bit with the included route.
- New exported function `ra_fast_level_status()` reports whether the fast
  level is degraded, the reason, the sentinel check and the first-use audit.
- When the fast level is degraded, the first affected result emits a single
  warning of class `ra_fast_level_unsafe` and is recomputed at the rigorous
  level with `theorem` provenance; without Rmpfr, each affected evaluation
  signals an error of that class. The behaviour is the same with `library()`
  and with `RobustArithmetic::`.
- A healthy session prints no startup message.
- `ra_environment_anchor()` and the environment anchor are removed.

## Printing and solving

- `format()` of an interval certifies that the printed decimal bounds contain
  the binary64 endpoints without relying on `as.numeric()`, also where R has no
  extended-precision long double, and stops with an error instead of printing
  a looser bound. In the measured benchmark of 1,000 random intervals, median
  formatting time increased by 54%.
- `ra_solve()` derives verdict provenance from the evaluations supporting each
  certificate. Printed cards use the label `verdict provenance`, and summaries
  use `Theorem provenance for every verdict`.

## Tests and build

- Tests of the fast-level machinery hold the level open for their own block,
  so that they assert the code and not the math library of the machine; the
  degradation rules are tested separately.
- The check that Rmpfr refuses `trigamma()` runs in a child R process.
- `VignetteBuilder` declares `knitr, rmarkdown`.
