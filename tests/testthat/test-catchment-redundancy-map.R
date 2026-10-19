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

testthat::test_that("REGRESSION: a county with zero redundancy gets its own colour class", {
  # The original implementation coloured .mm_redundancy with a plain
  # continuous scale_fill_viridis_c() plus a hand-written integer-breaks
  # helper, which put 0 ("no option at all") at the same dark end of the
  # gradient as "merely low redundancy" -- exactly what
  # mysterymaps_jenks_zero_scale() exists to prevent.
  skip_unless_spatial()
  counties <- mm_counties(n = 2, rate = c(0, 0))
  # one catchment covering county 1 only; county 2 has zero redundancy
  catch_a <- sf::st_sf(provider = "A", geometry = mm_square(-99, 40, w = 1))
  p <- mysterymaps_catchment_redundancy_map(
    catch_a, counties, provider_id_var = "provider", grid_spacing_miles = 10)
  ld <- p$layers[[1]]$data
  zero_rows <- which(ld$.mm_redundancy == 0)
  testthat::expect_true(length(zero_rows) > 0)
  testthat::expect_true(all(ld$.mm_fill_color[zero_rows] == "#e0e0e0"))
  testthat::expect_false(any(ld$.mm_fill_color[-zero_rows] == "#e0e0e0"))
})

testthat::test_that("zero_color is overridable", {
  skip_unless_spatial()
  counties <- mm_counties(n = 2, rate = c(0, 0))
  catch_a <- sf::st_sf(provider = "A", geometry = mm_square(-99, 40, w = 1))
  p <- mysterymaps_catchment_redundancy_map(
    catch_a, counties, provider_id_var = "provider", grid_spacing_miles = 10,
    zero_color = "pink")
  ld <- p$layers[[1]]$data
  testthat::expect_true(any(ld$.mm_fill_color == "pink"))
})

testthat::test_that("each needed package is named in its own error", {
  f <- fixture()
  for (pkg in c("sf", "ggplot2")) {
    testthat::local_mocked_bindings(
      requireNamespace = function(package, ...) !identical(package, pkg),
      .package = "base")
    testthat::expect_error(
      mysterymaps_catchment_redundancy_map(f$catchments, f$counties, provider_id_var = "provider"),
      sprintf("needs the '%s' package", pkg))
  }
})

testthat::test_that("invalid catchment or polygon geometry is repaired rather than erroring", {
  # A self-intersecting ("bowtie") polygon is invalid per se; st_is_valid()
  # returns FALSE and most sf set operations downstream refuse to run on it
  # unless repaired first.
  skip_unless_spatial()
  bowtie <- sf::st_polygon(list(cbind(c(-99, -97, -99, -97, -99), c(40, 40, 42, 42, 40))))
  bad_catchments <- sf::st_sf(provider = "A",
                              geometry = sf::st_sfc(bowtie, crs = 4326))
  counties <- mm_counties(n = 2, rate = c(0, 0))
  expect_true(any(!sf::st_is_valid(bad_catchments)))

  p <- mysterymaps_catchment_redundancy_map(
    bad_catchments, counties, provider_id_var = "provider", grid_spacing_miles = 10)
  testthat::expect_s3_class(p, "ggplot")
})

testthat::test_that("a polygon narrower than the grid spacing is still scored, via the fallback sample", {
  # The documented real-world case: an independent city too small for any
  # sample grid point to land inside it at the chosen spacing, alongside an
  # ordinary-sized county the grid samples normally. Only the tiny polygon
  # should need the fallback; starving the WHOLE grid (every polygon missed)
  # is a different, further edge case this test does not exercise.
  skip_unless_spatial()
  normal_county <- sf::st_sf(
    GEOID = "normal", NAMELSAD = "Normal County", rate = 0,
    geometry = mm_square(-99, 40, w = 1))
  tiny_city <- sf::st_sf(
    GEOID = "tiny", NAMELSAD = "Tiny Independent City", rate = 0,
    geometry = mm_square(-97.5, 40, w = 0.01))
  counties <- rbind(normal_county, tiny_city)
  catch_a <- sf::st_sf(provider = "A",
                       geometry = mm_square(-99.5, 39.5, w = 3))

  p <- mysterymaps_catchment_redundancy_map(
    catch_a, counties, provider_id_var = "provider", grid_spacing_miles = 20)
  vals <- p$layers[[1]]$data$.mm_redundancy
  testthat::expect_false(any(is.na(vals)))
})

testthat::test_that("SABOTEUR: grid_spacing_miles = Inf errors clearly instead of a cryptic aggregate() failure", {
  # Without finite = TRUE, the cell size becomes Inf, st_make_grid() silently
  # produces a grid with no points, and the failure surfaces several steps
  # later as stats::aggregate()'s unrelated "no rows to aggregate" -- naming
  # neither this argument nor Inf as the cause.
  skip_unless_spatial()
  f <- fixture()
  testthat::expect_error(
    mysterymaps_catchment_redundancy_map(
      f$catchments, f$counties, provider_id_var = "provider", grid_spacing_miles = Inf),
    "finite")
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
