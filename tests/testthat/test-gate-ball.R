## GATE 6 -- the norm-ball certificate against external referents.
##
## Written before R/ball-certificate.R. The predictions and their numbers are
## in dev/PREREGISTRO_FASE_6.md, section 3; nothing here was chosen after
## seeing a result. The batteries are large and carry skip_on_cran(), as every
## gate of this package does.

test_that("GATE 6 / P1: the certified ball contains the true fixed point", {
  skip_on_cran()
  skip_if_not(ra_has_mpfr(), "the rigorous referent needs Rmpfr")
  ## AFFINE MAPS IN R^n. Phi(x) = A x + b with ||A||_inf < 1 has exactly one
  ## fixed point, x* = (I - A)^{-1} b. Two referents, neither of them this
  ## package's algebra:
  ##
  ##   (a) the LAPACK solution, whose distance to the truth is bounded by an
  ##       MPFR residual through the Neumann bound ||(I-A)^{-1}|| <= 1/(1-||A||);
  ##   (b) on a subsample, the MPFR iteration of Phi itself, which computes the
  ##       fixed point without ever solving a system.
  ##
  ## The prediction is 200 of 200 with no exception, and n reaching 8: a
  ## battery that only exercised n = 1 would be measuring something else.
  n_inst <- as.integer(Sys.getenv("RA_GATE6_N", "200"))
  set.seed(20260820)
  prec <- 300L
  fallos <- 0L
  peor <- 0
  dims <- integer(0)

  for (k in seq_len(n_inst)) {
    n <- sample(1:8, 1L)
    dims <- c(dims, n)
    ## A with row sums bounded well below one, entries of dispar magnitude.
    A <- matrix(rnorm(n * n) * 10^runif(n * n, -3, 0), n, n)
    fila <- rowSums(abs(A))
    A <- A * (0.75 / max(fila))                    # ||A||_inf = 0.75 exactly
    b <- rnorm(n) * 10^runif(n, -2, 2)
    cc <- rnorm(n) * 10^runif(n, -2, 2)            # an arbitrary centre

    ## The two upper bounds the caller owes the certificate, rounded OUT so
    ## that they really are upper bounds and not the double that came closest.
    rho <- ra_succ(max(abs(A %*% cc + b - cc)))
    L <- ra_succ(max(rowSums(abs(A))))
    cert <- ra_ball_certificate(rho, L, norm = "sup")
    if (!isTRUE(cert$contraction)) { fallos <- fallos + 1L; next }

    ## Referent (a): LAPACK plus an MPFR residual.
    xhat <- solve(diag(n) - A, b)
    Am <- Rmpfr::mpfr(A, prec); bm <- Rmpfr::mpfr(b, prec)
    xm <- Rmpfr::mpfr(xhat, prec)
    res <- as.numeric(Rmpfr::asNumeric(max(abs((xm - Am %*% xm) - bm))))
    delta <- res / (1 - 0.75)                      # Neumann bound on ||xhat - x*||
    dist <- max(abs(xhat - cc))
    ## Conservative direction: the true fixed point can be delta away from the
    ## LAPACK one, so the distance to charge the certificate is dist + delta.
    if (!((dist + delta) <= cert$error_bound)) fallos <- fallos + 1L
    peor <- max(peor, (dist + delta) / cert$error_bound)

    ## The published radius certifies itself (P1.2).
    otra <- ra_ball_certificate(rho, L, radius = cert$radius, norm = "sup")
    if (!isTRUE(otra$confined)) fallos <- fallos + 1L

    ## Referent (b), on a subsample: the fixed point by MPFR iteration, which
    ## never solves a system.
    if (k %% 20L == 0L) {
      xi <- Rmpfr::mpfr(rep(0, n), prec)
      for (it in seq_len(400L)) xi <- Am %*% xi + bm
      xi <- as.numeric(Rmpfr::asNumeric(xi))
      if (!(max(abs(xi - cc)) <= cert$error_bound)) fallos <- fallos + 1L
      if (!(max(abs(xi - xhat)) <= 1e-8 * max(1, max(abs(xhat))))) fallos <- fallos + 1L
    }
  }

  cat(sprintf("\n  GATE 6 / P1: %d instancias, dim %d a %d, peor cociente %.4f\n",
              n_inst, min(dims), max(dims), peor))
  expect_identical(fallos, 0L)
  expect_true(max(dims) >= 6)             # el porton NO admite cerrar con n chico
})

