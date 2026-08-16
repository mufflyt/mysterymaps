# SPEC section 35 (RNG discipline) and the deduplication half of the
# capability guards.
#
# These two live together because they are the same failure in different
# clothing: an operation whose result depends on something the artifact does
# not record. An unseeded jitter cannot be regenerated; an unverified dedup
# cannot be reconciled. Both produce a map that looks identical either way.

# ---------------------------------------------------------------------------
# RNG discipline
# ---------------------------------------------------------------------------

stub_webshot <- function(env = parent.frame()) {
  skip_if_not_installed("webshot")
  local_mocked_bindings(
    webshot = function(url, file, ...) { file.create(file); invisible(file) },
    .package = "webshot", .env = env)
}

skip_unless_dots <- function() {
  for (p in c("leaflet", "webshot", "viridis", "htmlwidgets", "sf",
              "rnaturalearth", "rnaturalearthdata", "rnaturalearthhires")) {
    skip_if_not_installed(p)
  }
  # These draw a dot map, which draws ACOG districts, which reads the table
  # packaged inside mysterycall. Absent on a runner that resolved mysterycall
  # without its extdata.
  skip_if_no_acog_csv()
}

physicians <- function(n = 5) {
  data.frame(
    long = seq(-105, -101, length.out = n),
    lat  = seq(39, 41, length.out = n),
    name = paste("Physician", seq_len(n)),
    ACOG_District = rep(c("District VIII", "District IX"), length.out = n),
    stringsAsFactors = FALSE)
}

marker_coords <- function(m) {
  a <- mm_call_args(m, "addCircleMarkers")
  list(lat = unlist(a[[1]]), lng = unlist(a[[2]]))
}

test_that("the same seed reproduces the same jittered map exactly", {
  # A published dot map moves every provider by up to jitter_range degrees.
  # If that displacement cannot be replayed, the figure cannot be regenerated
  # and "why is this provider here" has no answer.
  skip_unless_dots()
  stub_webshot()
  out <- withr::local_tempdir()

  a <- suppressWarnings(suppressMessages(
    mysterymaps_map_physicians(physicians(), output_dir = out, seed = 42)))
  b <- suppressWarnings(suppressMessages(
    mysterymaps_map_physicians(physicians(), output_dir = out, seed = 42)))

  expect_equal(marker_coords(a), marker_coords(b))
})

test_that("different seeds produce different jitter", {
  # The complement: a seed that changes nothing is not a seed.
  skip_unless_dots()
  stub_webshot()
  out <- withr::local_tempdir()

  a <- suppressWarnings(suppressMessages(
    mysterymaps_map_physicians(physicians(), output_dir = out, seed = 1)))
  b <- suppressWarnings(suppressMessages(
    mysterymaps_map_physicians(physicians(), output_dir = out, seed = 2)))

  expect_false(isTRUE(all.equal(marker_coords(a), marker_coords(b))))
})

test_that("the seed used is recorded on the returned object", {
  # Provenance the package is responsible for: the artifact says how it was
  # made, rather than the caller having to remember.
  skip_unless_dots()
  stub_webshot()
  m <- suppressWarnings(suppressMessages(
    mysterymaps_map_physicians(physicians(), output_dir = withr::local_tempdir(),
                               seed = 99)))
  expect_equal(attr(m, "mysterymaps_seed"), 99)
})

test_that("REGRESSION: seeding a map does not reseed the caller's stream", {
  # set.seed() without restoration would make drawing a map silently reseed
  # every simulation that ran after it in the same script.
  skip_unless_dots()
  stub_webshot()
  out <- withr::local_tempdir()

  set.seed(7)
  before <- .Random.seed
  expected <- runif(3)

  set.seed(7)
  suppressWarnings(suppressMessages(
    mysterymaps_map_physicians(physicians(), output_dir = out, seed = 12345)))
  after_map <- runif(3)

  expect_equal(after_map, expected)
  set.seed(7)
  expect_equal(.Random.seed, before)
})

test_that("an invalid seed is rejected rather than silently ignored", {
  skip_unless_dots()
  stub_webshot()
  out <- withr::local_tempdir()
  for (bad in list("42", c(1, 2), NA_real_)) {
    expect_error(
      suppressWarnings(suppressMessages(
        mysterymaps_map_physicians(physicians(), output_dir = out, seed = bad))),
      "single number or NULL")
  }
})

