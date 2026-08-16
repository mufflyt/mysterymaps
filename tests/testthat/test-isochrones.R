# Isochrone generation talks to the HERE routing API, so none of these tests
# make a network call. What is tested is everything around the call: the
# guards, the key handling, the memoisation, the shape of a failure, and the
# per-row bookkeeping in the data-frame wrapper.

fake_isoline <- function(...) {
  args <- list(...)
  sf::st_sf(
    id       = 1L,
    rank     = 1L,
    range    = args$range,
    departure = as.character(args$datetime),
    geometry = mm_square(x = -100, y = 40, w = args$range / 3600))
}

# hereR's setters are called for their side effects on package state; in a test
# they only need to not fail.
mock_hereR <- function(isoline = fake_isoline) {
  skip_if_not_installed("hereR")
  # Blank HERE_API_KEY for the duration. These tests pass an explicit api_key
  # and must prove that argument works; with a real key in the developer's
  # environment they would pass even when the argument is ignored entirely --
  # which is exactly how the missing api_key= forwarding in
  # mysterymaps_isochrones_for_df() survived local runs and only failed on CI.
  withr::local_envvar(c(HERE_API_KEY = ""), .local_envir = parent.frame())
  local_mocked_bindings(
    isoline = isoline,
    set_key = function(...) invisible(NULL),
    set_freemium = function(...) invisible(NULL),
    set_verbose = function(...) invisible(NULL),
    .package = "hereR",
    .env = parent.frame())
}

# --------------------------------------------------------------------------
# mysterymaps_create_isochrones
# --------------------------------------------------------------------------

test_that("a missing API key is an error naming the environment variable", {
  # The alternative is a 401 from HERE several minutes into a batch run.
  skip_if_not_installed("sf")
  skip_if_not_installed("hereR")
  expect_error(
    mysterymaps_create_isochrones(mm_points(1), range = 1800, api_key = ""),
    "HERE_API_KEY")
  expect_error(
    mysterymaps_create_isochrones(mm_points(1), range = 1800,
                                  api_key = NA_character_),
    "HERE_API_KEY")
})

test_that("each required package is named in its own error", {
  for (pkg in c("sf", "hereR", "lwgeom")) {
    local_mocked_bindings(
      requireNamespace = function(package, ...) !identical(package, pkg),
      .package = "base")
    expect_error(
      mysterymaps_create_isochrones(NULL, range = 1800, api_key = "k"),
      sprintf("'%s' is required", pkg))
  }
})

test_that("one sf polygon is returned per requested range, named in seconds", {
  skip_if_not_installed("sf")
  skip_if_not_installed("lwgeom")
  mock_hereR()
  res <- suppressMessages(
    mysterymaps_create_isochrones(mm_points(1), range = c(1800, 3600),
                                  api_key = "test-key-1"))

  expect_named(res, c("1800", "3600"))
  expect_s3_class(res[["1800"]], "sf")
  expect_equal(sf::st_crs(res[["1800"]])$epsg, 4326L)
})

test_that("an API failure returns a list carrying $error, not a hard stop", {
  # Documented contract: callers detect failure with is.null(result$error).
  # A stop() here would abort a 12,000-provider batch on one bad point.
  skip_if_not_installed("sf")
  skip_if_not_installed("lwgeom")
  mock_hereR(isoline = function(...) stop("HTTP 429 rate limited"))

  res <- suppressMessages(
    mysterymaps_create_isochrones(mm_points(1), range = 1800,
                                  api_key = "test-key-2"))
  expect_type(res, "list")
  expect_match(res$error, "429")
})

