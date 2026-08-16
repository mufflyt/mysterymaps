# Named scientific regressions.
#
# Every defect found while building this validation system gets its own named
# test here rather than being folded into a generic suite. The names are the
# contract: when one of these goes red, the failure line alone says which
# specific scientific error has returned.
#
#   regression-invalid-s2-geometry
#   regression-non-sf-class-before-crs
#   regression-overlap-csv-is-written
#   regression-area-method-not-truncated-in-canonical-output
#   regression-geoid-survives-csv-round-trip
#   regression-s2-state-restored-on-success
#   regression-s2-state-restored-on-error
#   regression-mapproj-fails-early
#   regression-map-actually-renders
#   regression-na-is-not-observed-zero
#   regression-jenks-single-positive-value
#   regression-jenks-na-does-not-abort

skip_no_sf <- function() skip_if_not_installed("sf")

# ---------------------------------------------------------------------------
test_that("regression-invalid-s2-geometry", {
  # s2 declines to repair a self-intersecting ring that the planar algorithm
  # splits cleanly into a MULTIPOLYGON. A self-intersecting ring is exactly
  # what a drive-time routing API returns, so before the planar fallback the
  # package rejected ordinary production geometry.
  skip_no_sf()
  bowtie <- sf::st_sf(id = 1L, geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(0, 2, 0, 2, 0), c(0, 0, 2, 2, 0)))), crs = 4326))

  expect_false(all(sf::st_is_valid(bowtie)))
  expect_false(all(sf::st_is_valid(sf::st_make_valid(bowtie))))   # s2 path alone

  out <- validate_sf_inputs(shape = bowtie)$shape
  expect_true(all(sf::st_is_valid(out)))
  expect_gt(as.numeric(sum(sf::st_area(sf::st_transform(out, 5070)))), 0)
})

test_that("regression-non-sf-class-before-crs", {
  # Passing a plain data.frame is the commonest caller mistake. It used to
  # report "Reference CRS is missing" -- an accurate statement about the wrong
  # problem, which sends the caller to inspect a CRS that was never there.
  skip_no_sf()
  err <- tryCatch(validate_sf_inputs(counties = data.frame(a = 1)),
                  error = function(e) conditionMessage(e))
  expect_match(err, "must be an sf object")
  expect_false(grepl("Reference CRS is missing", err))
})

# ---------------------------------------------------------------------------
test_that("regression-overlap-csv-is-written", {
  # The documented CSV side effect did not happen. A downstream script
  # globbing for it found nothing and silently processed zero rows.
  skip_no_sf()
  out <- withr::local_tempdir()
  suppressWarnings(suppressMessages(
    mysterymaps_calculate_overlap(mm_block_groups(4), mm_isochrones(), 30, out)))

  csv <- file.path(out, "intersect_30_minutes.csv")
  expect_true(file.exists(csv))
  expect_gt(file.size(csv), 0)
})

test_that("regression-area-method-not-truncated-in-canonical-output", {
  # ESRI shapefiles truncate field names to ten characters: `area_method`
  # arrives as `ar_mthd` and `intersect_area` as `intrsc_`. The CSV is the
  # canonical tabular record precisely because it does not do that.
  skip_no_sf()
  out <- withr::local_tempdir()
  suppressWarnings(suppressMessages(
    mysterymaps_calculate_overlap(mm_block_groups(4), mm_isochrones(), 30, out)))

  tbl <- utils::read.csv(file.path(out, "intersect_30_minutes.csv"),
                         colClasses = c(GEOID = "character"))
  expect_named(tbl, c("GEOID", "intersect_area", "area_method"))
  expect_true(all(tbl$area_method == "projected:EPSG:5070"))

  # And prove the shapefile really does truncate, so this test keeps its point.
  shp <- sf::st_read(file.path(out, "intersect_30_minutes.shp"), quiet = TRUE)
  expect_false("area_method" %in% names(shp))
})

test_that("regression-geoid-survives-csv-round-trip", {
  # utils::read.csv() converts the quoted "080010001" to the integer 80010001,
  # turning Colorado's state FIPS 08 into 8. Every downstream join then misses,
  # the county comes back NA, and an NA county on a rare-subspecialty map is
  # indistinguishable from a measured zero.
  skip_no_sf()
  out <- withr::local_tempdir()
  bg <- mm_block_groups(4)
  suppressWarnings(suppressMessages(
    mysterymaps_calculate_overlap(bg, mm_isochrones(), 30, out)))

  csv <- file.path(out, "intersect_30_minutes.csv")

  # The naive read is lossy -- that is the hazard being guarded, so pin it.
  naive <- utils::read.csv(csv)
  expect_false(is.character(naive$GEOID))

  # The documented read round-trips exactly.
  ok <- utils::read.csv(csv, colClasses = c(GEOID = "character"))
  expect_type(ok$GEOID, "character")
  expect_true(all(nchar(ok$GEOID) == nchar(bg$GEOID[1])))
  expect_true(all(ok$GEOID %in% bg$GEOID))
  expect_true(all(startsWith(ok$GEOID, "0")))

  # And the artifact declares its own types for GDAL/OGR readers.
  csvt <- paste0(tools::file_path_sans_ext(csv), ".csvt")
  expect_true(file.exists(csvt))
  expect_match(readLines(csvt, warn = FALSE)[1], "String")
})

