# Hospital Referral Regions. mysterymaps_hrr() downloads an 8 MB shapefile from
# the Dartmouth Atlas on first use, so the download itself is stubbed: what is
# tested is the transform, the AK/HI filter, and the guards -- not Dartmouth's
# uptime.

fake_hrr_sf <- function() {
  skip_if_not_installed("sf")
  cities <- c("CO-Denver", "CA-Sacramento", "AK-Anchorage", "HI-Honolulu",
              "PR-San Juan")
  geoms <- lapply(seq_along(cities), function(i) {
    x <- -110 + i
    sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x),
                              c(35, 35, 36, 36, 35))))
  })
  # Deliberately NOT 4326: mysterymaps_hrr() must transform it.
  sf::st_transform(
    sf::st_sf(hrrcity = cities, hrrnum = seq_along(cities),
              geometry = sf::st_sfc(geoms, crs = 4326)),
    5070)
}

# Stub the download+unzip step by writing the fixture to a real shapefile and
# handing back its path.
local_stub_hrr_shapefile <- function(env = parent.frame()) {
  skip_if_not_installed("sf")
  dir <- withr::local_tempdir(.local_envir = env)
  path <- file.path(dir, "hrr.shp")
  suppressWarnings(sf::st_write(fake_hrr_sf(), path, quiet = TRUE))
  local_mocked_bindings(ensure_hrr_shapefile = function(...) path,
                        .env = env)
  path
}

test_that("the shapefile is returned in EPSG:4326 whatever it was stored in", {
  # Everything downstream -- leaflet, the honeycomb grid, st_filter against
  # physician points -- assumes WGS84.
  skip_if_not_installed("sf")
  local_stub_hrr_shapefile()
  hrr <- suppressMessages(mysterymaps_hrr())
  expect_equal(sf::st_crs(hrr)$epsg, 4326L)
})

test_that("Alaska and Hawaii are dropped by default", {
  skip_if_not_installed("sf")
  local_stub_hrr_shapefile()
  hrr <- suppressMessages(mysterymaps_hrr())
  expect_false(any(grepl("^(AK|HI)", hrr$hrrcity)))
  # Puerto Rico is NOT part of the AK/HI filter and must survive it.
  expect_true(any(grepl("^PR-", hrr$hrrcity)))
})

test_that("remove_HI_AK = FALSE keeps every HRR for the inset maps", {
  skip_if_not_installed("sf")
  local_stub_hrr_shapefile()
  hrr <- suppressMessages(mysterymaps_hrr(remove_HI_AK = FALSE))
  expect_equal(nrow(hrr), 5L)
  expect_true(any(grepl("^AK-", hrr$hrrcity)))
  expect_true(any(grepl("^HI-", hrr$hrrcity)))
})

test_that("the filter matches a PREFIX, not a substring", {
  # "^(AK|HI)" rather than "AK|HI": an HRR whose city merely contains those
  # letters -- "MI-Saginaw" does not, but "OH-Akron" does -- must survive.
  skip_if_not_installed("sf")
  dir <- withr::local_tempdir()
  path <- file.path(dir, "hrr.shp")
  sf_obj <- fake_hrr_sf()
  sf_obj$hrrcity <- c("OH-Akron", "CA-Sacramento", "AK-Anchorage",
                      "HI-Honolulu", "PR-San Juan")
  suppressWarnings(sf::st_write(sf_obj, path, quiet = TRUE))
  local_mocked_bindings(ensure_hrr_shapefile = function(...) path)

  hrr <- suppressMessages(mysterymaps_hrr())
  expect_true("OH-Akron" %in% hrr$hrrcity)
})

test_that("sf is named in the error when it is not installed", {
  local_mocked_bindings(
    requireNamespace = function(package, ...) !identical(package, "sf"),
    .package = "base")
  expect_error(mysterymaps_hrr(), "'sf' is required")
})