test_that("results are memoised, so the second identical call is free", {
  skip_if_not_installed("sf")
  skip_if_not_installed("lwgeom")
  skip_if_not_installed("memoise")
  calls <- 0L
  mock_hereR(isoline = function(...) {
    calls <<- calls + 1L
    fake_isoline(...)
  })

  loc <- mm_points(1)
  suppressMessages(mysterymaps_create_isochrones(loc, 1800, api_key = "memo-key"))
  first <- calls
  suppressMessages(mysterymaps_create_isochrones(loc, 1800, api_key = "memo-key"))
  expect_equal(calls, first)

  mysterymaps_clear_isochrone_cache()
})

test_that("clearing the cache makes the next call hit the API again", {
  skip_if_not_installed("sf")
  skip_if_not_installed("lwgeom")
  skip_if_not_installed("memoise")
  calls <- 0L
  mock_hereR(isoline = function(...) {
    calls <<- calls + 1L
    fake_isoline(...)
  })

  loc <- mm_points(1)
  suppressMessages(mysterymaps_create_isochrones(loc, 1800, api_key = "clear-key"))
  mysterymaps_clear_isochrone_cache()
  suppressMessages(mysterymaps_create_isochrones(loc, 1800, api_key = "clear-key"))
  expect_gte(calls, 2L)
})

test_that("clearing the cache is safe to call at any time", {
  expect_invisible(mysterymaps_clear_isochrone_cache())
  expect_null(mysterymaps_clear_isochrone_cache())
})

# --------------------------------------------------------------------------
# mysterymaps_isochrones_for_df
# --------------------------------------------------------------------------

test_that("a missing key is refused before any row is processed", {
  skip_if_not_installed("sf")
  skip_if_not_installed("hereR")
  skip_if_not_installed("easyr")
  expect_error(
    mysterymaps_isochrones_for_df(data.frame(lat = 40, long = -100),
                                  api_key = ""),
    "HERE_API_KEY")
})

test_that("lat/long columns are required, whatever case they arrive in", {
  skip_if_not_installed("sf")
  skip_if_not_installed("hereR")
  skip_if_not_installed("easyr")
  skip_if_not_installed("janitor")
  mock_hereR()

  expect_error(
    mysterymaps_isochrones_for_df(data.frame(x = 1, y = 2), api_key = "k"),
    "must have 'lat' and 'long' columns")

  # janitor::clean_names() runs first, so LAT/LONG is accepted.
  expect_no_error(suppressMessages(
    mysterymaps_isochrones_for_df(data.frame(LAT = 40.1, LONG = -100.1),
                                  breaks = 1800, api_key = "k")))
})

test_that("coordinates outside WGS84 bounds are rejected with a count", {
  # Projected metres passed as degrees is the failure this catches: it produces
  # isochrones somewhere in the Gulf of Guinea rather than an error.
  skip_if_not_installed("sf")
  skip_if_not_installed("hereR")
  skip_if_not_installed("easyr")
  mock_hereR()

  expect_error(
    mysterymaps_isochrones_for_df(data.frame(lat = c(40, 900), long = -100),
                                  api_key = "k"),
    "1 latitude values are outside valid WGS84")
  expect_error(
    mysterymaps_isochrones_for_df(data.frame(lat = 40, long = c(-100, -400)),
                                  api_key = "k"),
    "1 longitude values are outside valid WGS84")
})

test_that("save_interval must be a positive number of seconds", {
  skip_if_not_installed("sf")
  skip_if_not_installed("hereR")
  skip_if_not_installed("easyr")
  mock_hereR()
  for (bad in list(0, -1, NA_real_, "240", c(1, 2))) {
    expect_error(
      mysterymaps_isochrones_for_df(data.frame(lat = 40, long = -100),
                                    api_key = "k", save_interval = bad),
      "save_interval must be a positive number")
  }
})

test_that("an empty input returns an empty data frame, and says so", {
  skip_if_not_installed("sf")
  skip_if_not_installed("hereR")
  skip_if_not_installed("easyr")
  mock_hereR()
  expect_message(
    out <- mysterymaps_isochrones_for_df(
      data.frame(lat = numeric(0), long = numeric(0)),
      breaks = 1800, api_key = "k"),
    "Nothing to process")
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 0L)
})

