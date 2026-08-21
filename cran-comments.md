# CRAN comments — RobustArithmetic 0.1.0

## Test environments

- local: Fedora 44, R 4.6.1, glibc 2.43
- CRAN pretest: Debian sid, R-devel (2026-08-19 r90430), gcc 16.2.0
- CRAN pretest: Windows Server 2022, R-devel (2026-08-17 r90424 ucrt)

## R CMD check results

0 errors | 0 warnings | 1 note

The note is `New submission`, together with the list of possibly misspelled
words in DESCRIPTION. All of them are intended:

- **Boldo**, **Melquiond**, **Zimmermann**, **Sengupta** are surnames of cited
  authors (Rump, Zimmermann, Boldo and Melquiond 2009, for the predecessor and
  successor formulas; Sengupta for the cited work on the standard).
- **cancellative** and **subclause** are the terms IEEE Std 1788.1-2017 uses
  for the operations of its subclause 6.7.3 and for its own sections. Using any
  other word would make the conformance statement harder to check against the
  standard, which is the point of stating it.
- **precisions** is the plural of the noun, used for the rungs of the precision
  ladder.

## Response to the pretest failures of 2026-08-21

The pretest reported `1 ERROR` on Debian and `1 ERROR` on Windows, in both
cases from the test suite. **Both had the same cause, and it was in the tests
and not in the package.**

This package ships measured sentinels — the observed error of the system math
library on sixteen elementary functions, and an anchor recording the
environment they were measured in. The safeguards exist precisely because
another machine may not honour them: on a machine whose library breaks the
declared slack, the fast level is degraded, every evaluation escalates to the
rigorous level with a warning, and the enclosure returned is a theorem rather
than a measurement. **That is what happened on the CRAN machines, and it is
the package working as designed** — the Windows library exceeded the declared
slack and the package said so, 197 times.

What was wrong is that several tests asserted the *machine* rather than the
*code*:

1. `test-safeguards.R` asserted that the environment anchor reports no
   mismatch — that is, that the machine running the tests is the machine the
   sentinels were generated on. It can only pass there. It now asserts what is
   actually a property of this package: that a mismatch, wherever there is one,
   names the field it is about.
2. Three tests of provenance propagation and one of the precision ladder
   presupposed that the fast level was in use. They are about bookkeeping and
   about the ladder, not about the accuracy of any library, so they now hold
   the fast level open for their own duration and restore the session state
   afterwards. The degradation itself is tested separately and unconditionally.
3. The test that measures the library error against the published bound now
   asserts the bound where it holds, and where it does not — which is a fact
   about the machine, not about the package — asserts the thing that must never
   fail: that the package *noticed*.

The repair was verified by reproducing both CRAN conditions locally, with the
anchor doctored to mismatch and with the measurement forced to break the
declared slack. Under both, and under neither, the suite passes.
