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

# --------------------------------------------------------------------------
# mm_honeycomb_counts: the per-cell provider count
# --------------------------------------------------------------------------
#
# Split out of mysterymaps_hrr_maps() so it can be asserted at all. The figure
# is a gtable, so a cell silently losing every provider it holds is invisible
# to any test of the output -- which is how the filter below survived.

hex_area <- function(lon = c(-172, -66), lat = c(19, 71)) {
  skip_if_not_installed("sf")
  sf::st_sf(name = "study area", geometry = sf::st_sfc(sf::st_polygon(list(
    cbind(lon[c(1, 2, 2, 1, 1)], lat[c(1, 1, 2, 2, 1)]))), crs = 4326))
}

hex_points <- function(lon, lat) {
  sf::st_as_sf(data.frame(id = seq_along(lon), lon = lon, lat = lat),
               coords = c("lon", "lat"), crs = 4326)
}

test_that("REGRESSION: providers in the westernmost cells are still counted", {
  # The defect this replaced was `dplyr::filter(grid_id > 9546L)`, commented
  # "Filter out Palmyra Atoll". grid_id is row_number() over st_make_grid(),
  # whose cells run in LONGITUDE order across the bounding box -- so the cut
  # deleted the 9,546 westernmost cells whatever was in them. Against the
  # current Natural Earth polygon that is 1,223 land cells including Honolulu,
  # Kauai and Nome, while Palmyra (5.9N) was never in the bbox at all.
  skip_if_not_installed("sf")
  area <- hex_area()

  # Two co-located providers in the far west, two in the far east. Co-located
  # rather than merely nearby: a 0.05-degree gap can straddle a cell boundary,
  # leaving one provider per cell, which min_count then suppresses -- a test
  # failure about the fixture rather than about the filter.
  pts <- hex_points(c(-171.5, -171.5, -67.5, -67.5), c(21.4, 21.4, 44.0, 44.0))

  out <- suppressWarnings(suppressMessages(
    mm_honeycomb_counts(area, pts, cellsize = 0.3)))

  lons <- sf::st_coordinates(suppressWarnings(sf::st_centroid(out)))[, 1]
  expect_true(any(lons < -170))     # the western pair survived
  expect_true(any(lons > -70))      # and so did the eastern
  expect_equal(sum(out$physician_count), 4L)
})

test_that("REGRESSION: cell ordering is longitudinal, which is why an index cut is unsafe", {
  # Pinning the sf property that made the old filter dangerous. If st_make_grid
  # ever ordered by latitude instead, a row-index cut would delete a different
  # band -- equally wrong, differently shaped. Either way it is not geography.
  skip_if_not_installed("sf")
  g <- sf::st_make_grid(hex_area(lon = c(-120, -100), lat = c(30, 40)),
                        c(1, 1), what = "polygons", square = FALSE)
  ctr <- sf::st_coordinates(suppressWarnings(sf::st_centroid(g)))
  first <- ctr[seq_len(20), ]; last <- ctr[seq.int(length(g) - 19, length(g)), ]
  expect_lt(max(first[, 1]), min(last[, 1]))   # first cells are all west of last
})

test_that("an outlying territory is excluded by latitude, not by row number", {
  # The intent the old filter claimed. Expressed as geography it cannot drift
  # when a data release changes the polygon's extent.
  skip_if_not_installed("sf")
  atoll <- sf::st_polygon(list(cbind(c(-162.2, -162.0, -162.0, -162.2, -162.2),
                                     c(5.8, 5.8, 6.0, 6.0, 5.8))))
  mainland <- sf::st_polygon(list(cbind(c(-160.5, -159.0, -159.0, -160.5, -160.5),
                                        c(21.8, 21.8, 22.3, 22.3, 21.8))))
  area <- sf::st_sf(name = "with atoll",
                    geometry = sf::st_sfc(sf::st_multipolygon(list(
                      list(atoll[[1]]), list(mainland[[1]]))), crs = 4326))

  pts <- hex_points(c(-162.1, -162.1, -159.8, -159.8), c(5.9, 5.9, 22.0, 22.0))
  out <- suppressWarnings(suppressMessages(
    mm_honeycomb_counts(area, pts, cellsize = 0.1)))

  lats <- sf::st_coordinates(suppressWarnings(sf::st_centroid(out)))[, 2]
  expect_false(any(lats < 15))       # the atoll's providers are gone
  expect_true(any(lats > 21))        # Kauai's are not
})

