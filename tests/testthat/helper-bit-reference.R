## A bit-level reference for the immediate neighbours of a double.
##
## The rounding layer of this package is checked against this file and not
## against itself. The reference reads the bit pattern of a double, moves it by
## one, and reads it back; it shares no line of code with the formulas it
## judges, which is the only arrangement under which agreement between the two
## means anything.
##
## The reference is verified in closed form before it is used, on values whose
## neighbours are known from the definition of binary64 rather than from any
## computation: the successor of 1 is 1 + 2^-52 because the exponent of 1 is 0,
## the predecessor of 1 is 1 - 2^-53 because 1 is a power of two and the gap
## below a power of two is half the gap above it, and the successor of 0 is the
## smallest subnormal. An instrument that is not itself checked cannot certify
## anything.

## --- bit pattern of a double, as two 32-bit halves held in doubles ---
ra_d2u32 <- function(x) {
  rw <- writeBin(as.numeric(x), raw(), size = 8L, endian = "little")
  b <- matrix(as.integer(rawToBits(rw)), nrow = 64L)
  list(lo = colSums(b[1:32, , drop = FALSE] * 2^(0:31)),
       hi = colSums(b[33:64, , drop = FALSE] * 2^(0:31)))
}

ra_u32_2d <- function(lo, hi) {
  bits <- rbind(outer(0:31, lo, function(k, v) (v %/% 2^k) %% 2),
                outer(0:31, hi, function(k, v) (v %/% 2^k) %% 2))
  readBin(packBits(as.raw(as.vector(bits)), type = "raw"), "double",
          n = length(lo), size = 8L, endian = "little")
}

## --- nextUp and nextDown, vectorised ---
ra_next_up_bits <- function(x) {
  x <- as.numeric(x)
  u <- ra_d2u32(x)
  lo <- u$lo
  hi <- u$hi
  pos <- x > 0
  neg <- x < 0
  ## strictly positive: one step away from zero is one step up in the pattern
  if (any(pos)) {
    l <- lo[pos] + 1
    carry <- l == 2^32
    l[carry] <- 0
    lo[pos] <- l
    hi[pos] <- hi[pos] + carry
  }
  ## strictly negative: one step toward zero is one step down in the pattern
  if (any(neg)) {
    l <- lo[neg]
    borrow <- l == 0
    l[borrow] <- 2^32
    lo[neg] <- l - 1
    hi[neg] <- hi[neg] - borrow
  }
  out <- ra_u32_2d(lo, hi)
  out[x == 0] <- 2^-1074
  out
}

ra_next_down_bits <- function(x) -ra_next_up_bits(-as.numeric(x))

## --- the test set of the probe, rebuilt exactly ---
ra_bit_test_set <- function(seed = 78L, per_band = 10000L) {
  set.seed(seed)
  exps_pow2 <- unique(c(-1074, -1073, -1022, -1021, -969, -500, -100, -10, -1,
                        0, 1, 10, 100, 500, 1020, 1023))
  pow2 <- 2^exps_pow2
  neigh <- c(ra_next_up_bits(pow2), ra_next_down_bits(pow2))
  bands <- c(-500, -100, -10, -1, 0, 1, 10, 100, 500)
  rand <- unlist(lapply(bands, function(k) (1 + runif(per_band)) * 2^k))
  subn <- c(2^-1074, 3 * 2^-1074, 2^-1022 - 2^-1074)
  base <- unique(c(pow2, neigh, rand, subn, 0, .Machine$double.xmax))
  xs <- c(base, -base)
  xs[is.finite(xs)]
}
