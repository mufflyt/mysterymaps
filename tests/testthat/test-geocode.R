# Geocoding calls the Google Maps API, so nothing here touches the network.
# What is tested is the file reading, the retry-and-give-up behaviour, and the
# row-alignment guard -- which is the one that matters, because a geocoder that
# returns the wrong NUMBER of rows silently attaches each coordinate to the
# wrong address.

write_addresses <- function(dir, ext = "csv", addresses = c("1 A St", "2 B Ave")) {
  path <- file.path(dir, paste0("addr.", ext))
  df <- data.frame(address = addresses, id = seq_along(addresses))
  switch(ext,
         csv  = utils::write.csv(df, path, row.names = FALSE),
         rds  = saveRDS(df, path),
         txt  = writeLines("nope", path))
  path
}

mock_ggmap <- function(geocode) {
  skip_if_not_installed("ggmap")
  local_mocked_bindings(
    geocode = geocode,
    register_google = function(...) invisible(NULL),
    .package = "ggmap",
    .env = parent.frame())
}

test_that("a missing input file is refused before anything else", {
  expect_error(mysterymaps_geocode(tempfile(), "key"), "Input file not found")
})

test_that("an unsupported extension is named in the error", {
  dir <- withr::local_tempdir()
  expect_error(mysterymaps_geocode(write_addresses(dir, "txt"), "key"),
               "Unsupported file type: txt")
})

test_that("a file with no address column is refused", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "x.csv")
  utils::write.csv(data.frame(street = "1 A St"), path, row.names = FALSE)
  expect_error(mysterymaps_geocode(path, "key"),
               "must have a column named 'address'")
})

test_that("CSV and RDS inputs both reach the geocoder", {
  skip_if_not_installed("ggmap")
  mock_ggmap(function(x, ...) data.frame(lat = c(40, 41), lon = c(-100, -101)))
  dir <- withr::local_tempdir()

  for (ext in c("csv", "rds")) {
    out <- suppressMessages(mysterymaps_geocode(write_addresses(dir, ext), "key"))
    expect_true(all(c("latitude", "longitude") %in% names(out)))
    expect_equal(nrow(out), 2L)
  }
})

test_that("coordinates are joined back to every original row, by address", {
  # The unique-address optimisation is where a mis-join would show up: three
  # rows sharing one address must all receive that address's coordinate.
  skip_if_not_installed("ggmap")
  mock_ggmap(function(x, ...) data.frame(lat = 40, lon = -100))
  dir <- withr::local_tempdir()
  path <- file.path(dir, "dupes.csv")
  utils::write.csv(data.frame(address = rep("1 A St", 3), id = 1:3), path,
                   row.names = FALSE)

  out <- suppressMessages(mysterymaps_geocode(path, "key"))
  expect_equal(nrow(out), 3L)
  expect_true(all(out$latitude == 40))
})

test_that("a non-data-frame API response is rejected", {
  skip_if_not_installed("ggmap")
  mock_ggmap(function(x, ...) "surprise")
  dir <- withr::local_tempdir()
  expect_error(suppressMessages(mysterymaps_geocode(write_addresses(dir), "key")),
               "unexpected data type")
})

test_that("a response missing lat or lon names the columns it did get", {
  skip_if_not_installed("ggmap")
  mock_ggmap(function(x, ...) data.frame(latitude = 40, longitude = -100))
  dir <- withr::local_tempdir()
  expect_error(suppressMessages(mysterymaps_geocode(write_addresses(dir), "key")),
               "got: latitude, longitude")
})

test_that("REGRESSION: a short response blanks ALL coordinates rather than misaligning", {
  # Returning 1 row for 2 addresses and recycling would give address 2 the
  # coordinate of address 1 -- a wrong answer that looks entirely normal.
  skip_if_not_installed("ggmap")
  mock_ggmap(function(x, ...) data.frame(lat = 40, lon = -100))
  dir <- withr::local_tempdir()

  out <- suppressMessages(
    mysterymaps_geocode(write_addresses(dir, addresses = c("1 A St", "2 B Ave")),
                        "key"))
  expect_true(all(is.na(out$latitude)))
  expect_true(all(is.na(out$longitude)))
})

