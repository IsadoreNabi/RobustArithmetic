/*
 * ra_portable_math.h: fma and roundeven for the bundled CORE-MATH kernels,
 * independent of the math library of the platform.
 *
 * The fifteen kernels in src/coremath_*.c round correctly only if fma(x, y, z)
 * returns x*y + z correctly rounded and roundeven rounds to the nearest integer
 * with ties to even. When the compiler cannot use an instruction for them,
 * __builtin_fma and __builtin_roundeven become calls to the math library of the
 * platform, and that library is not always exact: the mingw-w64 library linked
 * by Rtools45 has no roundeven, and its fma differs from the correctly rounded
 * result on between 9 and 34 percent of the measured triples, depending on the
 * class of input. dev/core-math/import.sh therefore makes this header the first
 * line of every kernel, replaces __builtin_fma by ra_fma, and defines
 * roundeven_finite as ra_roundeven_finite. Nothing in this header calls a
 * function of the math library; <math.h> is included for the type double_t
 * used by the musl code below.
 */

#ifndef RA_PORTABLE_MATH_H
#define RA_PORTABLE_MATH_H

#include <stdint.h>
#include <string.h>
#include <float.h>
#include <math.h>

/*
 * Rounds a finite double to the nearest integer, ties to even, on its IEEE 754
 * binary64 bit pattern. A magnitude of at least 2^52 is already an integer; a
 * magnitude below 1/2 rounds to the zero of the same sign; a magnitude in
 * [1/2, 1) rounds to that zero only when it is exactly 1/2, and to one of the
 * same sign otherwise; in the remaining range the fractional bits are cleared
 * and the integer part is incremented when they exceed one half, or equal one
 * half with an odd integer part. The kernels call it only on finite arguments.
 */
static inline double ra_roundeven_finite(double x)
{
  uint64_t u, one, half, frac;
  int e, s;
  memcpy(&u, &x, sizeof u);
  e = (int) ((u >> 52) & 0x7ff);
  if (e >= 0x3ff + 52) return x;
  if (e < 0x3ff - 1) { u &= 0x8000000000000000ull; memcpy(&x, &u, sizeof u); return x; }
  if (e == 0x3ff - 1) { u = (u & 0x8000000000000000ull) | ((u & 0x000fffffffffffffull) ? 0x3ff0000000000000ull : 0); memcpy(&x, &u, sizeof u); return x; }
  s = 0x3ff + 52 - e;
  one = 1ull << s; half = one >> 1; frac = u & (one - 1);
  u &= ~(one - 1);
  if (frac > half || (frac == half && (u & one))) u += one;
  memcpy(&x, &u, sizeof u);
  return x;
}

/*
 * Where the compiler guarantees the FMA instruction (x86 with __FMA__ defined,
 * and AArch64, whose base instruction set includes fused multiply-add), ra_fma
 * is that instruction. Everywhere else it is the fma of musl pinned below, which
 * forms the exact result with 64-bit integer arithmetic and rounds it once.
 */
#if defined(__FMA__) || defined(__aarch64__) || defined(_M_ARM64)
# define ra_fma(x, y, z) __builtin_fma ((x), (y), (z))
#else
/*
 * ra_fma_pow2(e) is 2^e, built from its bit pattern, for -1074 <= e <= 1023.
 *
 * ra_fma_scale(r, e) is r * 2^e with a single rounding, for the values the musl
 * code passes: r is a nonzero binary integer that already holds at most 53
 * significant bits and a sticky bit. For -1022 <= e <= 1023 the power is exact
 * and the one product rounds, overflowing to infinity when the exact value
 * does. For e > 1023 the exact result is at least 2^62 * 2^1024 and overflows,
 * so the first product already gives the infinity of the right sign. For
 * e < -1022 the first product by 2^-1022 is exact because |r| >= 1, and the
 * second product rounds; clamping its exponent at -1074 changes no result,
 * because below that bound the exact value lies far under half the least
 * subnormal and rounds to the same signed zero.
 */
static inline double ra_fma_pow2(int e)
{
  uint64_t u = e >= -1022 ? (uint64_t) (e + 1023) << 52 : 1ull << (e + 1074);
  double d;
  memcpy(&d, &u, sizeof d);
  return d;
}

static inline double ra_fma_scale(double r, int e)
{
  if (e > 1023) { r *= 0x1p1023; e -= 1023; if (e > 1023) e = 1023; }
  else if (e < -1022) { r *= 0x1p-1022; e += 1022; if (e < -1074) e = -1074; }
  return r * ra_fma_pow2(e);
}

/*
 * The lines between BEGIN and END are src/math/fma.c of musl at the commit
 * named on the BEGIN line (MIT license, reproduced in inst/COPYRIGHTS; the
 * pinned file is dev/musl/fma.c), with these local changes and no other: its
 * four include lines are removed; its local names take the prefix ra_fma_ or
 * RA_FMA_; its helpers and its entry point are static inline, and the entry
 * point is named ra_fma; its floating-point environment pragma is removed, as
 * in the bundled CORE-MATH files; its count-leading-zeros helper is
 * __builtin_clzll; its final scaling calls ra_fma_scale; and six shift counts
 * are parenthesized, which keeps the evaluation order.
 */
/* BEGIN musl src/math/fma.c 9683bd62414604d3bd56cf6bd7be8f54aa31e7d3 */
#define RA_FMA_ASUINT64(x) ((union {double f; uint64_t i;}){x}).i
#define RA_FMA_ZEROINFNAN (0x7ff-0x3ff-52-1)

struct ra_fma_num { uint64_t m; int e; int sign; };