test_that("each output row carries its band label and origin row index", {
  # Without point_index the dissolved surface cannot be traced back to the
  # provider whose isochrone is missing, which is what the coverage gate needs.
  skip_if_not_installed("sf")
  skip_if_not_installed("hereR")
  skip_if_not_installed("easyr")
  skip_if_not_installed("lwgeom")
  mock_hereR()

  out <- suppressMessages(mysterymaps_isochrones_for_df(
    data.frame(lat = c(40.1, 40.3), long = c(-100.1, -100.3), npi = c(1, 2)),
    breaks = c(1800, 3600), api_key = "k",
    output_dir = withr::local_tempdir()))

  expect_s3_class(out, "sf")
  expect_true(all(c("name", "range", "point_index") %in% names(out)))
  expect_setequal(unique(out$name), c("30 minutes", "60 minutes"))
  expect_setequal(unique(out$point_index), c(1L, 2L))
  # Original columns ride along.
  expect_true("npi" %in% names(out))
})

test_that("a row whose isochrone fails is skipped, not fatal", {
  skip_if_not_installed("sf")
  skip_if_not_installed("hereR")
  skip_if_not_installed("easyr")
  skip_if_not_installed("lwgeom")
  n <- 0L
  mock_hereR(isoline = function(...) {
    n <<- n + 1L
    if (n == 1L) stop("HTTP 500") else fake_isoline(...)
  })
  mysterymaps_clear_isochrone_cache()

  out <- suppressMessages(mysterymaps_isochrones_for_df(
    data.frame(lat = c(40.11, 40.31), long = c(-100.11, -100.31)),
    breaks = 1800, api_key = "skip-key",
    output_dir = withr::local_tempdir()))

  expect_s3_class(out, "sf")
  expect_equal(unique(out$point_index), 2L)
})

test_that("checkpoints are written to output_dir as .rds and .gpkg", {
  # A batch of 12,000 providers takes hours; losing it to a crash at hour three
  # is the reason the checkpoint exists.
  skip_if_not_installed("sf")
  skip_if_not_installed("hereR")
  skip_if_not_installed("easyr")
  skip_if_not_installed("lwgeom")
  mock_hereR()
  out_dir <- withr::local_tempdir()

  suppressMessages(mysterymaps_isochrones_for_df(
    data.frame(lat = 40.12, long = -100.12), breaks = 1800,
    api_key = "ckpt-key", output_dir = out_dir))

  expect_length(list.files(out_dir, pattern = "\\.rds$"), 1L)
  expect_length(list.files(out_dir, pattern = "\\.gpkg$"), 1L)
})


test_that("regression-api-key-is-forwarded-to-the-routing-call", {
  # mysterymaps_isochrones_for_df() validated api_key, passed it to
  # hereR::set_key(), and then called mysterymaps_create_isochrones() without
  # it -- so the inner call fell back to Sys.getenv("HERE_API_KEY"). With no
  # env var the documented argument did nothing.
  skip_if_not_installed("sf")
  skip_if_not_installed("hereR")
  skip_if_not_installed("easyr")
  skip_if_not_installed("lwgeom")

  withr::local_envvar(c(HERE_API_KEY = ""))
  seen <- NULL
  local_mocked_bindings(
    isoline = fake_isoline,
    set_key = function(api_key, ...) { seen <<- api_key; invisible(NULL) },
    set_freemium = function(...) invisible(NULL),
    set_verbose = function(...) invisible(NULL),
    .package = "hereR")
  mysterymaps_clear_isochrone_cache()

  out <- suppressMessages(mysterymaps_isochrones_for_df(
    data.frame(lat = 40.5, long = -100.5), breaks = 1800,
    api_key = "explicit-key-only", output_dir = withr::local_tempdir()))

  expect_s3_class(out, "sf")
  expect_identical(seen, "explicit-key-only")
})
