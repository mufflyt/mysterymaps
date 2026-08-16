# mysterymaps_calculate_overlap() measures how much of each block group falls
# inside a drive-time surface. Almost every guard in it exists to stop a number
# that LOOKS right from being produced: an unprojected area, a 2010 block group
# measured against a 2020 provider roster, an intersection missing the join key.

skip_unless_spatial <- function() {
  skip_if_not_installed("sf")
}

test_that("non-sf arguments are rejected by name", {
  skip_unless_spatial()
  expect_error(
    mysterymaps_calculate_overlap(data.frame(a = 1), mm_isochrones(), 30,
                                  tempfile()),
    "'block_groups' must be an sf object")
  expect_error(
    mysterymaps_calculate_overlap(mm_block_groups(), data.frame(a = 1), 30,
                                  tempfile()),
    "'isochrones_joined' must be an sf object")
})

test_that("drive_time_minutes must be a single non-negative number", {
  skip_unless_spatial()
  for (bad in list("30", c(30, 60), -1, numeric(0))) {
    expect_error(
      mysterymaps_calculate_overlap(mm_block_groups(), mm_isochrones(), bad,
                                    tempfile()),
      "single non-negative numeric")
  }
})

test_that("output_dir must be a non-empty string", {
  skip_unless_spatial()
  expect_error(
    mysterymaps_calculate_overlap(mm_block_groups(), mm_isochrones(), 30, ""),
    "non-empty character string")
})

test_that("crosswalk must be a function when supplied", {
  skip_unless_spatial()
  expect_error(
    mysterymaps_calculate_overlap(mm_block_groups(), mm_isochrones(), 30,
                                  tempfile(), crosswalk = "nope"),
    "must be a function or NULL")
})

test_that("a missing data_year or vintage column is refused", {
  # Without a vintage on both sides there is no way to know the geographies
  # even describe the same country in the same decade.
  skip_unless_spatial()
  iso <- mm_isochrones()
  iso$data_year <- NULL
  expect_error(
    mysterymaps_calculate_overlap(mm_block_groups(), iso, 30, tempfile()),
    "must include a `data_year` column")

  bg <- mm_block_groups()
  bg$vintage <- NULL
  expect_error(
    mysterymaps_calculate_overlap(bg, mm_isochrones(), 30, tempfile()),
    "must include a `vintage` column")
})

test_that("mixed vintages within one input are refused", {
  skip_unless_spatial()
  iso <- mm_isochrones(drive_time = c(30, 60))
  iso$data_year <- c(2019, 2020)
  expect_error(
    mysterymaps_calculate_overlap(mm_block_groups(), iso, 30, tempfile()),
    "single, non-missing year")
})

test_that("mismatched vintages that are not 2010/2020 are a hard error", {
  # A crosswalk exists between the 2010 and 2020 definitions. Between 2019 and
  # 2020 there is nothing to cross-walk; the caller has simply mixed data.
  skip_unless_spatial()
  expect_error(
    mysterymaps_calculate_overlap(mm_block_groups(vintage = 2019),
                                  mm_isochrones(data_year = 2020), 30,
                                  tempfile()),
    "Provide matching vintages")
})

test_that("a 2010/2020 mismatch names the crosswalk as the remedy", {
  skip_unless_spatial()
  expect_error(
    mysterymaps_calculate_overlap(mm_block_groups(vintage = 2010),
                                  mm_isochrones(data_year = 2020), 30,
                                  tempfile()),
    "Supply a `crosswalk` function")
})

test_that("a crosswalk returning the wrong thing is caught, not trusted", {
  skip_unless_spatial()
  args <- list(mm_block_groups(vintage = 2010), mm_isochrones(data_year = 2020),
               30, tempfile())

  expect_error(
    do.call(mysterymaps_calculate_overlap,
            c(args, list(crosswalk = function(x, years) data.frame(a = 1)))),
    "must return an sf object")

  expect_error(
    do.call(mysterymaps_calculate_overlap,
            c(args, list(crosswalk = function(x, years) {
              x$vintage <- NULL; x
            }))),
    "must include a `vintage` column")

  # Returns sf with a vintage, but still the wrong one.
  expect_error(
    do.call(mysterymaps_calculate_overlap,
            c(args, list(crosswalk = function(x, years) {
              x$vintage <- 2015; x
            }))),
    "did not return ACS data aligned")
})

