mk <- function() {
  skip_if_not_installed("sf")
  sq <- sf::st_sfc(sf::st_polygon(list(cbind(c(0,2,2,0,0), c(0,0,2,2,0)))), crs = 4326)
  pts <- sf::st_as_sf(data.frame(state = c("AA","AA","BB"),
                                 x = c(1, 1.5, 9), y = c(1, 1.5, 9)),
                      coords = c("x","y"), crs = 4326)
  list(surface = sq, pts = pts)
}

test_that("all-inside passes quietly", {
  d <- mk()
  res <- mysterymaps_gate_provider_coverage(d$pts[1:2, ], d$surface)
  expect_equal(res$n_outside, 0L)
})

test_that("a provider outside their own surface is an ERROR by default", {
  # A provider is within any drive time of themselves. One outside means an
  # isochrone was never generated -- which does not error, warn, or leave a
  # visible hole; it just removes shading that should have been there.
  d <- mk()
  expect_error(mysterymaps_gate_provider_coverage(d$pts, d$surface),
               "OUTSIDE the surface")
})

test_that("the failure names where it clusters", {
  d <- mk()
  expect_error(
    mysterymaps_gate_provider_coverage(d$pts, d$surface, group_col = "state"),
    "BB \\(1\\)")
  expect_error(
    mysterymaps_gate_provider_coverage(d$pts, d$surface, group_col = "state"),
    "batch that did not run")
})

test_that("a tolerance can be set, but zero is the default", {
  d <- mk()
  expect_equal(formals(mysterymaps_gate_provider_coverage)$max_missing_pct, 0)
  res <- mysterymaps_gate_provider_coverage(d$pts, d$surface, max_missing_pct = 50)
  expect_equal(res$n_outside, 1L)
})

test_that("warn mode reports without aborting", {
  d <- mk()
  expect_warning(mysterymaps_gate_provider_coverage(d$pts, d$surface, on_fail = "warn"),
                 "OUTSIDE")
})
