## Phase 6 -- the norm-ball fixed point certificate.
##
## WRITTEN BEFORE R/ball-certificate.R, as the rule of the way demands: the
## controls come first, and among them the ones that must refuse. The design
## and its algebra are in dev/PREREGISTRO_FASE_6.md; every assertion below
## names the theorem or the prediction it exercises.

test_that("T1/T2: confinement is emitted exactly when L*r + rho <= r", {
  ## rho = 0.2, L = 0.5  =>  r* = 0.4. Below it, nothing; at it and above, the
  ## confinement certificate, which is prediction P2.2.
  cert_small <- ra_ball_certificate(0.2, 0.5, radius = 0.399)
  expect_false(cert_small$confined)
  expect_false(cert_small$contraction)

  ## El borde se juzga contra el radio minimo, que viene redondeado hacia
  ## arriba: un radio UN ULP por debajo de el se rechaza, y el radio mismo se
  ## acepta. Pedirle que acepte el 0.4 exacto seria pedirle una exactitud que
  ## el redondeo hacia afuera no promete, y que la §5.3 del paquete ya dejo
  ## declarada como precio del diseño y no como defecto.
  r_star <- ra_ball_certificate(0.2, 0.5)$radius
  expect_false(ra_ball_certificate(0.2, 0.5, radius = ra_pred(r_star))$confined)
  cert_at <- ra_ball_certificate(0.2, 0.5, radius = r_star)
  expect_true(cert_at$confined)
  expect_true(cert_at$contraction)

  cert_big <- ra_ball_certificate(0.2, 0.5, radius = 4)
  expect_true(cert_big$confined)
  expect_true(cert_big$contraction)
})

test_that("T4: the minimal certified radius is rho/(1-L) and certifies itself", {
  cert <- ra_ball_certificate(0.2, 0.5)
  expect_true(cert$confined)
  expect_true(cert$contraction)
  expect_true(cert$radius >= 0.4)                 # rounded outwards, never below
  expect_true(cert$radius < 0.4 + 1e-12)
  ## The published radius re-certifies itself: that is prediction P1.2.
  again <- ra_ball_certificate(0.2, 0.5, radius = cert$radius)
  expect_true(again$confined)
  ## And the error bound on the centre is that same radius.
  expect_identical(cert$error_bound, cert$radius)
})

test_that("P2.1 CONTROL THAT MUST REFUSE: the translation has no fixed point", {
  ## Phi(x) = x + v is an isometry with L = 1 exactly and residual ||v||. It has
  ## no fixed point anywhere, and the certificate must refuse it for the right
  ## reason -- L not below one -- and not through an NA or a silent zero.
  cert <- ra_ball_certificate(1, 1)
  expect_false(cert$confined)
  expect_false(cert$contraction)
  expect_true(is.na(cert$radius))
  expect_match(cert$reason, "1", fixed = TRUE)
  ## Even with a huge radius offered, confinement is unreachable: L*r + rho <= r
  ## reduces to rho <= 0.
  big <- ra_ball_certificate(1, 1, radius = 1e12)
  expect_false(big$confined)
})

test_that("a zero residual at the centre makes the centre itself the fixed point", {
  cert <- ra_ball_certificate(0, 0.5)
  expect_true(cert$confined)
  expect_true(cert$contraction)
  expect_identical(cert$radius, 0)
  expect_identical(cert$error_bound, 0)
})

test_that("L at one ulp below one still certifies, and the radius blows up honestly", {
  L <- 1 - 2^-40
  cert <- ra_ball_certificate(1e-6, L)
  expect_true(cert$contraction)
  expect_true(cert$radius > 1e6)                  # rho/(1-L) ~ 1.1e6
  expect_true(is.finite(cert$radius))
})

test_that("a denominator that rounds to zero refuses instead of returning Inf", {
  ## 1 - sup(L) underflows to zero when L is within an ulp of one. The refusal
  ## is the right answer and it must be a word, never an Inf travelling as a
  ## radius.
  cert <- ra_ball_certificate(1e-3, 1 - 2^-60)
  if (cert$contraction) {
    expect_true(is.finite(cert$radius))
  } else {
    expect_true(is.na(cert$radius))
    expect_true(nzchar(cert$reason))
  }
})