test_that("the southern limit sits below every one of the fifty states", {
  # Ka Lae, Hawaii, at 18.91N is the southernmost point of the fifty states.
  # A limit above it would repeat the original defect with a nicer comment.
  expect_lt(formals(mm_honeycomb_counts)$southern_limit, 18.91)
  expect_gt(formals(mm_honeycomb_counts)$southern_limit, 6.0)   # above Palmyra
})

test_that("min_count is a stated suppression threshold, not a rendering detail", {
  # A cell holding one provider is dropped, and drawn exactly like a cell
  # holding none. That is a small-cell suppression decision; pinned so it is a
  # choice someone can see rather than an inequality nobody reads.
  skip_if_not_installed("sf")
  area <- hex_area(lon = c(-105, -100), lat = c(38, 42))
  lone <- hex_points(-102.5, 40.0)

  expect_equal(nrow(suppressWarnings(suppressMessages(
    mm_honeycomb_counts(area, lone, cellsize = 0.5)))), 0L)
  expect_equal(nrow(suppressWarnings(suppressMessages(
    mm_honeycomb_counts(area, lone, cellsize = 0.5, min_count = 1L)))), 1L)
  expect_equal(formals(mm_honeycomb_counts)$min_count, 2L)
})

test_that("cells are clipped to the study area, and providers outside it are not counted", {
  skip_if_not_installed("sf")
  area <- hex_area(lon = c(-105, -100), lat = c(38, 42))
  outside <- hex_points(c(-90, -90), c(40, 40))
  expect_equal(nrow(suppressWarnings(suppressMessages(
    mm_honeycomb_counts(area, outside, cellsize = 0.5)))), 0L)
})

test_that("providers arriving in another CRS are counted in the same cells", {
  skip_if_not_installed("sf")
  area <- hex_area(lon = c(-105, -100), lat = c(38, 42))
  pts <- hex_points(c(-102.5, -102.5, -101.0, -101.0), c(40, 40, 39, 39))

  wgs <- suppressWarnings(suppressMessages(
    mm_honeycomb_counts(area, pts, cellsize = 0.5)))
  alb <- suppressWarnings(suppressMessages(
    mm_honeycomb_counts(area, sf::st_transform(pts, 5070), cellsize = 0.5)))
  expect_equal(sort(wgs$physician_count), sort(alb$physician_count))
  expect_equal(nrow(wgs), nrow(alb))
})

test_that("the count owns its s2 setting and gives it back", {
  # Clipping hexagons to a coastline leaves slivers that s2 rejects, so with
  # spherical geometry on the count does not come out wrong -- it errors. It
  # used to work only because its one caller had switched s2 off a few lines
  # earlier, which made the result a function of the session.
  skip_if_not_installed("sf")
  before <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(before)), add = TRUE)

  area <- hex_area(lon = c(-105, -100), lat = c(38, 42))
  pts <- hex_points(c(-102.5, -102.5), c(40, 40))

  results <- lapply(c(TRUE, FALSE), function(state) {
    suppressMessages(sf::sf_use_s2(state))
    out <- suppressWarnings(suppressMessages(
      mm_honeycomb_counts(area, pts, cellsize = 0.5)))
    c(n = nrow(out), total = sum(out$physician_count),
      restored = sf::sf_use_s2() == state)
  })
  expect_equal(results[[1]], results[[2]])
  expect_true(all(vapply(results, function(r) r[["restored"]] == 1, logical(1))))
})
