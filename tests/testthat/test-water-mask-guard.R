sq <- function(n) {
  skip_if_not_installed("sf")
  sf::st_sfc(sf::st_polygon(list(cbind(c(0,n,n,0,0), c(0,0,n,n,0)))), crs = 4326)
}

test_that("a mask the size of its state is rejected", {
  # 102-104% of land area, single feature: a state outline, not water.
  m <- list(MO = sq(4))            # large
  aw <- c(MO = 1)                  # tiny mapped water
  expect_warning(out <- mysterymaps_guard_water_masks(m, aw), "state outlines")
  expect_length(out, 0L)
  expect_true(!is.null(attr(out, "inverted")))
})

test_that("REGRESSION: a Great Lakes state is NOT rejected", {
  # Michigan's boundary contains the Great Lakes, so a large mask is correct.
  # Comparing to LAND area flagged it at 68% and would have let the surface run
  # across Lake Michigan -- the failure the clip exists to prevent.
  g <- sq(2)
  a <- as.numeric(sf::st_area(g)) / 1e6
  m <- list(MI = g)
  expect_silent(suppressMessages(out <- mysterymaps_guard_water_masks(m, c(MI = a))))
  expect_length(out, 1L)
})

test_that("plausible masks pass untouched", {
  g <- sq(1)
  a <- as.numeric(sf::st_area(g)) / 1e6
  out <- suppressMessages(mysterymaps_guard_water_masks(list(NY = g), c(NY = a * 2)))
  expect_named(out, "NY")
})

test_that("error mode aborts instead of excluding", {
  expect_error(
    mysterymaps_guard_water_masks(list(KS = sq(4)), c(KS = 1), action = "error"),
    "state outlines")
})

test_that("a state with no census water figure is not judged", {
  # Absent denominator means unknown, not guilty.
  out <- suppressWarnings(suppressMessages(
    mysterymaps_guard_water_masks(list(XX = sq(4)), c(YY = 1))))
  expect_length(out, 1L)
})

test_that("the threshold is a parameter, and 5x is the default", {
  expect_equal(formals(mysterymaps_guard_water_masks)$max_ratio, 5)
  g <- sq(2); a <- as.numeric(sf::st_area(g)) / 1e6
  expect_warning(mysterymaps_guard_water_masks(list(A = g), c(A = a / 10), max_ratio = 5))
  expect_silent(suppressMessages(
    mysterymaps_guard_water_masks(list(A = g), c(A = a / 10), max_ratio = 20)))
})
