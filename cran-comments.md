# CRAN comments — RobustArithmetic 0.2.0

This is a resubmission. Version 0.1.1 did not pass the incoming pretest on
Windows; 0.2.0 repairs the cause at its root and also carries the corrections
of the check failures reported for 0.1.0.

## Test environments

- local: Fedora Linux 44, R 4.6.1, x86_64-redhat-linux-gnu, with all
  suggested packages required
- local: Fedora Linux 44, R 4.6.1, x86_64-pc-linux-gnu, built with
  `--disable-long-double`, with Rmpfr available
- local: Fedora Linux 44, R 4.6.1, x86_64-pc-linux-gnu, built with
  `--disable-long-double`, without Rmpfr, with unavailable suggested packages
  allowed
- real platforms through GitHub Actions: the rhub workflow (16 platforms) and
  a workflow of the package (11 platforms) that runs `R CMD check --as-cran` and
  then checks correct rounding of the sixteen elementary functions against
  Rmpfr on the same machine. The matrix ran on the commit of version 0.1.1 that
  precedes this release, whose package sources differ from 0.2.0 only in the
  `Version` field and `NEWS.md`. Platforms:

  windows-2022 (R release)
  windows-2022 (R devel)
  windows-latest (R release)
  macos-latest (R release)
  macos-15 (R release)
  macos-15 (R 4.5.2)
  macos-15-intel (R release)
  macos-15-intel (R 4.5.2)
  ubuntu-latest (R release)
  ubuntu-latest (R devel)
  ubuntu-24.04-arm (R release)
  windows (R-devel)
  macos (R-devel)
  macos-arm64 (R-devel)
  m1-san (R-devel)
  clang-asan
  clang-ubsan
  gcc-asan
  valgrind
  rchk
  nold
  nosuggests
  intel
  lto
  c23
  ubuntu-next
  ubuntu-release

## R CMD check results

### Local checks

0 errors | 0 warnings | 0 notes

All three local configurations returned `Status: OK`, with remote incoming
checks disabled so that their results are comparable.

### Remote incoming feasibility check

0 errors | 0 warnings | 1 note

The system R build, with network access, required suggested packages and
remote incoming checks enabled, returned `Status: 1 NOTE`. Its only note was
(the timing in brackets, which varies between runs, is omitted):

```text
* checking CRAN incoming feasibility ... NOTE
Maintainer: 'Jose Mauricio Gomez Julian <isadore.nabi@pm.me>'

Days since last update: 3
```

The last published version is 0.1.0. This release corrects the check failures
reported for it on 2026-09-12 and the cause of the Windows pretest failure of
the 0.1.1 submission on 2026-09-14; 0.1.1 was never published.

### Real platforms

On the 26 platforms that run `R CMD check`, no check reported an ERROR or a
WARNING, and the correct-rounding check against Rmpfr passed on every one of
them, including the three Windows runners and the rhub Windows, valgrind,
sanitizer, `nold` and `nosuggests` platforms. On `rchk` the analysis reported
no counted error. The rhub checks returned `Status: OK`; on the 11 runners of
the package workflow the only note named a file that the workflow itself wrote
into the source directory before building, which is not part of the package
and no longer happens.

## Response to the Windows pretest of version 0.1.1 (2026-09-14)

Debian passed with the feasibility note only. Windows Server 2022 with R-devel
ucrt ended the test suite with `[ FAIL 1 | WARN 186 | SKIP 26 | PASS 625 ]`; the
error was in `test-newton.R`.

The cause lies in the elementary functions R uses on Windows. In `R.dll` of
R 4.6.1 and of R-devel, `tan`, `sinh`, `cosh`, `tanh`, `log10`, `asin`, `acos`
and `atan` are imported from UCRT, while `exp`, `log`, `sin`, `cos`, `sqrt`,
`expm1`, `log1p` and `log2` are compiled into `R.dll` from the mingw-w64
library, which evaluates them with x87 extended-precision instructions. No
published error bound exists for that route. At the first fast-level use, the
package's audit measured `sin` and `cos` beyond the slack it had derived for
other libraries and degraded the fast level for the session, as designed; each
elementary operation then escalated to Rmpfr with a warning (the 186 warnings),
and one test that hid Rmpfr to check provenance labels met the degraded level,
which correctly refused to return an enclosure.

The package no longer depends on that route. Its fast level evaluates fifteen
elementary functions with correctly rounded CORE-MATH kernels compiled into
the package and `sqrt` with the hardware square root, so correct rounding does
not depend on the platform. The tests of the fast-level machinery no longer
inherit the state of the machine, and a harness in the development tree runs
the installed test suite in healthy and degraded states, with and without
Rmpfr and with R built without long doubles.

## Response to the check failures reported for 0.1.0 (2026-09-12)

- `r-oldrel-macos-arm64`, `M1mac` and `noLD`: a formatted lower endpoint could be
  read back by `as.numeric()` above the value it bounded, because the formatter
  inferred the side of the exact decimal through that conversion. `format()` now
  certifies containment from the exact decimal significand and an error bound
  and stops with an error rather than printing a looser bound.
- `r-oldrel-macos-arm64` and `r-oldrel-macos-x86_64`: two tests required the
  platform `sin()` to differ from the correctly rounded result, an observation
  about one machine turned into a package property. The fast level now uses the
  included correctly rounded kernels on every platform, the environment anchor
  and `ra_environment_anchor()` are removed, and the state of the fast level is
  reported by `ra_fast_level_status()`.

## Compiled code included in the package

The package now contains C code:

- fifteen binary64 kernels of CORE-MATH (<https://gitlab.inria.fr/core-math/core-math>,
  commit 1ab68b70b90f807fd2bc9cf20ec295d49ae09592, MIT license), with local changes
  limited to namespace isolation, portable warning-free compilation and taking
  `fma` and `roundeven` from a header of the package;
- that header, `src/ra_portable_math.h`, whose `fma` for compilers without the
  FMA instruction is derived from musl (commit
  9683bd62414604d3bd56cf6bd7be8f54aa31e7d3, MIT license), because the `fma` of
  the Rtools45 toolchain is not correctly rounded and its library has no
  `roundeven`.

Copyright holders, local changes and both license texts are in
`inst/COPYRIGHTS`, referred to by the `Copyright` field; the authors of the
included files are listed in `Authors@R` with role `cph`. The compiled code
calls no `printf`, `abort`, `exit` or random number generator, and every C file
compiles without warnings under GCC (C17 and C23) and Clang with
`-Wall -Wextra -pedantic`.
