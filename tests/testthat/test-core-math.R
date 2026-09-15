ra_core_bits_to_double <- function(bits) {
  vapply(bits, function(pattern) {
    bytes <- as.raw(strtoi(
      substring(pattern, seq(1L, 15L, 2L), seq(2L, 16L, 2L)),
      16L
    ))
    readBin(rev(bytes), "double", size = 8L, endian = "little")
  }, numeric(1L), USE.NAMES = FALSE)
}

ra_core_double_to_bits <- function(value) {
  vapply(value, function(element) {
    paste(
      rev(as.character(writeBin(element, raw(), size = 8L, endian = "little"))),
      collapse = ""
    )
  }, character(1L), USE.NAMES = FALSE)
}

test_that("vendored elementary functions match the embedded MPFR cases", {
  cases <- utils::read.csv(
    testthat::test_path("core-math-cases.csv"),
    colClasses = "character"
  )
  evaluator <- get(".ra_cr", envir = asNamespace("RobustArithmetic"))

  expect_identical(names(cases), c("fun", "x_bits", "y_bits"))
  expect_true(all(table(cases$fun) == 128L))

  for (function_name in unique(cases$fun)) {
    selected <- cases[cases$fun == function_name, , drop = FALSE]
    input <- ra_core_bits_to_double(selected$x_bits)
    expected <- ra_core_bits_to_double(selected$y_bits)
    actual <- evaluator(function_name, input)
    missing <- is.na(expected)

    expect_true(
      all(is.na(actual[missing])),
      info = paste(function_name, "not-a-number results")
    )
    expect_identical(
      ra_core_double_to_bits(actual[!missing]),
      selected$y_bits[!missing],
      info = paste(function_name, "finite and infinite results")
    )
  }
})