test_that("the arguments are validated and the norm label travels", {
  expect_error(ra_ball_certificate(-1, 0.5), class = "ra_bad_argument")
  expect_error(ra_ball_certificate(0.1, -0.5), class = "ra_bad_argument")
  expect_error(ra_ball_certificate(0.1, 0.5, radius = -1), class = "ra_bad_argument")
  ## El radio CERO se admite: la bola degenerada es convexa, compacta y no
  ## vacia, de modo que Brouwer se le aplica. Se rechaza por no alcanzar el
  ## radio minimo, no por invalido.
  expect_false(ra_ball_certificate(0.1, 0.5, radius = 0)$confined)
  cert <- ra_ball_certificate(0.1, 0.5, norm = "sup")
  expect_identical(cert$norm, "sup")
  expect_identical(ra_ball_certificate(0.1, 0.5)$norm, "unspecified")
})

test_that("intervals are accepted and their SUPREMA are what rule", {
  ## The certificate consumes upper bounds. Handing it an interval must give
  ## the same verdict as handing it that interval's supremum, and a strictly
  ## wider interval must never certify more.
  a <- ra_ball_certificate(ra_interval(0.1, 0.2), ra_interval(0.4, 0.5))
  b <- ra_ball_certificate(0.2, 0.5)
  expect_equal(a$radius, b$radius)
  expect_identical(a$confined, b$confined)
})

test_that("S3: the provenance of the inputs propagates, weakest wins", {
  th <- ra_interval(0.2, 0.2)
  ms <- ra_interval(0.5, 0.5)
  ms$prov <- "measured"
  th$prov <- "theorem"
  expect_identical(ra_ball_certificate(th, th)$prov, "theorem")
  expect_identical(ra_ball_certificate(th, ms)$prov, "measured")
  expect_identical(ra_ball_certificate(ms, th)$prov, "measured")
})

test_that("T6 Gershgorin encloses the spectrum, and is exact on a diagonal", {
  A <- diag(c(-2, 5, 0.5))
  g <- ra_gershgorin(A)
  expect_true(ra_inf(g) <= -2)
  expect_true(ra_sup(g) >= 5)
  ## Radii are zero on a diagonal, so the enclosure is the extreme diagonal
  ## entries and nothing wider: the case where the bound is tight is the one
  ## that separates an implemented Gershgorin from an invented one.
  expect_equal(ra_inf(g), -2)
  expect_equal(ra_sup(g), 5)

  B <- matrix(c(4, 1, 1, 3), 2, 2)
  gb <- ra_gershgorin(B)
  ev <- eigen(B, symmetric = TRUE, only.values = TRUE)$values
  expect_true(all(ev >= ra_inf(gb) & ev <= ra_sup(gb)))

  expect_error(ra_gershgorin(matrix(1:6, 2, 3)), class = "ra_bad_argument")
  expect_error(ra_gershgorin(matrix(c(1, 2, 3, 4), 2, 2)), class = "ra_bad_argument")
})

test_that("T7 Weyl bounds the spectrum of a sum, and is checked against eigen", {
  set.seed(606)
  A <- crossprod(matrix(rnorm(9), 3, 3))
  B <- crossprod(matrix(rnorm(9), 3, 3))
  ea <- range(eigen(A, symmetric = TRUE, only.values = TRUE)$values)
  eb <- range(eigen(B, symmetric = TRUE, only.values = TRUE)$values)
  s <- ra_spectral_sum(ra_interval(ea[1], ea[2]), ra_interval(eb[1], eb[2]))
  es <- range(eigen(A + B, symmetric = TRUE, only.values = TRUE)$values)
  expect_true(ra_inf(s) <= es[1])
  expect_true(ra_sup(s) >= es[2])
})

test_that("the univariate door derives rho and L itself over the ball", {
  ## Phi(x) = x/2 + 1 has the fixed point 2. From the centre 1.9 the residual is
  ## 0.05 and the Lipschitz constant is 1/2 everywhere, so r* = 0.1 and the
  ## certified ball [1.8, 2.0] contains 2.
  cert <- ra_certify_fixed_point(quote(x / 2 + 1), centre = 1.9, radius = 0.5)
  expect_true(cert$confined)
  expect_true(cert$contraction)
  expect_true(cert$error_bound >= 0.1)
  expect_true(cert$error_bound < 0.1 + 1e-9)
})