static inline struct ra_fma_num ra_fma_normalize(double x)
{
	uint64_t ix = RA_FMA_ASUINT64(x);
	int e = ix>>52;
	int sign = e & 0x800;
	e &= 0x7ff;
	if (!e) {
		ix = RA_FMA_ASUINT64(x*0x1p63);
		e = ix>>52 & 0x7ff;
		e = e ? e-63 : 0x800;
	}
	ix &= (1ull<<52)-1;
	ix |= 1ull<<52;
	ix <<= 1;
	e -= 0x3ff + 52 + 1;
	return (struct ra_fma_num){ix,e,sign};
}

static inline void ra_fma_mul(uint64_t *hi, uint64_t *lo, uint64_t x, uint64_t y)
{
	uint64_t t1,t2,t3;
	uint64_t xlo = (uint32_t)x, xhi = x>>32;
	uint64_t ylo = (uint32_t)y, yhi = y>>32;

	t1 = xlo*ylo;
	t2 = xlo*yhi + xhi*ylo;
	t3 = xhi*yhi;
	*lo = t1 + (t2<<32);
	*hi = t3 + (t2>>32) + (t1 > *lo);
}

static inline double ra_fma(double x, double y, double z)
{
	/* normalize so top 10bits and last bit are 0 */
	struct ra_fma_num nx, ny, nz;
	nx = ra_fma_normalize(x);
	ny = ra_fma_normalize(y);
	nz = ra_fma_normalize(z);

	if (nx.e >= RA_FMA_ZEROINFNAN || ny.e >= RA_FMA_ZEROINFNAN)
		return x*y + z;
	if (nz.e >= RA_FMA_ZEROINFNAN) {
		if (nz.e > RA_FMA_ZEROINFNAN) /* z==0 */
			return x*y;
		return z;
	}

	/* mul: r = x*y */
	uint64_t rhi, rlo, zhi, zlo;
	ra_fma_mul(&rhi, &rlo, nx.m, ny.m);
	/* either top 20 or 21 bits of rhi and last 2 bits of rlo are 0 */

	/* align exponents */
	int e = nx.e + ny.e;
	int d = nz.e - e;
	/* shift bits z<<=kz, r>>=kr, so kz+kr == d, set e = e+kr (== ez-kz) */
	if (d > 0) {
		if (d < 64) {
			zlo = nz.m<<d;
			zhi = nz.m>>(64-d);
		} else {
			zlo = 0;
			zhi = nz.m;
			e = nz.e - 64;
			d -= 64;
			if (d == 0) {
			} else if (d < 64) {
				rlo = rhi<<(64-d) | rlo>>d | !!(rlo<<(64-d));
				rhi = rhi>>d;
			} else {
				rlo = 1;
				rhi = 0;
			}
		}
	} else {
		zhi = 0;
		d = -d;
		if (d == 0) {
			zlo = nz.m;
		} else if (d < 64) {
			zlo = nz.m>>d | !!(nz.m<<(64-d));
		} else {
			zlo = 1;
		}
	}

	/* add */
	int sign = nx.sign^ny.sign;
	int samesign = !(sign^nz.sign);
	int nonzero = 1;
	if (samesign) {
		/* r += z */
		rlo += zlo;
		rhi += zhi + (rlo < zlo);
	} else {
		/* r -= z */
		uint64_t t = rlo;
		rlo -= zlo;
		rhi = rhi - zhi - (t < rlo);
		if (rhi>>63) {
			rlo = -rlo;
			rhi = -rhi-!!rlo;
			sign = !sign;
		}
		nonzero = !!rhi;
	}

	/* set rhi to top 63bit of the result (last bit is sticky) */
	if (nonzero) {
		e += 64;
		d = __builtin_clzll(rhi)-1;
		/* note: d > 0 */
		rhi = rhi<<d | rlo>>(64-d) | !!(rlo<<d);
	} else if (rlo) {
		d = __builtin_clzll(rlo)-1;
		if (d < 0)
			rhi = rlo>>1 | (rlo&1);
		else
			rhi = rlo<<d;
	} else {
		/* exact +-0 */
		return x*y + z;
	}
	e -= d;

	/* convert to double */
	int64_t i = rhi; /* i is in [1<<62,(1<<63)-1] */
	if (sign)
		i = -i;
	double r = i; /* |r| is in [0x1p62,0x1p63] */

	if (e < -1022-62) {
		/* result is subnormal before rounding */
		if (e == -1022-63) {
			double c = 0x1p63;
			if (sign)
				c = -c;
			if (r == c) {
				/* min normal after rounding, underflow depends
				   on arch behaviour which can be imitated by
				   a double to float conversion */
				float fltmin = 0x0.ffffff8p-63*FLT_MIN * r;
				return DBL_MIN/FLT_MIN * fltmin;
			}
			/* one bit is lost when scaled, add another top bit to
			   only round once at conversion if it is inexact */
			if (rhi << 53) {
				i = rhi>>1 | (rhi&1) | 1ull<<62;
				if (sign)
					i = -i;
				r = i;
				r = 2*r - c; /* remove top bit */

				/* raise underflow portably, such that it
				   cannot be optimized away */
				{
					double_t tiny = DBL_MIN/FLT_MIN * r;
					r += (double)(tiny*tiny) * (r-r);
				}
			}
		} else {
			/* only round once when scaled */
			d = 10;
			i = ( rhi>>d | !!(rhi<<(64-d)) ) << d;
			if (sign)
				i = -i;
			r = i;
		}
	}
	return ra_fma_scale(r, e);
}
/* END musl src/math/fma.c */
#endif

#endif /* RA_PORTABLE_MATH_H */
