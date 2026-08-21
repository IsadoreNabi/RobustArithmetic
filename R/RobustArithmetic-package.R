#' @title RobustArithmetic: verified interval arithmetic in pure R
#' @description Interval arithmetic whose results are enclosures rather than
#'   estimates: every operation returns a pair of endpoints that provably
#'   contains the exact result, so that a conclusion drawn from them holds for
#'   the whole interval at once and not for a sample of it.
#' @details The package is organised in levels.
#'
#'   The outward-rounding layer moves a computed double strictly down or
#'   strictly up using the predecessor and successor formulas of Rump,
#'   Zimmermann, Boldo and Melquiond, which are valid in round-to-nearest. The
#'   floating-point rounding mode is never changed, and the reason is not only
#'   that R does not expose the control. The rounding mode is per-thread state
#'   of the processor, not a setting of the caller: a directed mode set from R
#'   would govern every floating-point operation executed afterwards on that
#'   thread until something set it back, whatever code performed it and
#'   whatever it was computing. That is a wide blast radius for a local
#'   convenience, and the formulas make it unnecessary.
#'
#'   The kernel implements the arithmetic on endpoints, in the inf-sup
#'   representation of the set-based flavor of the interval standard, with the
#'   decoration subset the package declares.
#'
#'   The elementary functions come at two levels. The fast level evaluates in
#'   the system math library and widens the result by a slack declared from
#'   published accuracy measurements of that library on this platform. The
#'   rigorous level evaluates in multiprecision, where every function is
#'   correctly rounded by contract, and returns through a directed bridge; it is
#'   reached by an escalation ladder when a verdict would otherwise fall inside
#'   the slack of the fast level.
#'
#'   Above the kernel sit the natural and centered extensions of an expression,
#'   a monotonicity test, the Hansen-Sengupta interval Newton operator with
#'   extended division and epsilon-inflated candidate verification, and a
#'   subdivision engine. Their only failure mode is a named abstention that
#'   prints the budget it exhausted.
#' @section What the interval standard asks, and what this package answers:
#'   Conformance with IEEE Std 1788.1-2017 is \strong{not} claimed, and the
#'   reason is the standard's own. Its subclause 1.5 defines conformance as a
#'   list of requirements an implementation \emph{shall} satisfy -- the
#'   decorations of 5.2, the required operations of 6.7 at the accuracies of
#'   6.5, the text input and output of 6.8.2 and 6.8.3, and the interchange
#'   representation of 7.3. There is no partial grade in that subclause to
#'   claim, so a package that meets some of the list and not the rest says so
#'   item by item instead of grading itself.
#'
#'   Measured against clause 6, requirement by requirement:
#'
#'   \itemize{
#'     \item \strong{6.7.1, interval constants} -- provided ([ra_empty()],
#'       [ra_entire()]).
#'     \item \strong{6.7.2, an interval version of each arithmetic operation of
#'       Table 4.1} -- \strong{22 of the 39}. Absent: \code{recip}, \code{fma},
#'       \code{pow}, \code{exp2}, \code{exp10}, \code{atan2}, \code{asinh},
#'       \code{acosh}, \code{atanh}, \code{sign}, \code{ceil}, \code{floor},
#'       \code{trunc}, \code{roundTiesToEven}, \code{roundTiesToAway},
#'       \code{min}, \code{max}. The table of admissible symbols was closed by
#'       the criteria of [ra_operator_table()], which are the criteria of an
#'       expression engine and not the standard's list; the two sets differ and
#'       the difference is this one.
#'     \item \strong{6.7.3, cancellative addition and subtraction} -- absent.
#'     \item \strong{6.7.4, intersection and convex hull} -- provided
#'       ([ra_intersect()], [ra_hull()]).
#'     \item \strong{6.7.5, constructors} -- \code{numsToInterval} provided
#'       ([ra_interval()]), with the declared divergence documented there;
#'       \code{textToInterval} absent, and with it the interval literals of
#'       6.6.
#'     \item \strong{6.7.6, the numeric functions of Table 4.3} -- all seven
#'       ([ra_inf()], [ra_sup()], [ra_mid()], [ra_rad()], [ra_wid()],
#'       [ra_mag()], [ra_mig()]).
#'     \item \strong{6.7.7, boolean functions} -- \code{isEmpty},
#'       \code{isEntire} and \code{isNaI} provided; the comparison relations of
#'       Table 4.5 absent.
#'     \item \strong{6.7.8, operations on decorations} --
#'       \code{decorationPart} ([ra_dec()]) and \code{setDec} ([ra_set_dec()])
#'       provided; \code{newDec} applied by the constructor but not exposed;
#'       \code{intervalPart} and the ordering comparisons on decorations
#'       absent.
#'     \item \strong{6.5.2, accuracy} -- the subclause requires the basic
#'       operations to be \emph{tightest}, that is, to return the hull of the
#'       exact result. They are not: outward rounding widens by one unit in the
#'       last place at each end, which is what makes the enclosure provable
#'       without a rounding mode. What holds is the weakest mode, \emph{valid},
#'       and it holds by theorem rather than by measurement.
#'     \item \strong{6.8.3, output} -- provided ([ra_interval_to_text()]), and
#'       [format.ra_ivl()] encloses in the same way, differing only in spelling
#'       the infinities as R does and in carrying the provenance marker. The
#'       criterion met is the one 6.6.2 fixes: the value of the literal
#'       \code{[l, u]} is the mathematical interval \code{[l, u]}, the decimals
#'       read exactly, and not the weaker "the string reads back to the same
#'       double". Tightness is left implementation-defined by the subclause and
#'       is declared here: the value of the string is contained in
#'       \code{[ra_pred(lo), ra_succ(hi)]}. The uncertain form of 6.6.2 is not
#'       emitted, and no conversion specifier selects it.
#'     \item \strong{6.8.2, input} -- absent, and with it \code{textToInterval}
#'       and the interval literals of 6.6 as an input syntax. Text produced by
#'       this package is a valid literal; text is not read back.
#'     \item \strong{7.3, interchange representation} -- absent.
#'   }
#'
#'   The decoration system itself follows 5.2 to 5.7 as written, down to the
#'   two rules a reader is most likely to expect otherwise: a domain error
#'   decorates \code{trv} and not \code{ill}, which is reserved for the
#'   ill-formed interval of 5.3, and an unbounded interval cannot carry
#'   \code{com}.
#'
#' @section Methodological notes:
#'   Failure is never silent and never uninformative in an unstated direction.
#'   An operation that cannot prove what was asked returns an object saying so;
#'   an input that could not have had a meaning raises a typed condition. There
#'   is no third case in which a number is returned that looks like an answer.
#' @section Dependencies:
#'   Imports \code{stats}, for the derivative engine used to close the table of
#'   admissible symbols and to build centered forms. Suggests 'Rmpfr' for the
#'   rigorous level; the package installs, checks and runs without it.
#' @references
#'   Institute of Electrical and Electronics Engineers. (2015). IEEE standard for
#'   interval arithmetic (IEEE Std 1788-2015).
#'   https://doi.org/10.1109/IEEESTD.2015.7140721
#'
#'   Rump, S. M., Zimmermann, P., Boldo, S., & Melquiond, G. (2009). Computing
#'   predecessor and successor in rounding to nearest. BIT Numerical Mathematics,
#'   49(2), 419-431. https://doi.org/10.1007/s10543-009-0218-z
#'
#'   Rump, S. M. (2010). Verification methods: Rigorous results using floating-point
#'   arithmetic. Acta Numerica, 19, 287-449.
#'   https://doi.org/10.1017/S096249291000005X
#'
#'   Neumaier, A. (1990). Interval methods for systems of equations. Cambridge
#'   University Press. https://doi.org/10.1017/CBO9780511526473
#'
#'   Hansen, E., & Walster, G. W. (2004). Global optimization using interval
#'   analysis (2nd ed.). Marcel Dekker.
#'
#'   Moore, R. E., Kearfott, R. B., & Cloud, M. J. (2009). Introduction to interval
#'   analysis. Society for Industrial and Applied Mathematics.
#'   https://doi.org/10.1137/1.9780898717716
#'
#'   Tucker, W. (2011). Validated numerics: A short introduction to rigorous
#'   computations. Princeton University Press.
#' @seealso [ra_succ()] for the outward-rounding layer, [ra_operator_table()]
#'   for what an expression may contain, and [ra_has_mpfr()] for the rigorous
#'   level.
#' @keywords internal
"_PACKAGE"
