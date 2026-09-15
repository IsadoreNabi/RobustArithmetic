## Generate R/sysdata.rda from the sealed CORE-MATH hard cases.
##
## Usage:
##   Rscript dev/gen_sentinels.R [sealed CORE-MATH archive]
##
## The expected values are computed with Rmpfr at 200 bits and converted once
## with asNumeric(). They are never read from .ra_cr() or from the expected
## output column of the embedded core-math cases.

stopifnot(file.exists("DESCRIPTION"))

if (!requireNamespace("Rmpfr", quietly = TRUE)) {
  stop("Package 'Rmpfr' is required to generate the sentinels.", call. = FALSE)
}

arguments <- commandArgs(trailingOnly = TRUE)
archive <- if (length(arguments)) {
  arguments[[1L]]
} else {
  path.expand("~/.cache/ra-research/coremath/pin_1ab68b70/src_binary64.tar.gz")
}
if (!file.exists(archive)) {
  stop("The sealed CORE-MATH archive does not exist: ", archive, call. = FALSE)
}

expected_archive_sha256 <-
  "52f35d1029a6c6423f8c537f59164b2359cffe98c1ca2079ea55caf5d1820ce5"
hash_line <- system2("sha256sum", archive, stdout = TRUE, stderr = TRUE)
archive_sha256 <- strsplit(hash_line[[1L]], "[[:space:]]+")[[1L]][[1L]]
if (!identical(archive_sha256, expected_archive_sha256)) {
  stop("The CORE-MATH archive does not match the sealed SHA-256.", call. = FALSE)
}

functions <- c(
  "exp", "log", "sin", "cos", "tan", "sinh", "cosh", "tanh", "sqrt",
  "expm1", "log1p", "log2", "log10", "asin", "acos", "atan"
)
software_functions <- setdiff(functions, "sqrt")
commit <- "1ab68b70b90f807fd2bc9cf20ec295d49ae09592"

members <- utils::untar(archive, list = TRUE)
wc_members <- vapply(software_functions, function(function_name) {
  suffix <- paste0("/src/binary64/", function_name, "/", function_name, ".wc")
  found <- members[endsWith(members, suffix)]
  if (length(found) != 1L) {
    stop("Expected exactly one sealed .wc member for ", function_name,
         "; found ", length(found), ".", call. = FALSE)
  }
  found
}, character(1L), USE.NAMES = TRUE)

extraction_directory <- tempfile("ra-sentinels-")
dir.create(extraction_directory)
on.exit(unlink(extraction_directory, recursive = TRUE), add = TRUE)
status <- utils::untar(archive, files = unname(wc_members),
                       exdir = extraction_directory)
if (!identical(status, 0L)) {
  stop("The sealed .wc files could not be extracted.", call. = FALSE)
}

bits_to_double <- function(pattern) {
  vapply(pattern, function(one) {
    bytes <- as.raw(strtoi(
      substring(one, seq.int(1L, 15L, 2L), seq.int(2L, 16L, 2L)),
      base = 16L
    ))
    readBin(rev(bytes), "double", size = 8L, endian = "little")
  }, numeric(1L), USE.NAMES = FALSE)
}

select_evenly <- function(values, count = 8L) {
  values <- values[is.finite(values)]
  values <- values[!duplicated(values)]
  if (length(values) < count) {
    stop("A sentinel source contains fewer than ", count,
         " distinct finite inputs.", call. = FALSE)
  }
  positions <- as.integer(round(seq.int(1L, length(values), length.out = count)))
  list(values = values[positions], positions = positions)
}

read_wc <- function(function_name) {
  path <- file.path(extraction_directory, wc_members[[function_name]])
  tokens <- scan(path, what = character(), comment.char = "#", quiet = TRUE)
  values <- suppressWarnings(as.numeric(tokens))
  nonnumeric <- unique(tokens[is.na(values)])
  admitted_specials <- c("-nan", "+nan", "-snan", "+snan")
  bad <- setdiff(nonnumeric, admitted_specials)
  if (length(bad)) {
    stop("Unparseable token in ", function_name, ".wc: ", bad[[1L]],
         call. = FALSE)
  }
  values <- values[!is.na(values)]
  in_domain <- switch(
    function_name,
    log = , log2 = , log10 = values > 0,
    log1p = values > -1,
    asin = , acos = values >= -1 & values <= 1,
    rep(TRUE, length(values))
  )
  select_evenly(values[in_domain])
}

read_sqrt_sample <- function() {
  path <- file.path("tests", "testthat", "core-math-cases.csv")
  cases <- utils::read.csv(path, colClasses = "character")
  if (!identical(names(cases), c("fun", "x_bits", "y_bits"))) {
    stop("The embedded core-math case table has an unexpected schema.",
         call. = FALSE)
  }
  inputs <- bits_to_double(cases$x_bits[cases$fun == "sqrt"])
  select_evenly(inputs[is.finite(inputs) & inputs >= 0])
}

selected <- lapply(functions, function(function_name) {
  if (identical(function_name, "sqrt")) read_sqrt_sample() else read_wc(function_name)
})
names(selected) <- functions

rows <- lapply(functions, function(function_name) {
  source <- selected[[function_name]]
  argument <- source$values
  exact <- do.call(function_name, list(Rmpfr::mpfr(argument, precBits = 200L)))
  expected <- Rmpfr::asNumeric(exact)
  if (length(expected) != length(argument) || anyNA(expected)) {
    stop("Rmpfr did not produce eight non-missing references for ",
         function_name, ".", call. = FALSE)
  }
  data.frame(
    fun = function_name,
    x = argument,
    cr = expected,
    role = if (identical(function_name, "sqrt")) "sample_case" else "hard_case",
    source = if (identical(function_name, "sqrt")) {
      "sealed binary64 sample"
    } else {
      paste0("CORE-MATH ", substr(commit, 1L, 8L), " .wc")
    },
    source_index = source$positions,
    stringsAsFactors = FALSE
  )
})

.ra_sentinels <- do.call(rbind, rows)
row.names(.ra_sentinels) <- NULL
stopifnot(
  identical(names(table(.ra_sentinels$fun)), sort(functions)),
  all(table(.ra_sentinels$fun) == 8L),
  all(is.finite(.ra_sentinels$x)),
  !any(grepl("route", .ra_sentinels$role, ignore.case = TRUE))
)

save(.ra_sentinels, file = file.path("R", "sysdata.rda"), compress = "xz")
cat("R/sysdata.rda written from sealed independent sources:",
    nrow(.ra_sentinels), "sentinels.\n")
