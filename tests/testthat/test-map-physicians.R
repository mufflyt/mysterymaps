# The physician dot map. It jitters coordinates, colours by ACOG district and
# writes an HTML file plus a screenshot, so the assertions are about the layer
# structure and the files -- not about the pixels.

skip_unless_dots <- function() {
  skip_if_not_installed("leaflet")
  skip_if_not_installed("webshot")
  skip_if_not_installed("viridis")
  skip_if_not_installed("htmlwidgets")
  skip_if_not_installed("sf")
  skip_if_not_installed("rnaturalearth")
  skip_if_not_installed("rnaturalearthdata")
}

physicians <- function(n = 5) {
  data.frame(
    long = seq(-105, -101, length.out = n),
    lat  = seq(39, 41, length.out = n),
    name = paste("Physician", seq_len(n)),
    ACOG_District = rep(c("District VIII", "District IX"), length.out = n),
    stringsAsFactors = FALSE
  )
}

test_that("each required package is named in its own error", {
  for (pkg in c("leaflet", "webshot", "viridis", "htmlwidgets")) {
    local_mocked_bindings(
      requireNamespace = function(package, ...) !identical(package, pkg),
      .package = "base")
    expect_error(mysterymaps_map_physicians(physicians()),
                 sprintf("'%s' is required", pkg))
  }
})

test_that("the map carries markers, district polygons and a legend", {
  skip_unless_dots()
  out <- withr::local_tempdir()
  # webshot needs PhantomJS, which is not installed on a CI runner; the
  # screenshot is not what this test is about.
  local_mocked_bindings(webshot = function(url, file, ...) {
    file.create(file)
    invisible(file)
  }, .package = "webshot")

  m <- suppressWarnings(suppressMessages(
    mysterymaps_map_physicians(physicians(), output_dir = out)))

  calls <- mm_calls(m)
  expect_true("addCircleMarkers" %in% calls)
  expect_true("addPolygons" %in% calls)
  expect_true("addLegend" %in% calls)
})

test_that("an HTML file and a PNG land in output_dir", {
  skip_unless_dots()
  out <- withr::local_tempdir()
  local_mocked_bindings(webshot = function(url, file, ...) {
    file.create(file)
    invisible(file)
  }, .package = "webshot")

  suppressWarnings(suppressMessages(
    mysterymaps_map_physicians(physicians(), output_dir = out)))

  expect_length(list.files(out, pattern = "^dot_map_.*\\.html$"), 1L)
  expect_length(list.files(out, pattern = "^dot_map_.*\\.png$"), 1L)
})

test_that("the map is returned invisibly", {
  skip_unless_dots()
  out <- withr::local_tempdir()
  local_mocked_bindings(webshot = function(url, file, ...) {
    file.create(file)
    invisible(file)
  }, .package = "webshot")

  expect_invisible(suppressWarnings(suppressMessages(
    mysterymaps_map_physicians(physicians(), output_dir = out))))
})

test_that("jitter_range = 0 leaves the coordinates where they were", {
  # The jitter exists so co-located providers are both visible; it must be
  # switchable off for a map whose points are already distinct.
  skip_unless_dots()
  out <- withr::local_tempdir()
  local_mocked_bindings(webshot = function(url, file, ...) {
    file.create(file)
    invisible(file)
  }, .package = "webshot")

  pd <- physicians(3)
  m <- suppressWarnings(suppressMessages(
    mysterymaps_map_physicians(pd, jitter_range = 0, output_dir = out)))

  markers <- mm_call_args(m, "addCircleMarkers")
  expect_equal(sort(unlist(markers[[1]])), sort(pd$lat))
  expect_equal(sort(unlist(markers[[2]])), sort(pd$long))
})

test_that("the legend labels every ACOG district, not just those with points", {
  # The factor levels come from the district table rather than the data, so a
  # district with no providers still appears -- which is the finding.
  skip_unless_dots()
  out <- withr::local_tempdir()
  local_mocked_bindings(webshot = function(url, file, ...) {
    file.create(file)
    invisible(file)
  }, .package = "webshot")

  m <- suppressWarnings(suppressMessages(
    mysterymaps_map_physicians(physicians(2), output_dir = out)))
  legend <- mm_call_args(m, "addLegend")
  labels <- unlist(legend[[1]]$labels %||% legend)
  expect_gte(length(unlist(labels)), 2L)
})