test_that("each package mysterymaps_hrr_maps needs is named in its own error", {
  for (pkg in c("sf", "scales", "ggspatial", "rnaturalearth", "gridExtra",
                "ggplot2")) {
    local_mocked_bindings(
      requireNamespace = function(package, ...) !identical(package, pkg),
      .package = "base")
    expect_error(mysterymaps_hrr_maps(mm_points()),
                 sprintf("'%s' is required", pkg))
  }
})

# --------------------------------------------------------------------------
# mysterymaps_hrr_maps: the honeycomb figure
# --------------------------------------------------------------------------
#
# The real ne_countries() USA spans the dateline, which at 0.3-degree hex
# spacing makes a grid of a quarter of a million cells and a test that takes
# minutes. A stubbed rectangle large enough to clear the hard-coded
# `grid_id > 9546` cut exercises the same code path in seconds.

stub_usa <- function(env = parent.frame()) {
  skip_if_not_installed("sf")
  skip_if_not_installed("rnaturalearth")
  usa <- sf::st_sf(
    name = "United States of America",
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(-115, -80, -80, -115, -115),
                                c(28, 28, 50, 50, 28)))),
      crs = 4326))
  local_mocked_bindings(ne_countries = function(...) usa,
                        .package = "rnaturalearth", .env = env)
  usa
}

test_that("the honeycomb figure is built and written as both TIFF and PNG", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("ggspatial")
  skip_if_not_installed("gridExtra")
  skip_if_not_installed("scales")
  skip_if_not_installed("rnaturalearth")

  stub_usa()
  local_stub_hrr_shapefile()
  out <- withr::local_tempdir()

  grob <- suppressWarnings(suppressMessages(
    mysterymaps_hrr_maps(mm_points(6, lon = seq(-110, -85, length.out = 6),
                                   lat = seq(30, 48, length.out = 6)),
                         trait_map = "obgyn", honey_map = "all",
                         output_dir = out, dpi = 72, width = 5, height = 4)))

  expect_true(file.exists(file.path(out, "obgyn_all_honey.tiff")))
  expect_true(file.exists(file.path(out, "obgyn_all_honey.png")))
  expect_s3_class(grob, "gtable")
})

test_that("trait_map and honey_map name the output files", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("ggspatial")
  skip_if_not_installed("gridExtra")
  skip_if_not_installed("rnaturalearth")

  stub_usa()
  local_stub_hrr_shapefile()
  out <- withr::local_tempdir()

  suppressWarnings(suppressMessages(
    mysterymaps_hrr_maps(mm_points(4, lon = seq(-108, -90, length.out = 4),
                                   lat = seq(32, 46, length.out = 4)),
                         trait_map = "neurotology", honey_map = "subset",
                         output_dir = out, dpi = 72, width = 4, height = 3)))

  expect_setequal(list.files(out),
                  c("neurotology_subset_honey.tiff",
                    "neurotology_subset_honey.png"))
})

test_that("REGRESSION: s2 is restored after the map is built", {
  # mysterymaps_hrr_maps() turns spherical geometry off to make the grid
  # intersection tractable. Leaving it off silently changes the result of every
  # subsequent sf operation in the session.
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("ggspatial")
  skip_if_not_installed("gridExtra")
  skip_if_not_installed("rnaturalearth")

  stub_usa()
  local_stub_hrr_shapefile()

  # Set it explicitly rather than reading whatever the previous test left
  # behind: an earlier mysterymaps_hrr_maps() call in this same file turns s2
  # off, and a test that starts from FALSE passes without checking anything.
  before <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(before)), add = TRUE)
  suppressMessages(sf::sf_use_s2(TRUE))

  suppressWarnings(suppressMessages(
    mysterymaps_hrr_maps(mm_points(3, lon = c(-105, -95, -88),
                                   lat = c(35, 40, 45)),
                         output_dir = withr::local_tempdir(),
                         dpi = 72, width = 4, height = 3)))

  expect_true(sf::sf_use_s2())
})
