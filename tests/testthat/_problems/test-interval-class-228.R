# Extracted from test-interval-class.R:228

# test -------------------------------------------------------------------------
x <- c(ra_interval(1, 2), ra_interval(3, 4), ra_empty())
expect_identical(length(x), 3L)
expect_identical(ra_inf(x[2]), 3)
expect_identical(length(x[c(1, 3)]), 2L)
d <- as.data.frame(x)
expect_identical(nrow(d), 3L)
expect_identical(names(d), c("lo", "hi", "dec", "wid"))
