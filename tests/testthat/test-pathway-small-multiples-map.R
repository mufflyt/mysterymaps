testthat::local_edition(3)

skip_unless_spatial <- function() {
  testthat::skip_if_not_installed("sf")
  testthat::skip_if_not_installed("ggplot2")
}

fixture_pts <- function() {
  f <- mm_points(n = 8)
  f$pathway <- rep(c("OBGYN", "URO"), length.out = 8)
  f
}

testthat::test_that("facets include a combined panel plus one per pathway", {
  skip_unless_spatial()
  pts <- fixture_pts()
  poly <- mm_square(-100, 39, w = 3)
  poly <- sf::st_as_sf(poly)
  p <- mysterymaps_pathway_small_multiples_map(pts, poly, pathway_var = "pathway")
  panel_levels <- levels(p$layers[[2]]$data$.mm_panel)
  testthat::expect_true("All Pathways Combined" %in% panel_levels)
  testthat::expect_true(all(c("OBGYN", "URO") %in% panel_levels))
})

testthat::test_that("pathway_labels recodes abbreviations to full words", {
  skip_unless_spatial()
  pts <- fixture_pts()
  poly <- sf::st_as_sf(mm_square(-100, 39, w = 3))
  p <- mysterymaps_pathway_small_multiples_map(
    pts, poly, pathway_var = "pathway", include_combined_panel = FALSE,
    pathway_labels = c(OBGYN = "Obstetrics and Gynecology", URO = "Urology"))
  panel_levels <- levels(p$layers[[2]]$data$.mm_panel)
  testthat::expect_true(all(c("Obstetrics and Gynecology", "Urology") %in% panel_levels))
  testthat::expect_false(any(c("OBGYN", "URO") %in% panel_levels))
})

testthat::test_that("errors on zero rows", {
  skip_unless_spatial()
  pts <- fixture_pts()
  poly <- sf::st_as_sf(mm_square(-100, 39, w = 3))
  testthat::expect_error(
    mysterymaps_pathway_small_multiples_map(pts[0, ], poly, pathway_var = "pathway"),
    "zero rows")
})
