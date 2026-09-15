#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>
#include <Rinternals.h>

extern SEXP ra_core_math(SEXP fun, SEXP x);

typedef union {
  DL_FUNC generic;
  SEXP (*call2)(SEXP, SEXP);
} ra_call_pointer;

static R_CallMethodDef ra_call_methods[] = {
  {"ra_core_math", NULL, 2},
  {NULL, NULL, 0}
};

void attribute_visible R_init_RobustArithmetic(DllInfo *dll)
{
  ra_call_pointer pointer;

  pointer.call2 = ra_core_math;
  ra_call_methods[0].fun = pointer.generic;
  R_registerRoutines(dll, NULL, ra_call_methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
