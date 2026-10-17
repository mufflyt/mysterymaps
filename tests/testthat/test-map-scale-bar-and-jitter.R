testthat::local_edition(3)

skip_unless_spatial <- function() {
  testthat::skip_if_not_installed("sf")
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("ggspatial")
}

testthat::test_that("mysterymaps_scale_bar defaults to imperial units", {
  skip_unless_spatial()
  layer <- mysterymaps_scale_bar()
  testthat::expect_true(inherits(layer, "Layer"))
  # unit_category is forwarded through `...` into aes_params -- it has no
  # formal argument on annotation_scale() itself, so this is the only place
  # that proves the default actually reaches the underlying geom.
  testthat::expect_identical(layer$aes_params$unit_category, "imperial")
})

testthat::test_that("mysterymaps_scale_bar validates location and width_hint", {
  skip_unless_spatial()
  testthat::expect_error(mysterymaps_scale_bar(location = "center"))
  testthat::expect_error(mysterymaps_scale_bar(width_hint = 2))
})

testthat::test_that("MYSTERYMAPS_ISOCHRONE_BANDS_MINUTES is the four production bands", {
  testthat::expect_identical(MYSTERYMAPS_ISOCHRONE_BANDS_MINUTES, c(30L, 60L, 120L, 180L))
})

testthat::test_that("jitter displaces points by no more than the requested radius", {
  skip_unless_spatial()
  pts <- mm_points(n = 20)
  jittered <- mysterymaps_jitter_points(pts, miles = 1.5, seed = 42)
  orig_m <- sf::st_transform(pts, 5070)
  jit_m <- sf::st_transform(jittered, 5070)
  d <- as.numeric(sf::st_distance(orig_m, jit_m, by_element = TRUE))
  testthat::expect_true(all(d <= 1.5 * 1609.344 + 1e-6))
  testthat::expect_true(any(d > 0))
})

testthat::test_that("jitter is deterministic for a fixed seed and reproducible across calls", {
  skip_unless_spatial()
  pts <- mm_points(n = 10)
  a <- mysterymaps_jitter_points(pts, miles = 1, seed = 7)
  b <- mysterymaps_jitter_points(pts, miles = 1, seed = 7)
  testthat::expect_equal(sf::st_coordinates(a), sf::st_coordinates(b))
})

testthat::test_that("miles = 0 returns points unchanged", {
  skip_unless_spatial()
  pts <- mm_points(n = 5)
  out <- mysterymaps_jitter_points(pts, miles = 0, seed = 42)
  testthat::expect_equal(sf::st_coordinates(out), sf::st_coordinates(pts))
})

testthat::test_that("jitter does not leak the random seed into the caller's stream", {
  skip_unless_spatial()
  pts <- mm_points(n = 5)
  set.seed(999)
  before <- runif(1)
  set.seed(999)
  invisible(mysterymaps_jitter_points(pts, miles = 1, seed = 42))
  after <- runif(1)
  testthat::expect_identical(before, after)
})