test_that("P2.3 the univariate door refuses where a centre-only L would certify", {
  ## Phi(x) = x^2 has derivative 2x: at the centre 0.4 it is 0.8 < 1, and over
  ## the ball of radius 0.4 it reaches 1.6. A caller who measured L at the
  ## centre gets a certificate that means nothing; the door that derives L over
  ## the ball refuses. This is what makes the declared responsibility real.
  ## Con L medido solo en el centro (0.8) el radio minimo es 0.24/0.2 = 1.2, de
  ## modo que la bola de radio 0.4 no alcanza ni con la premisa falsa; lo que
  ## SI muestra la premisa falsa es que el certificado se emite con radio 1.2 y
  ## afirma una contraccion que sobre esa bola no existe.
  centre_only <- ra_ball_certificate(0.24, 0.8)
  expect_true(centre_only$contraction)            # certified on a false premise
  expect_true(centre_only$radius > 1)
  door <- ra_certify_fixed_point(quote(x^2), centre = 0.4, radius = 0.4)
  expect_false(door$contraction)                  # the door refuses
  expect_true(door$lipschitz >= 1.6)              # because it measured L over the ball
})

test_that("the class drags everything a class drags", {
  cert <- ra_ball_certificate(0.2, 0.5, norm = "sup")
  expect_s3_class(cert, "ra_certificate")
  expect_type(format(cert), "character")
  expect_output(print(cert), "certificate")
  d <- as.data.frame(cert)
  expect_s3_class(d, "data.frame")
  expect_true(all(c("confined", "contraction", "radius", "norm") %in% names(d)))
  s <- summary(cert)
  expect_s3_class(s, "ra_summary_certificate")
  expect_type(format(s), "character")
  expect_output(print(s), "certificate")
})

test_that("E-1: confinement by DIRECT image, without contraction", {
  ## The fixture the amendment made possible, and the one VI.3 demands be
  ## distinguishable. Phi(x) = x^2 over the ball of centre 0.4 and radius 0.4,
  ## that is [0, 0.8]: its image is [0, 0.64], contained -- confinement by
  ## direct evaluation -- while sup|Phi'| = 1.6 over the ball refutes the
  ## contraction. There is a fixed point inside (the origin) and uniqueness is
  ## not claimed.
  cert <- ra_ball_certificate(rho = 0.24, lipschitz = 1.6,
                              radius = 0.4, image_radius = 0.4)
  expect_true(cert$confined)
  expect_false(cert$contraction)
  expect_identical(cert$route, "image")
  ## Through the Lipschitz route alone the same numbers certify nothing: that
  ## is exactly why the third input exists.
  solo_lip <- ra_ball_certificate(rho = 0.24, lipschitz = 1.6, radius = 0.4)
  expect_false(solo_lip$confined)
})

test_that("E-1: the route that decided travels in the object", {
  by_lip <- ra_ball_certificate(0.2, 0.5, radius = 1)
  expect_true(by_lip$confined)
  expect_identical(by_lip$route, "lipschitz")
  ## A direct image radius that fails does not veto a Lipschitz route that
  ## succeeds: the certificate takes whichever theorem reaches.
  both <- ra_ball_certificate(0.2, 0.5, radius = 1, image_radius = 9)
  expect_true(both$confined)
  expect_identical(both$route, "lipschitz")
})

test_that("E-1: no Lipschitz constant means no minimal radius and no contraction", {
  cert <- ra_ball_certificate(0.2, radius = 1, image_radius = 0.5)
  expect_true(cert$confined)
  expect_false(cert$contraction)
  expect_true(is.na(cert$lipschitz))
  expect_error(ra_ball_certificate(0.2, image_radius = 0.5), class = "ra_bad_argument")
})

test_that("ra_certificate [print fixture] reads as prose and names both words", {
  cert <- ra_ball_certificate(0.2, 0.5, norm = "sup")
  txt <- paste(format(cert), collapse = " ")
  expect_match(txt, "confinement", ignore.case = TRUE)
  expect_match(txt, "contraction", ignore.case = TRUE)
  ## The doctrinal boundary of VI.3 must be visible on the card when there is
  ## confinement without contraction: enclosure is certified, what happens
  ## inside is not claimed.
  weak <- ra_ball_certificate(rho = 0.24, lipschitz = 1.6,
                              radius = 0.4, image_radius = 0.4)
  wtxt <- paste(format(weak), collapse = " ")
  expect_match(wtxt, "not claimed", ignore.case = TRUE)
})
