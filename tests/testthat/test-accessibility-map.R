testthat::local_edition(3)

skip_unless_spatial <- function() {
  testthat::skip_if_not_installed("sf")
  testthat::skip_if_not_installed("ggplot2")
}

# The exact shape twostep::compute_e2sfca() documents returning: a list with
# an `access` element carrying GEOID, a scaled score, and coverage_status.
fixture_e2sfca <- function() {
  list(access = data.frame(
    GEOID = c("T1", "T2", "T3", "T4"),
    access = c(0, 4.2, NA, 7.8) / 1,
    access_scaled = c(0, 4.2, NA, 7.8),
    coverage_status = c("within_modeled_catchment", "within_modeled_catchment",
                        "outside_all_modeled_catchments", "within_modeled_catchment")
  ))
}

fixture_tracts <- function(geoid = c("T1", "T2", "T3", "T4")) {
  sf::st_sf(
    GEOID = geoid,
    geometry = sf::st_sfc(lapply(seq_along(geoid), function(i) {
      x <- -100 + i
      sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x), c(40, 40, 41, 41, 40))))
    }), crs = 4326)
  )
}

testthat::test_that("builds a ggplot with one feature per tract", {
  skip_unless_spatial()
  p <- mysterymaps_accessibility_map(fixture_e2sfca(), fixture_tracts())
  testthat::expect_s3_class(p, "ggplot")
  testthat::expect_equal(nrow(p$layers[[1]]$data), 4L)
})

testthat::test_that("REGRESSION: a reached tract scoring zero is NOT the same colour as one outside every catchment", {
  # Before twostep distinguished these, outside-catchment tracts were
  # zero-filled and became indistinguishable from a measured zero -- 190 of
  # 1,447 Colorado tracts, 13% of the state, each reported as "zero
  # accessibility" when the honest finding was "never reached". This pins
  # that mysterymaps_accessibility_map() keeps the distinction twostep makes.
  skip_unless_spatial()
  p <- mysterymaps_accessibility_map(fixture_e2sfca(), fixture_tracts())
  ld <- p$layers[[1]]$data
  t1 <- ld$.mm_fill_color[ld$GEOID == "T1"]  # reached, score 0
  t3 <- ld$.mm_fill_color[ld$GEOID == "T3"]  # outside every catchment
  testthat::expect_equal(t1, "#e0e0e0")
  testthat::expect_equal(t3, "#efe7d5")
  testthat::expect_false(identical(t1, t3))
})

testthat::test_that("a tract reached but with an NA score gets na_color, distinct from a measured zero or outside", {
  skip_unless_spatial()
  e <- fixture_e2sfca()
  e$access$access_scaled[e$access$GEOID == "T2"] <- NA_real_  # reached, score unknown
  p <- mysterymaps_accessibility_map(e, fixture_tracts())
  ld <- p$layers[[1]]$data
  testthat::expect_equal(ld$.mm_fill_color[ld$GEOID == "T2"], "#ffffff")  # na_color
  testthat::expect_equal(ld$.mm_fill_color[ld$GEOID == "T1"], "#e0e0e0") # zero_color
  testthat::expect_equal(ld$.mm_fill_color[ld$GEOID == "T3"], "#efe7d5") # outside_color
})

testthat::test_that("REGRESSION: a tract whose GEOID matches nothing in access is still drawn, coloured na_color", {
  # A left join from the geometry side keeps every polygon on the map. A
  # bare NA coverage_status from the failed join must not reach
  # mysterymaps_jenks_zero_scale(), which refuses to guess at it -- it must
  # route to the ordinary missing-value path instead.
  skip_unless_spatial()
  tracts <- fixture_tracts(c("T1", "T2", "T3", "T_UNMATCHED"))
  p <- mysterymaps_accessibility_map(fixture_e2sfca(), tracts)
  ld <- p$layers[[1]]$data
  testthat::expect_equal(nrow(ld), 4L)
  testthat::expect_equal(ld$.mm_fill_color[ld$GEOID == "T_UNMATCHED"], "#ffffff")
})

testthat::test_that("value_col switches between access and access_scaled", {
  # Coloring is by RANK (Jenks classification), so a test must flip the rank
  # order between the two columns -- not just change their magnitudes, which
  # can legitimately produce identical colours under the same classification.
  skip_unless_spatial()
  e <- fixture_e2sfca()
  e$access$access <- c(0, 200, NA, 100)   # T2 > T4 here, opposite of access_scaled's T2 < T4
  p_scaled <- mysterymaps_accessibility_map(e, fixture_tracts(), value_col = "access_scaled")
  p_raw <- mysterymaps_accessibility_map(e, fixture_tracts(), value_col = "access")
  ld_scaled <- p_scaled$layers[[1]]$data
  ld_raw <- p_raw$layers[[1]]$data
  testthat::expect_false(identical(
    ld_scaled$.mm_fill_color[ld_scaled$GEOID == "T2"],
    ld_raw$.mm_fill_color[ld_raw$GEOID == "T2"]))
})

testthat::test_that("colours are overridable", {
  skip_unless_spatial()
  p <- mysterymaps_accessibility_map(
    fixture_e2sfca(), fixture_tracts(),
    zero_color = "pink", outside_color = "brown", na_color = "black")
  ld <- p$layers[[1]]$data
  testthat::expect_equal(ld$.mm_fill_color[ld$GEOID == "T1"], "pink")
  testthat::expect_equal(ld$.mm_fill_color[ld$GEOID == "T3"], "brown")
})

testthat::test_that("the legend title defaults to 'Modeled Accessibility' and is overridable", {
  skip_unless_spatial()
  p <- mysterymaps_accessibility_map(fixture_e2sfca(), fixture_tracts())
  testthat::expect_equal(p$scales$scales[[1]]$name, "Modeled Accessibility")
  p2 <- mysterymaps_accessibility_map(fixture_e2sfca(), fixture_tracts(),
                                      legend_title = "Urogynecology Access")
  testthat::expect_equal(p2$scales$scales[[1]]$name, "Urogynecology Access")
})

testthat::test_that("errors with a clear message when `access` is missing from e2sfca_result", {
  skip_unless_spatial()
  testthat::expect_error(
    mysterymaps_accessibility_map(list(not_access = 1), fixture_tracts()),
    "no `access` element")
})

testthat::test_that("errors when tracts_sf has no GEOID column", {
  skip_unless_spatial()
  bad_tracts <- fixture_tracts()
  names(bad_tracts)[names(bad_tracts) == "GEOID"] <- "geoid_lower"
  testthat::expect_error(
    mysterymaps_accessibility_map(fixture_e2sfca(), bad_tracts))
})

testthat::test_that("errors when access is missing a required column", {
  skip_unless_spatial()
  e <- fixture_e2sfca()
  e$access$coverage_status <- NULL
  testthat::expect_error(mysterymaps_accessibility_map(e, fixture_tracts()))
})

testthat::test_that("errors on zero-row tracts_sf", {
  skip_unless_spatial()
  testthat::expect_error(
    mysterymaps_accessibility_map(fixture_e2sfca(), fixture_tracts()[0, ]),
    "zero rows")
})

testthat::test_that("each needed package is named in its own error", {
  skip_unless_spatial()
  for (pkg in c("sf", "ggplot2")) {
    testthat::local_mocked_bindings(
      requireNamespace = function(package, ...) !identical(package, pkg),
      .package = "base")
    testthat::expect_error(
      mysterymaps_accessibility_map(fixture_e2sfca(), fixture_tracts()),
      sprintf("needs the '%s' package", pkg))
  }
})
