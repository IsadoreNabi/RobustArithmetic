#include <math.h>
#include <string.h>

#include <R.h>
#include <Rinternals.h>

extern double ra_cr_exp(double x);
extern double ra_cr_log(double x);
extern double ra_cr_sin(double x);
extern double ra_cr_cos(double x);
extern double ra_cr_tan(double x);
extern double ra_cr_sinh(double x);
extern double ra_cr_cosh(double x);
extern double ra_cr_tanh(double x);
extern double ra_cr_expm1(double x);
extern double ra_cr_log1p(double x);
extern double ra_cr_log2(double x);
extern double ra_cr_log10(double x);
extern double ra_cr_asin(double x);
extern double ra_cr_acos(double x);
extern double ra_cr_atan(double x);

typedef double (*ra_math_function)(double);

typedef struct {
  const char *name;
  ra_math_function function;
} ra_math_entry;

static double ra_cr_sqrt(double x)
{
  return sqrt(x);
}

static const ra_math_entry ra_math_functions[] = {
  {"exp", ra_cr_exp},
  {"log", ra_cr_log},
  {"sin", ra_cr_sin},
  {"cos", ra_cr_cos},
  {"tan", ra_cr_tan},
  {"sinh", ra_cr_sinh},
  {"cosh", ra_cr_cosh},
  {"tanh", ra_cr_tanh},
  {"sqrt", ra_cr_sqrt},
  {"expm1", ra_cr_expm1},
  {"log1p", ra_cr_log1p},
  {"log2", ra_cr_log2},
  {"log10", ra_cr_log10},
  {"asin", ra_cr_asin},
  {"acos", ra_cr_acos},
  {"atan", ra_cr_atan}
};

static ra_math_function ra_find_math_function(SEXP fun)
{
  R_xlen_t i;
  const char *name;
  const R_xlen_t count = (R_xlen_t) (sizeof(ra_math_functions) /
                                      sizeof(ra_math_functions[0]));

  if (TYPEOF(fun) != STRSXP || XLENGTH(fun) != 1 ||
      STRING_ELT(fun, 0) == NA_STRING) {
    Rf_error("`fun` must be one non-missing function name.");
  }
  name = CHAR(STRING_ELT(fun, 0));
  for (i = 0; i < count; ++i) {
    if (strcmp(name, ra_math_functions[i].name) == 0) {
      return ra_math_functions[i].function;
    }
  }
  Rf_error("Unknown correctly rounded function: '%s'.", name);
  return NULL;
}

SEXP ra_core_math(SEXP fun, SEXP x)
{
  R_xlen_t i;
  R_xlen_t length;
  int protected_count = 0;
  SEXP input;
  SEXP output;
  ra_math_function function = ra_find_math_function(fun);

  if (TYPEOF(x) != REALSXP && TYPEOF(x) != INTSXP) {
    Rf_error("`x` must be a numeric vector.");
  }

  input = x;
  if (TYPEOF(x) == INTSXP) {
    input = PROTECT(Rf_coerceVector(x, REALSXP));
    ++protected_count;
  }
  length = XLENGTH(input);
  output = PROTECT(Rf_allocVector(REALSXP, length));
  ++protected_count;

  for (i = 0; i < length; ++i) {
    const double value = REAL(input)[i];
    if (ISNA(value)) {
      REAL(output)[i] = NA_REAL;
    } else if (ISNAN(value)) {
      REAL(output)[i] = R_NaN;
    } else {
      REAL(output)[i] = function(value);
    }
  }

  UNPROTECT(protected_count);
  return output;
}