test_that("a drive time with no isochrones lists the ones that do exist", {
  # "No isochrones found" alone sends the caller back to inspect the data by
  # hand; naming the available values ends the question immediately.
  skip_unless_spatial()
  expect_error(
    mysterymaps_calculate_overlap(mm_block_groups(),
                                  mm_isochrones(drive_time = c(30, 60)),
                                  45, tempfile()),
    "Available drive_time values: 30, 60")
})

test_that("block groups without a GEOID are refused before the join", {
  skip_unless_spatial()
  bg <- mm_block_groups()
  bg$GEOID <- NULL
  expect_error(
    suppressMessages(
      mysterymaps_calculate_overlap(bg, mm_isochrones(), 30, tempfile())),
    "GEOID")
})

test_that("a full run writes a shapefile and reports overlap percentiles", {
  skip_unless_spatial()
  out <- withr::local_tempdir()

  msgs <- capture_messages(
    suppressWarnings(
      mysterymaps_calculate_overlap(mm_block_groups(), mm_isochrones(), 30, out)))

  expect_true(file.exists(file.path(out, "intersect_30_minutes.shp")))
  expect_match(paste(msgs, collapse = ""), "50th Percentile")
  expect_match(paste(msgs, collapse = ""), "75th Percentile")
})

test_that("REGRESSION: areas are measured in an equal-area projection", {
  # Measuring in degrees makes a Texas block group and a North Dakota one of
  # the same shape differ by ~30% in area, which biases every coverage figure
  # by latitude. EPSG:5070 is recorded in the output so the choice is auditable.
  skip_unless_spatial()
  out <- withr::local_tempdir()
  suppressWarnings(suppressMessages(
    mysterymaps_calculate_overlap(mm_block_groups(), mm_isochrones(), 30, out)))

  # Read the CSV rather than the shapefile: the shapefile format truncates
  # field names to ten characters, so `area_method` arrives as `ar_mthd`.
  tbl <- utils::read.csv(file.path(out, "intersect_30_minutes.csv"))
  expect_true("area_method" %in% names(tbl))
  expect_true(all(tbl$area_method == "projected:EPSG:5070"))
  expect_true(all(tbl$intersect_area > 0))
})

test_that("the written shapefile comes back in EPSG:4326", {
  # Shapefiles are handed on to web maps, which want WGS84 whatever the
  # measurement CRS was.
  skip_unless_spatial()
  out <- withr::local_tempdir()
  suppressWarnings(suppressMessages(
    mysterymaps_calculate_overlap(mm_block_groups(), mm_isochrones(), 30, out)))
  shp <- sf::st_read(file.path(out, "intersect_30_minutes.shp"), quiet = TRUE)
  expect_equal(sf::st_crs(shp)$epsg, 4326L)
})

test_that("inputs that cannot overlap are refused before any number is produced", {
  # A coverage figure of 0% reads as a finding. It is far more often two
  # datasets that do not describe the same place, so this fails at the gate
  # rather than reporting the zero.
  skip_unless_spatial()
  far <- mm_isochrones()
  sf::st_geometry(far) <- sf::st_sfc(
    sf::st_polygon(list(cbind(c(10, 11, 11, 10, 10), c(10, 10, 11, 11, 10)))),
    sf::st_polygon(list(cbind(c(11, 12, 12, 11, 11), c(10, 10, 11, 11, 10)))),
    crs = 4326)
  out <- withr::local_tempdir()

  expect_error(
    suppressMessages(
      mysterymaps_calculate_overlap(mm_block_groups(), far, 30, out)),
    "do not overlap")
})

test_that("the documented CSV of GEOID, area and method is actually written", {
  skip_unless_spatial()
  out <- withr::local_tempdir()
  suppressWarnings(suppressMessages(
    mysterymaps_calculate_overlap(mm_block_groups(), mm_isochrones(), 30, out)))

  csv <- file.path(out, "intersect_30_minutes.csv")
  expect_true(file.exists(csv))
  expect_named(utils::read.csv(csv),
               c("GEOID", "intersect_area", "area_method"))
})

test_that("a valid crosswalk is used and the run completes", {
  skip_unless_spatial()
  out <- withr::local_tempdir()
  crosswalk <- function(bg, years) {
    expect_equal(years$from, 2010)
    expect_equal(years$to, 2020)
    bg$vintage <- years$to
    bg
  }
  expect_no_error(
    suppressWarnings(suppressMessages(
      mysterymaps_calculate_overlap(mm_block_groups(vintage = 2010),
                                    mm_isochrones(data_year = 2020), 30, out,
                                    crosswalk = crosswalk))))
})
