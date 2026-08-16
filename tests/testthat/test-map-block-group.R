# The block-group overlap map. Every check here is on the input contract: the
# function writes an HTML file and a screenshot, so a bad input that slips
# through produces a plausible-looking map of the wrong thing.

skip_unless_bg <- function() {
  skip_if_not_installed("sf")
  skip_if_not_installed("leaflet")
  skip_if_not_installed("lwgeom")
  skip_if_not_installed("webshot")
  skip_if_not_installed("htmlwidgets")
}

bg_with_overlap <- function(overlap = c(0.1, 0.4, 0.8, 1)) {
  bg <- mm_block_groups(length(overlap))
  bg$overlap <- overlap
  bg
}

test_that("output_dir must be a non-empty string", {
  skip_unless_bg()
  expect_error(
    mysterymaps_map_block_group(bg_with_overlap(), mm_isochrones(),
                                output_dir = ""),
    "output_dir")
})

test_that("both inputs must be sf", {
  skip_unless_bg()
  expect_error(
    mysterymaps_map_block_group(data.frame(a = 1), mm_isochrones()),
    "`bg_data` must be an sf object")
  expect_error(
    mysterymaps_map_block_group(bg_with_overlap(), data.frame(a = 1)),
    "`isochrones_data` must be an sf object")
})

test_that("isochrones must carry a numeric drive_time in minutes", {
  skip_unless_bg()
  iso <- mm_isochrones()
  iso$drive_time <- NULL
  expect_error(
    mysterymaps_map_block_group(bg_with_overlap(), iso),
    "must include a `drive_time` column")

  iso2 <- mm_isochrones()
  iso2$drive_time <- as.character(iso2$drive_time)
  expect_error(
    mysterymaps_map_block_group(bg_with_overlap(), iso2),
    "must be a numeric column")
})

test_that("the overlap column is required, and named as computed upstream", {
  # Pointing at mysterymaps_calculate_overlap() saves the caller working out
  # where a proportion column was supposed to come from.
  skip_unless_bg()
  expect_error(
    mysterymaps_map_block_group(mm_block_groups(), mm_isochrones()),
    "mysterymaps_calculate_overlap")
})

test_that("overlap outside 0-1 is refused", {
  # A percentage passed where a proportion was expected renders every block
  # group at the top of the colour ramp, which reads as total coverage.
  skip_unless_bg()
  expect_error(
    mysterymaps_map_block_group(bg_with_overlap(c(0.1, 0.4, 0.8, 40)),
                                mm_isochrones()),
    "must be between 0 and 1")
  expect_error(
    mysterymaps_map_block_group(bg_with_overlap(c(-0.1, 0.4, 0.8, 1)),
                                mm_isochrones()),
    "must be between 0 and 1")
})

test_that("NA overlap values are tolerated", {
  # A block group the isochrones never reached has no overlap, which is
  # different from an invalid one.
  skip_unless_bg()
  bg <- bg_with_overlap(c(0.1, NA, 0.8, 1))
  out <- withr::local_tempdir()
  expect_no_error(suppressWarnings(suppressMessages(
    mysterymaps_map_block_group(bg, mm_isochrones(), output_dir = out))))
})

test_that("a full run writes an HTML map into output_dir", {
  skip_unless_bg()
  out <- withr::local_tempdir()
  suppressWarnings(suppressMessages(
    mysterymaps_map_block_group(bg_with_overlap(), mm_isochrones(),
                                output_dir = out)))
  expect_length(list.files(out, pattern = "^overlap_bg_map_.*\\.html$"), 1L)
})

test_that("each required package is named in its own error", {
  for (pkg in c("sf", "leaflet", "lwgeom", "webshot", "htmlwidgets")) {
    local_mocked_bindings(
      requireNamespace = function(package, ...) !identical(package, pkg),
      .package = "base")
    expect_error(
      mysterymaps_map_block_group(bg_with_overlap(), mm_isochrones()),
      sprintf("'%s' is required", pkg))
  }
})