test_that("the retry gives up after three attempts and reports why", {
  skip_if_not_installed("ggmap")
  attempts <- 0L
  mock_ggmap(function(x, ...) {
    attempts <<- attempts + 1L
    stop("HTTP 503 service unavailable")
  })
  # The backoff sleeps 1s then 2s; make it instant.
  local_mocked_bindings(Sys.sleep = function(...) invisible(NULL),
                        .package = "base")
  dir <- withr::local_tempdir()

  expect_error(
    suppressMessages(mysterymaps_geocode(write_addresses(dir), "key")),
    "failed after 3 attempts")
  expect_equal(attempts, 3L)
})

test_that("a transient failure followed by success is not fatal", {
  skip_if_not_installed("ggmap")
  n <- 0L
  mock_ggmap(function(x, ...) {
    n <<- n + 1L
    if (n == 1L) stop("HTTP 500") else data.frame(lat = c(40, 41), lon = c(-100, -101))
  })
  local_mocked_bindings(Sys.sleep = function(...) invisible(NULL),
                        .package = "base")
  dir <- withr::local_tempdir()

  out <- suppressMessages(mysterymaps_geocode(write_addresses(dir), "key"))
  expect_equal(nrow(out), 2L)
  expect_false(anyNA(out$latitude))
})

test_that("failed addresses are written to failed_output_path", {
  skip_if_not_installed("ggmap")
  mock_ggmap(function(x, ...) data.frame(lat = c(40, NA), lon = c(-100, NA)))
  dir <- withr::local_tempdir()
  failed <- file.path(dir, "failed.csv")

  suppressMessages(
    mysterymaps_geocode(write_addresses(dir), "key", failed_output_path = failed))

  expect_true(file.exists(failed))
  expect_equal(nrow(utils::read.csv(failed)), 1L)
})

test_that("a total API failure still writes the failure list when asked", {
  skip_if_not_installed("ggmap")
  mock_ggmap(function(x, ...) stop("HTTP 401 unauthorised"))
  local_mocked_bindings(Sys.sleep = function(...) invisible(NULL),
                        .package = "base")
  dir <- withr::local_tempdir()
  failed <- file.path(dir, "failed.csv")

  expect_error(
    suppressMessages(
      mysterymaps_geocode(write_addresses(dir), "key",
                          failed_output_path = failed)))
  expect_true(file.exists(failed))
  expect_true("reason" %in% names(utils::read.csv(failed)))
})

test_that("output_file_path receives the enriched table", {
  skip_if_not_installed("ggmap")
  mock_ggmap(function(x, ...) data.frame(lat = c(40, 41), lon = c(-100, -101)))
  dir <- withr::local_tempdir()
  out_path <- file.path(dir, "geocoded.csv")

  suppressMessages(
    mysterymaps_geocode(write_addresses(dir), "key", output_file_path = out_path))

  written <- utils::read.csv(out_path)
  expect_true(all(c("address", "latitude", "longitude") %in% names(written)))
  expect_equal(nrow(written), 2L)
})

test_that("quiet = TRUE suppresses the progress chatter", {
  skip_if_not_installed("ggmap")
  mock_ggmap(function(x, ...) data.frame(lat = c(40, 41), lon = c(-100, -101)))
  dir <- withr::local_tempdir()
  path <- write_addresses(dir)

  expect_silent(mysterymaps_geocode(path, "key", quiet = TRUE))
  expect_message(mysterymaps_geocode(path, "key", quiet = FALSE), "Geocoding")
})

test_that("ggmap is named in the error when it is not installed", {
  dir <- withr::local_tempdir()
  path <- write_addresses(dir)
  local_mocked_bindings(
    requireNamespace = function(package, ...) !identical(package, "ggmap"),
    .package = "base")
  expect_error(mysterymaps_geocode(path, "key"), "'ggmap' is required")
})