test_that("GATE 6 / P3: Gershgorin encloses every eigenvalue, Weyl bounds every sum", {
  skip_on_cran()
  set.seed(20260821)
  n_g <- as.integer(Sys.getenv("RA_GATE6_G", "500"))
  fuera <- 0L
  ajustados <- 0L
  for (k in seq_len(n_g)) {
    m <- sample(2:12, 1L)
    tipo <- sample(c("generica", "diagonal", "casi_degenerada", "mal_condicionada"), 1L)
    A <- switch(tipo,
      generica = { M <- matrix(rnorm(m * m), m, m); (M + t(M)) / 2 },
      diagonal = diag(rnorm(m) * 10^runif(m, -2, 2), m),
      casi_degenerada = { d <- rep(rnorm(1), m) + rnorm(m) * 1e-12
                          M <- diag(d, m); M[1, 2] <- M[2, 1] <- 1e-13; M },
      mal_condicionada = { M <- matrix(rnorm(m * m), m, m) * 10^runif(m * m, -6, 6)
                           (M + t(M)) / 2 })
    g <- ra_gershgorin(A)
    ev <- eigen(A, symmetric = TRUE, only.values = TRUE)$values
    if (!all(ev >= ra_inf(g) & ev <= ra_sup(g))) fuera <- fuera + 1L
    if (tipo == "diagonal") {
      ## En una diagonal la cota es AJUSTADA, y es el caso que separa un
      ## Gershgorin implementado de uno inventado.
      d <- diag(A)
      if (!(isTRUE(all.equal(ra_inf(g), min(d))) &&
            isTRUE(all.equal(ra_sup(g), max(d))))) fuera <- fuera + 1L
      ajustados <- ajustados + 1L
    }
  }
  cat(sprintf("  GATE 6 / P3: %d matrices, %d diagonales con cota ajustada\n",
              n_g, ajustados))
  expect_identical(fuera, 0L)
  expect_true(ajustados > 0L)

  n_w <- as.integer(Sys.getenv("RA_GATE6_W", "300"))
  fuera_w <- 0L
  for (k in seq_len(n_w)) {
    m <- sample(2:8, 1L)
    A <- { M <- matrix(rnorm(m * m), m, m); (M + t(M)) / 2 }
    B <- { M <- matrix(rnorm(m * m), m, m); (M + t(M)) / 2 }
    ea <- range(eigen(A, symmetric = TRUE, only.values = TRUE)$values)
    eb <- range(eigen(B, symmetric = TRUE, only.values = TRUE)$values)
    es <- range(eigen(A + B, symmetric = TRUE, only.values = TRUE)$values)
    s <- ra_spectral_sum(ra_interval(ea[1], ea[2]), ra_interval(eb[1], eb[2]))
    if (!(ra_inf(s) <= es[1] && ra_sup(s) >= es[2])) fuera_w <- fuera_w + 1L
  }
  expect_identical(fuera_w, 0L)
})

test_that("GATE 6 / P4: the directed rounding changes the verdict, and only towards refusing", {
  skip_on_cran()
  ## Se busca un caso donde la aritmetica ingenua en doble ACEPTE y la dirigida
  ## RECHACE. La direccion contraria no puede pasar y tambien se vigila: si
  ## apareciera, el redondeo estaria entrando al reves.
  set.seed(20260822)
  encontrados <- 0L
  al_reves <- 0L
  for (k in seq_len(20000L)) {
    r <- 2^runif(1, -6, 6)
    L <- runif(1, 0.1, 0.999)
    rho <- (1 - L) * r                       # justo en el borde, hasta redondeo
    rho <- rho * (1 + rnorm(1) * 1e-16)      # empujado un ulp para los dos lados
    if (rho <= 0) next
    ingenuo <- (L * r + rho) <= r
    cert <- ra_ball_certificate(rho, L, radius = r)
    if (ingenuo && !cert$confined) encontrados <- encontrados + 1L
    if (!ingenuo && cert$confined) al_reves <- al_reves + 1L
  }
  cat(sprintf("  GATE 6 / P4: %d casos donde lo dirigido rechaza y lo ingenuo acepta; %d al reves\n",
              encontrados, al_reves))
  expect_true(encontrados > 0L)
  expect_identical(al_reves, 0L)
})
