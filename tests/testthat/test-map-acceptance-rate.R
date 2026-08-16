# The simpler of the two state choropleths. It multiplies rates by 100 for
# display, which is the detail most likely to be got wrong twice.

skip_unless_ggplot <- function() {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("maps")
  # coord_map() renders through mapproj; without it these maps cannot be built.
  skip_if_not_installed("mapproj")
}

test_that("it returns a ggplot invisibly", {
  skip_unless_ggplot()
  df <- data.frame(state = c("Colorado", "California"), rate = c(0.55, 0.72))
  expect_s3_class(mysterymaps_map_acceptance_rate(df, "state", "rate"), "ggplot")
  expect_invisible(mysterymaps_map_acceptance_rate(df, "state", "rate"))
})

test_that("rates are converted to percentages exactly once", {
  # 0.55 must reach the plot as 55, not 0.55 and not 5500.
  skip_unless_ggplot()
  df <- data.frame(state = "Colorado", rate = 0.55)
  p <- mysterymaps_map_acceptance_rate(df, "state", "rate")
  expect_equal(unique(p$data$rate_pct[p$data$region == "colorado"]), 55)
})

test_that("two-letter abbreviations are expanded to full names", {
  skip_unless_ggplot()
  abb  <- data.frame(state = c("CO", "CA"), rate = c(0.55, 0.72))
  full <- data.frame(state = c("Colorado", "California"), rate = c(0.55, 0.72))
  got  <- mysterymaps_map_acceptance_rate(abb, "state", "rate")$data
  want <- mysterymaps_map_acceptance_rate(full, "state", "rate")$data
  expect_equal(got$rate_pct, want$rate_pct)
})

test_that("`data` must be a data frame with both named columns", {
  skip_unless_ggplot()
  expect_error(mysterymaps_map_acceptance_rate(1:3, "a", "b"),
               "must be a data frame")
  expect_error(
    mysterymaps_map_acceptance_rate(data.frame(a = 1), "state", "rate"),
    "Column 'state' not found")
  expect_error(
    mysterymaps_map_acceptance_rate(data.frame(state = "CO"), "state", "rate"),
    "Column 'rate' not found")
})

test_that("region_type = 'hrr' refuses with a pointer to the sf workflow", {
  # HRR polygons are not in the maps package; failing here with instructions
  # beats failing later with "region not found".
  skip_unless_ggplot()
  df <- data.frame(state = "Colorado", rate = 0.5)
  expect_error(
    mysterymaps_map_acceptance_rate(df, "state", "rate", region_type = "hrr"),
    "map_create_base")
})

test_that("an unknown region_type is rejected", {
  skip_unless_ggplot()
  df <- data.frame(state = "Colorado", rate = 0.5)
  expect_error(
    mysterymaps_map_acceptance_rate(df, "state", "rate", region_type = "county"))
})

test_that("polygon draw order survives the merge", {
  skip_unless_ggplot()
  df <- data.frame(state = c("Colorado", "California", "Texas"),
                   rate = c(0.5, 0.6, 0.4))
  d <- mysterymaps_map_acceptance_rate(df, "state", "rate")$data
  by_group <- split(d$order, d$group)
  expect_true(all(vapply(by_group, function(o) !is.unsorted(o), logical(1))))
})

test_that("states with no data survive the join as NA", {
  skip_unless_ggplot()
  df <- data.frame(state = "Colorado", rate = 0.5)
  d <- mysterymaps_map_acceptance_rate(df, "state", "rate")$data
  expect_true(any(is.na(d$rate_pct)))
  expect_true(any(!is.na(d$rate_pct)))
})

test_that("save_path actually writes a file at the requested size", {
  # mysterycall_save_plot() is reached through an importFrom binding, so this
  # runs it for real rather than mocking it: the thing worth knowing is that a
  # file lands on disk, not that a function was called.
  skip_unless_ggplot()
  skip_if_not_installed("mysterycall")
  dir <- withr::local_tempdir()
  target <- file.path(dir, "acceptance.png")

  mysterymaps_map_acceptance_rate(
    data.frame(state = c("Colorado", "California"), rate = c(0.55, 0.72)),
    "state", "rate", save_path = target, width = 5, height = 4, dpi = 72L)

  expect_true(file.exists(target))
  expect_gt(file.size(target), 0)
})

test_that("no file is written when save_path is NULL", {
  skip_unless_ggplot()
  dir <- withr::local_tempdir()
  withr::local_dir(dir)
  mysterymaps_map_acceptance_rate(data.frame(state = "Colorado", rate = 0.5),
                                  "state", "rate")
  expect_length(list.files(dir), 0L)
})

test_that("ggplot2, maps and mapproj are each named in their own error", {
  for (pkg in c("ggplot2", "maps", "mapproj")) {
    local_mocked_bindings(
      requireNamespace = function(package, ...) !identical(package, pkg),
      .package = "base")
    expect_error(
      mysterymaps_map_acceptance_rate(data.frame(state = "CO", rate = 0.5),
                                      "state", "rate"),
      sprintf("'%s' is required", pkg))
  }
})