# ---------------------------------------------------------------------------
test_that("regression-s2-state-restored-on-success", {
  # mysterymaps_hrr_maps() turned spherical geometry off and left it off,
  # silently changing the result of every sf call the caller made next.
  skip_no_sf()
  before <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(before)), add = TRUE)

  for (start in c(TRUE, FALSE)) {
    suppressMessages(sf::sf_use_s2(start))
    suppressMessages(mysterymaps_gate_provider_coverage(
      mm_points(3), mm_surface(x = -101, y = 39, w = 6, h = 4)))
    expect_equal(sf::sf_use_s2(), start,
                 info = sprintf("entered with s2 = %s", start))
  }
})

test_that("regression-s2-state-restored-on-error", {
  # Restoration must survive the failure path too, or a single rejected batch
  # leaves the whole session measuring on the plane without saying so.
  skip_no_sf()
  before <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(before)), add = TRUE)

  for (start in c(TRUE, FALSE)) {
    suppressMessages(sf::sf_use_s2(start))
    # A provider outside their own surface is an error by design.
    expect_error(suppressMessages(mysterymaps_gate_provider_coverage(
      mm_points(3, lon = c(-99, -98, 40), lat = c(40.2, 40.4, -100)),
      mm_surface(x = -99.5, y = 40, w = 2, h = 1))))
    expect_equal(sf::sf_use_s2(), start,
                 info = sprintf("errored with s2 = %s", start))
  }
})

# ---------------------------------------------------------------------------
test_that("regression-mapproj-fails-early", {
  # coord_map() resolves mapproj at RENDER time. Without the guard the
  # function returned a healthy-looking ggplot and the failure surfaced later,
  # inside someone else's ggsave(), naming ggplot2 rather than this package.
  local_mocked_bindings(
    requireNamespace = function(package, ...) !identical(package, "mapproj"),
    .package = "base")
  expect_error(
    mysterymaps_geographic_map(data.frame(state = "CO", offered = 1)),
    "mapproj")
  expect_error(
    mysterymaps_map_acceptance_rate(data.frame(state = "Colorado", rate = 0.5),
                                    "state", "rate"),
    "mapproj")
})

test_that("regression-map-actually-renders", {
  # A ggplot object that constructs is not a map. Both choropleths must
  # survive the full build-and-write path, which is where coord_map(),
  # the viridis scale and the projection are actually exercised.
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("maps")
  skip_if_not_installed("mapproj")
  dir <- withr::local_tempdir()

  p1 <- suppressWarnings(mysterymaps_geographic_map(
    data.frame(state = c("CO", "CA", "TX"), offered = c(1, 0, 1))))
  f1 <- file.path(dir, "geographic.png")
  ggplot2::ggsave(f1, p1, width = 5, height = 4, dpi = 72)
  expect_gt(file.size(f1), 0)

  p2 <- mysterymaps_map_acceptance_rate(
    data.frame(state = c("Colorado", "California"), rate = c(0.55, 0.72)),
    "state", "rate")
  f2 <- file.path(dir, "acceptance.png")
  ggplot2::ggsave(f2, p2, width = 5, height = 4, dpi = 72)
  expect_gt(file.size(f2), 0)
})

# ---------------------------------------------------------------------------
test_that("regression-na-is-not-observed-zero", {
  # The scale coloured NA and 0 identically and labelled that colour "0",
  # asserting "no providers here" for a county that was never measured.
  sc <- mysterymaps_jenks_zero_scale(c(0, NA, 1, 4, 9, 30))
  expect_false(identical(sc$color(NA_real_), sc$color(0)))
  na_idx <- which(sc$leg_cols == sc$color(NA_real_))
  expect_false(sc$leg_labs[[na_idx]] == "0")
})

test_that("regression-jenks-single-positive-value", {
  # classIntervals(style = "jenks") errors on a single unique value. One
  # county with a nonzero count is an ordinary rare-subspecialty map.
  expect_no_error(mysterymaps_jenks_zero_scale(c(0, 0, 7)))
  sc <- mysterymaps_jenks_zero_scale(c(0, 0, 7))
  expect_identical(sc$color(7), sc$leg_cols[[2]])
})

test_that("regression-jenks-na-does-not-abort", {
  # n[n > 0] keeps NA, which reached `if (min(v) == max(v))` and raised
  # "missing value where TRUE/FALSE needed", taking the whole map with it.
  expect_no_error(mysterymaps_jenks_zero_scale(c(0, 1, 2, 5, 9, 40, NA), k = 3))
  sc <- mysterymaps_jenks_zero_scale(c(0, 1, 2, 5, 9, 40, NA), k = 3)
  expect_false(anyNA(sc$color(c(0, 1, 2, 5, 9, 40, NA))))
})