test_that("jitter_range = 0 makes the map deterministic without a seed", {
  # The escape hatch for anyone who would rather have no randomness at all.
  skip_unless_dots()
  stub_webshot()
  out <- withr::local_tempdir()
  a <- suppressWarnings(suppressMessages(
    mysterymaps_map_physicians(physicians(), jitter_range = 0, output_dir = out)))
  b <- suppressWarnings(suppressMessages(
    mysterymaps_map_physicians(physicians(), jitter_range = 0, output_dir = out)))
  expect_equal(marker_coords(a), marker_coords(b))
})

# ---------------------------------------------------------------------------
# Deduplication conservation
# ---------------------------------------------------------------------------
#
# mysterymaps_geocode() deduplicates addresses before calling the API and joins
# the coordinates back afterwards. That is the one place in this package where
# a count is deliberately reduced, so it needs the conservation identity:
#
#   rows out == rows in
#   unique addresses geocoded <= rows in
#   every input row receives the coordinate of its own address

mock_ggmap <- function(geocode, env = parent.frame()) {
  skip_if_not_installed("ggmap")
  local_mocked_bindings(
    geocode = geocode, register_google = function(...) invisible(NULL),
    .package = "ggmap", .env = env)
}

write_csv_addr <- function(dir, addresses) {
  path <- file.path(dir, "addr.csv")
  utils::write.csv(
    data.frame(address = addresses, id = seq_along(addresses),
               stringsAsFactors = FALSE),
    path, row.names = FALSE)
  path
}

test_that("deduplication never changes the number of rows returned", {
  # The conservation identity. Deduplication is an optimisation on the API
  # call, not on the dataset; losing a row here loses a provider.
  skip_if_not_installed("ggmap")
  mock_ggmap(function(x, ...) data.frame(lat = rep(40, length(x)),
                                         lon = rep(-100, length(x))))
  dir <- withr::local_tempdir()

  for (addr in list(
        rep("1 A St", 5),                       # all duplicates
        c("1 A St", "2 B Ave", "3 C Rd"),       # all distinct
        c("1 A St", "1 A St", "2 B Ave"))) {    # mixed
    path <- write_csv_addr(dir, addr)
    out <- suppressMessages(mysterymaps_geocode(path, "key"))
    expect_equal(nrow(out), length(addr), info = paste(addr, collapse = "|"))
  }
})

test_that("the geocoder is called once per UNIQUE address, not once per row", {
  # If dedup silently stopped working the map would be identical and the bill
  # would not be. This is the only observable difference.
  skip_if_not_installed("ggmap")
  seen <- NULL
  mock_ggmap(function(x, ...) {
    seen <<- x
    data.frame(lat = rep(40, length(x)), lon = rep(-100, length(x)))
  })
  dir <- withr::local_tempdir()
  path <- write_csv_addr(dir, c("1 A St", "1 A St", "1 A St", "2 B Ave"))

  suppressMessages(mysterymaps_geocode(path, "key"))
  expect_length(seen, 2L)
  expect_setequal(seen, c("1 A St", "2 B Ave"))
})

test_that("duplicate injection does not change any provider's coordinate", {
  # Duplicating rows must change row count and nothing else -- the metamorphic
  # form of the same identity.
  skip_if_not_installed("ggmap")
  coords <- c("1 A St" = 40, "2 B Ave" = 41)
  mock_ggmap(function(x, ...) data.frame(lat = unname(coords[x]),
                                         lon = -unname(coords[x])))
  dir <- withr::local_tempdir()

  base <- suppressMessages(mysterymaps_geocode(
    write_csv_addr(dir, c("1 A St", "2 B Ave")), "key"))
  dupes <- suppressMessages(mysterymaps_geocode(
    write_csv_addr(dir, c("1 A St", "2 B Ave", "1 A St", "2 B Ave")), "key"))

  expect_equal(nrow(dupes), 4L)
  for (a in c("1 A St", "2 B Ave")) {
    expect_setequal(unique(dupes$latitude[dupes$address == a]),
                    unique(base$latitude[base$address == a]))
  }
})

test_that("each row receives the coordinate of its OWN address", {
  # The mis-join this dedup could produce: every row gets row 1's coordinate.
  skip_if_not_installed("ggmap")
  coords <- c("1 A St" = 40, "2 B Ave" = 41, "3 C Rd" = 42)
  mock_ggmap(function(x, ...) data.frame(lat = unname(coords[x]),
                                         lon = -unname(coords[x])))
  dir <- withr::local_tempdir()
  addr <- c("3 C Rd", "1 A St", "2 B Ave", "1 A St")
  out <- suppressMessages(mysterymaps_geocode(write_csv_addr(dir, addr), "key"))

  expect_equal(out$latitude, unname(coords[addr]))
})
