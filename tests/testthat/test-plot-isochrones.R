# Per-drive-time isochrone maps and shapefiles. The function is a loop that
# writes files, so what is tested is what lands on disk and what happens to the
# rows that should not produce a file at all.

skip_unless_plot <- function() {
  skip_if_not_installed("sf")
  skip_if_not_installed("leaflet")
  skip_if_not_installed("htmlwidgets")
}

iso_for_plot <- function(drive_time = c(30, 60)) {
  iso <- mm_isochrones(drive_time = drive_time)
  iso
}

test_that("one HTML map and one shapefile are written per drive time", {
  skip_unless_plot()
  out <- withr::local_tempdir()
  suppressMessages(
    mysterymaps_plot_isochrones(iso_for_plot(), c(30, 60), output_dir = out))

  maps <- list.files(file.path(out, "isochrone_maps"), pattern = "\\.html$")
  shps <- list.files(file.path(out, "shp"), pattern = "\\.shp$")
  expect_setequal(maps, c("isochrone_map_30_minutes.html",
                          "isochrone_map_60_minutes.html"))
  expect_setequal(shps, c("isochrones_30_minutes.shp",
                          "isochrones_60_minutes.shp"))
})

test_that("an NA drive time is skipped with a message, not written as 'NA'", {
  # unique(isochrones$drive_time) picks up NA whenever one row failed, and
  # "isochrone_map_NA_minutes.html" is not a file anyone wants.
  skip_unless_plot()
  out <- withr::local_tempdir()
  expect_message(
    mysterymaps_plot_isochrones(iso_for_plot(), c(30, NA), output_dir = out),
    "Skipping NA drive time")

  expect_false(any(grepl("NA", list.files(file.path(out, "isochrone_maps")))))
})

test_that("the written shapefile is in EPSG:4326", {
  skip_unless_plot()
  out <- withr::local_tempdir()
  suppressMessages(
    mysterymaps_plot_isochrones(iso_for_plot(30), 30, output_dir = out))
  shp <- sf::st_read(file.path(out, "shp", "isochrones_30_minutes.shp"),
                     quiet = TRUE)
  expect_equal(sf::st_crs(shp)$epsg, 4326L)
})

test_that("isochrones for one drive time are dissolved into a single feature", {
  # The map answers "is this ground covered?", so overlapping per-provider
  # polygons must become one surface rather than a stack of translucent ones.
  skip_unless_plot()
  out <- withr::local_tempdir()
  overlapping <- mm_isochrones(drive_time = c(30, 30))
  suppressMessages(
    mysterymaps_plot_isochrones(overlapping, 30, output_dir = out))
  shp <- sf::st_read(file.path(out, "shp", "isochrones_30_minutes.shp"),
                     quiet = TRUE)
  expect_equal(nrow(shp), 1L)
})

test_that("output directories are created when they do not exist", {
  skip_unless_plot()
  out <- file.path(withr::local_tempdir(), "deep", "nested")
  suppressMessages(
    mysterymaps_plot_isochrones(iso_for_plot(30), 30, output_dir = out))
  expect_true(dir.exists(file.path(out, "isochrone_maps")))
  expect_true(dir.exists(file.path(out, "shp")))
})

test_that("each required package is named in its own error", {
  for (pkg in c("sf", "leaflet", "htmlwidgets")) {
    local_mocked_bindings(
      requireNamespace = function(package, ...) !identical(package, pkg),
      .package = "base")
    expect_error(mysterymaps_plot_isochrones(iso_for_plot(), 30),
                 sprintf("'%s' is required", pkg))
  }
})
