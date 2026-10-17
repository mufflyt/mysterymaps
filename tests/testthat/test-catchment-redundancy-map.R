testthat::local_edition(3)

skip_unless_spatial <- function() {
  testthat::skip_if_not_installed("sf")
  testthat::skip_if_not_installed("ggplot2")
}

# Two overlapping provider catchments over a 2-county strip: county 1 is
# covered by provider A only, county 2 by both A and B.
fixture <- function() {
  counties <- mm_counties(n = 2, rate = c(0, 0))
  catch_a <- sf::st_sf(provider = "A", geometry = mm_square(-99, 40, w = 2))
  catch_b <- sf::st_sf(provider = "B", geometry = mm_square(-98, 40, w = 1))
  list(counties = counties, catchments = rbind(catch_a, catch_b))
}

testthat::test_that("a county covered by two providers scores higher than one covered by one", {
  skip_unless_spatial()
  f <- fixture()
  p <- mysterymaps_catchment_redundancy_map(
    f$catchments, f$counties, provider_id_var = "provider", grid_spacing_miles = 10)
  vals <- p$layers[[1]]$data$.mm_redundancy
  testthat::expect_length(vals, 2L)
  testthat::expect_true(vals[2] >= vals[1])
})

testthat::test_that("errors on zero-row catchments or polygons", {
  skip_unless_spatial()
  f <- fixture()
  testthat::expect_error(
    mysterymaps_catchment_redundancy_map(f$catchments[0, ], f$counties,
                                         provider_id_var = "provider"),
    "zero rows")
  testthat::expect_error(
    mysterymaps_catchment_redundancy_map(f$catchments, f$counties[0, ],
                                         provider_id_var = "provider"),
    "zero rows")
})
