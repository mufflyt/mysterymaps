# Adversarial/boundary-case testing for mysterymaps_hex_access_maps() and the
# 8 internal helpers the cyclocomp refactor extracted from it. Matches the
# convention established by the sibling PR "Fix 7 silent-corruption and
# cryptic-error bugs found by adversarial testing": deliberately malformed and
# boundary-case inputs, not just each function's own documented examples.

testthat::local_edition(3)

skip_unless_spatial <- function() {
  testthat::skip_if_not_installed("sf")
}

mm_points <- function(origin_id, year, population, travel_minutes, x, y, crs = 4326, extra = list()) {
  sf::st_as_sf(
    base::data.frame(c(
      base::list(
        origin_id = origin_id, year = year, population = population,
        travel_minutes = travel_minutes, x = x, y = y
      ),
      extra
    )),
    coords = c("x", "y"), crs = crs
  )
}

mm_region <- function() {
  sf::st_sf(geometry = sf::st_as_sfc(
    sf::st_bbox(c(xmin = -79, ymin = 36, xmax = -77, ymax = 38), crs = sf::st_crs(4326))
  ))
}

# ---- Saboteur 1: reversed years silently flipped the comparison direction --
# REAL BUG, FIXED. years = c(2023, 2013) used to run with no error: "current"
# became 2013, "earlier" became 2023, change_minutes came out negated, and the
# map title read "Change in access: 2023 to 2013" with no indication anything
# was backwards. years[1] >= years[2] is now rejected in validation.
testthat::test_that("REGRESSION: years out of ascending order errors instead of silently flipping change direction", {
  skip_unless_spatial()
  locations <- mm_points(
    c("a", "b", "a", "b"), c(2013L, 2013L, 2023L, 2023L), c(100, 300, 100, 300),
    c(20, 80, 40, 100), x = c(-78, -78.01, -78, -78.01), y = c(37, 37.01, 37, 37.01)
  )
  testthat::expect_error(
    mysterymaps_hex_access_maps(locations, mm_region(), hex_km = 300, years = c(2023L, 2013L)),
    "Invalid"
  )
})

testthat::test_that("equal years still errors (pre-existing guard, not regressed by the >= fix)", {
  skip_unless_spatial()
  locations <- mm_points(
    c("a", "b"), c(2013L, 2013L), c(100, 300), c(20, 80),
    x = c(-78, -78.01), y = c(37, 37.01)
  )
  testthat::expect_error(
    mysterymaps_hex_access_maps(locations, mm_region(), hex_km = 300, years = c(2013L, 2013L)),
    "Invalid"
  )
})

# ---- Saboteur 2: Inf travel time silently poisoned the weighted mean -------
# REAL BUG, FIXED, in the internal helper .hex_access_weighted_minutes().
# Unreachable via the exported function (filter_years already rejects Inf
# upstream), but the helper itself had no defense -- is.finite() now excludes
# Inf/-Inf/NaN the same way it already excludes NA.
testthat::test_that("REGRESSION: .hex_access_weighted_minutes() excludes Inf instead of letting it poison the mean", {
  wm <- base::get(".hex_access_weighted_minutes", envir = base::asNamespace("mysterymaps"))
  testthat::expect_equal(wm(c(10, Inf, 20), c(100, 100, 100)), 15)
  testthat::expect_true(base::is.na(wm(c(Inf, -Inf), c(100, 100))))
  testthat::expect_true(base::is.na(wm(c(NaN, NaN), c(100, 100))))
})

testthat::test_that(".hex_access_weighted_minutes() still excludes NA and zero-weight rows as before", {
  wm <- base::get(".hex_access_weighted_minutes", envir = base::asNamespace("mysterymaps"))
  testthat::expect_equal(wm(c(10, NA, 20), c(100, 100, 100)), 15)
  testthat::expect_equal(wm(c(10, 20), c(100, 0)), 10)
  testthat::expect_true(base::is.na(wm(c(10, 20), c(0, 0))))
})

# ---- Saboteur 3: all population zero in a hex-year, travel otherwise valid --
testthat::test_that("all-zero population in a hex-year yields NA weighted_minutes, not 0 or a crash", {
  skip_unless_spatial()
  locations <- mm_points(
    c("a", "b", "a", "b"), c(2013L, 2013L, 2023L, 2023L), c(0, 0, 0, 0),
    c(20, 80, 40, 100), x = c(-78, -78.01, -78, -78.01), y = c(37, 37.01, 37, 37.01)
  )
  mapped <- mysterymaps_hex_access_maps(locations, mm_region(), hex_km = 300)
  testthat::expect_true(base::all(base::is.na(mapped$summaries$weighted_minutes)))
})

# ---- Saboteur 4: all travel NA for one year under default min_coverage = 1 --
testthat::test_that("a hex-year with zero coverage is suppressed to NA, the other year is unaffected", {
  skip_unless_spatial()
  locations <- mm_points(
    c("a", "b", "a", "b"), c(2013L, 2013L, 2023L, 2023L), c(100, 300, 100, 300),
    c(NA, NA, 40, 100), x = c(-78, -78.01, -78, -78.01), y = c(37, 37.01, 37, 37.01)
  )
  mapped <- mysterymaps_hex_access_maps(locations, mm_region(), hex_km = 300)
  s13 <- mapped$summaries[mapped$summaries$year == 2013L, ]
  s23 <- mapped$summaries[mapped$summaries$year == 2023L, ]
  testthat::expect_equal(s13$coverage, 0)
  testthat::expect_true(base::is.na(s13$weighted_minutes))
  testthat::expect_false(base::is.na(s23$weighted_minutes))
})

# ---- Saboteur 5: partial coverage below default (1) but above a lowered min_coverage
testthat::test_that("partial coverage is correctly computed from the valid subset only, not NA'd when min_coverage is lowered", {
  skip_unless_spatial()
  y2013 <- mm_points(
    c("a", "b", "c", "d"), 2013L, c(100, 300, 0, 0), c(20, NA, 999, 999),
    x = c(-78, -78.01, -78, -78.01), y = c(37, 37.01, 37, 37.01)
  )
  y2023 <- mm_points(
    c("a", "b", "c", "d"), 2023L, c(100, 300, 0, 0), c(40, 100, 999, 999),
    x = c(-78, -78.01, -78, -78.01), y = c(37, 37.01, 37, 37.01)
  )
  locations <- base::rbind(y2013, y2023)
  mapped <- mysterymaps_hex_access_maps(locations, mm_region(), hex_km = 300, min_coverage = 0.2)
  s13 <- mapped$summaries[mapped$summaries$year == 2013L, ]
  testthat::expect_equal(s13$coverage, 0.25)
  testthat::expect_equal(s13$weighted_minutes, 20)
})

# ---- Saboteur 6: duplicate origin_id+year rows must fail closed ------------
testthat::test_that("duplicate origin_id within the same year errors instead of silently double-counting population", {
  skip_unless_spatial()
  locations <- mm_points(
    c("a", "a", "a", "a"), c(2013L, 2013L, 2023L, 2023L), c(100, 300, 100, 300),
    c(20, 80, 40, 100), x = c(-78, -78.01, -78, -78.01), y = c(37, 37.01, 37, 37.01)
  )
  testthat::expect_error(
    mysterymaps_hex_access_maps(locations, mm_region(), hex_km = 300),
    "unique"
  )
})

testthat::test_that("NA origin_id errors rather than being silently joined", {
  skip_unless_spatial()
  locations <- mm_points(
    c("a", NA, "a", "b"), c(2013L, 2013L, 2023L, 2023L), c(100, 300, 100, 300),
    c(20, 80, 40, 100), x = c(-78, -78.01, -78, -78.01), y = c(37, 37.01, 37, 37.01)
  )
  testthat::expect_error(
    mysterymaps_hex_access_maps(locations, mm_region(), hex_km = 300),
    "unique"
  )
})

# ---- Saboteur 7: a point exactly on a shared hexagon boundary edge ---------
# Confirms the documented dedup behaviour (comment in .hex_access_assign_hexagons)
# actually holds: no double-counting, no error, deterministic single hex_id.
testthat::test_that("a point on a shared hex boundary edge is assigned exactly one hexagon, not duplicated", {
  skip_unless_spatial()
  locations <- mm_points(
    c("a", "b", "a", "b"), c(2013L, 2013L, 2023L, 2023L), c(100, 100, 100, 100),
    c(20, 20, 40, 40), x = c(-78, -78, -78, -78), y = c(37, 37, 37, 37)
  )
  mapped <- mysterymaps_hex_access_maps(locations, mm_region(), hex_km = 300)
  testthat::expect_length(base::unique(mapped$summaries$hex_id), 1L)
  testthat::expect_equal(
    mapped$summaries$total_population[mapped$summaries$year == 2013L], 200
  )
})

# ---- Saboteur 8: non-convex boundary (a hole) must not fragment hex_id -----
# The class of bug this exact package fixed twice elsewhere tonight (grid_id
# attribute-join fan-out after st_intersection splits a cell on an irregular
# boundary). st_intersection() keeps a split cell as one MULTIPOLYGON row
# here rather than multiple rows, but this is worth pinning as an explicit
# invariant rather than trusting that implementation detail silently.
testthat::test_that("REGRESSION: hex_id stays unique even when the boundary has a hole", {
  skip_unless_spatial()
  outer <- base::rbind(c(-79, 36), c(-77, 36), c(-77, 38), c(-79, 38), c(-79, 36))
  hole <- base::rbind(c(-78.6, 36.6), c(-77.4, 36.6), c(-77.4, 37.4), c(-78.6, 37.4), c(-78.6, 36.6))
  region_with_hole <- sf::st_sf(geometry = sf::st_sfc(
    sf::st_polygon(list(outer, hole[base::nrow(hole):1, ])), crs = 4326
  ))
  locations <- mm_points(
    c("a", "b", "a", "b"), c(2013L, 2013L, 2023L, 2023L), c(100, 300, 100, 300),
    c(20, 80, 40, 100), x = c(-78.9, -77.1, -78.9, -77.1), y = c(36.1, 37.9, 36.1, 37.9)
  )
  mapped <- mysterymaps_hex_access_maps(locations, region_with_hole, hex_km = 50)
  testthat::expect_identical(base::anyDuplicated(mapped$hexagons$hex_id), 0L)
})

# ---- Saboteur 9: non-POINT geometry must be rejected, not silently coerced -
testthat::test_that("non-POINT origin geometry errors with a clear message", {
  skip_unless_spatial()
  bad <- sf::st_sf(
    origin_id = "a", year = 2013L, population = 1, travel_minutes = 10,
    geometry = sf::st_sfc(
      sf::st_linestring(base::rbind(c(-78, 37), c(-78.1, 37.1))), crs = 4326
    )
  )
  testthat::expect_error(
    mysterymaps_hex_access_maps(bad, mm_region(), hex_km = 300),
    "POINT"
  )
})

# ---- Saboteur 10: minimal valid input (one origin per year) ----------------
testthat::test_that("a single origin per comparison year builds without error", {
  skip_unless_spatial()
  locations <- mm_points(
    c("a", "a"), c(2013L, 2023L), c(100, 100), c(20, 40), x = c(-78, -78), y = c(37, 37)
  )
  mapped <- mysterymaps_hex_access_maps(locations, mm_region(), hex_km = 300)
  testthat::expect_s3_class(mapped$travel_map, "ggplot")
  testthat::expect_equal(base::nrow(mapped$summaries), 2L)
})

# ---- Saboteur 11: degenerate/tiny boundary still produces a usable grid ----
testthat::test_that("a boundary smaller than one hex cell still builds (coarse single-cell grid), not an empty-grid crash", {
  skip_unless_spatial()
  tiny_region <- sf::st_sf(geometry = sf::st_as_sfc(
    sf::st_bbox(c(xmin = -78.001, ymin = 37, xmax = -78.0005, ymax = 37.0005), crs = sf::st_crs(4326))
  ))
  locations <- mm_points(
    c("a", "a"), c(2013L, 2023L), c(100, 100), c(20, 40),
    x = c(-78.00075, -78.00075), y = c(37.00025, 37.00025)
  )
  mapped <- mysterymaps_hex_access_maps(locations, tiny_region, hex_km = 500)
  testthat::expect_true(base::nrow(mapped$hexagons) >= 1L)
})

# ---- Saboteur 12: no origin points fall within the boundary at all --------
testthat::test_that("origins entirely outside the boundary error clearly rather than building an empty map", {
  skip_unless_spatial()
  locations <- mm_points(
    c("a", "a"), c(2013L, 2023L), c(100, 100), c(20, 40), x = c(10, 10), y = c(10, 10)
  )
  testthat::expect_error(
    mysterymaps_hex_access_maps(locations, mm_region(), hex_km = 300),
    "within boundary"
  )
})

# ---- Saboteur 13: negative travel_minutes must fail closed -----------------
testthat::test_that("negative travel time errors instead of silently entering the weighted mean", {
  skip_unless_spatial()
  locations <- mm_points(
    c("a", "b", "a", "b"), c(2013L, 2013L, 2023L, 2023L), c(100, 300, 100, 300),
    c(-5, 80, 40, 100), x = c(-78, -78.01, -78, -78.01), y = c(37, 37.01, 37, 37.01)
  )
  testthat::expect_error(
    mysterymaps_hex_access_maps(locations, mm_region(), hex_km = 300),
    "Invalid population or travel"
  )
})

# ---- Saboteur 14: a non-projected (longlat) crs argument must be rejected --
testthat::test_that("passing a longlat crs (e.g. 4326) for the equal-area grid errors instead of silently building a distorted grid", {
  skip_unless_spatial()
  locations <- mm_points(
    c("a", "a"), c(2013L, 2023L), c(100, 100), c(20, 40), x = c(-78, -78), y = c(37, 37)
  )
  testthat::expect_error(
    mysterymaps_hex_access_maps(locations, mm_region(), hex_km = 300, crs = 4326),
    "projected"
  )
})

# ---- Saboteur 15: origins already carries a column named "hex_id" ---------
# REAL BUG, FIXED. sf::st_join() does not error on a colliding column name --
# it silently renames BOTH copies ("hex_id.x", "hex_id.y"), so the join
# itself always "succeeds". The failure only surfaced several steps later,
# as a confusing dplyr error ("Column `hex_id` not found") from inside
# .hex_access_assign_hexagons()'s arrange()/distinct() call, which never
# named the real cause: a reserved internal column name collision.
testthat::test_that("REGRESSION: a pre-existing 'hex_id' column in origins errors clearly instead of a downstream dplyr crash", {
  skip_unless_spatial()
  locations <- mm_points(
    c("a", "b", "a", "b"), c(2013L, 2013L, 2023L, 2023L), c(100, 300, 100, 300),
    c(20, 80, 40, 100), x = c(-78, -78.01, -78, -78.01), y = c(37, 37.01, 37, 37.01),
    extra = list(hex_id = c(999L, 998L, 999L, 998L))
  )
  testthat::expect_error(
    mysterymaps_hex_access_maps(locations, mm_region(), hex_km = 300),
    "hex_id"
  )
})

# ---- Saboteur 16: a zero-row (or all-empty-geometry) boundary ---------------
# REAL BUG, FIXED. A 0-row boundary has no bounding box (NA, not an error),
# and sf::st_make_grid() did not notice -- it failed several steps later
# inside base::seq() with "'from' must be a finite number", naming neither
# the boundary nor the real cause.
testthat::test_that("REGRESSION: a zero-row boundary errors clearly instead of a cryptic seq() failure", {
  skip_unless_spatial()
  empty_boundary <- sf::st_sf(geometry = sf::st_sfc(crs = 4326))
  locations <- mm_points(
    c("a", "a"), c(2013L, 2023L), c(100, 100), c(20, 40), x = c(-78, -78), y = c(37, 37)
  )
  testthat::expect_error(
    mysterymaps_hex_access_maps(locations, empty_boundary, hex_km = 300),
    "boundary"
  )
})

testthat::test_that("a boundary with an empty-geometry row mixed in among valid rows still builds", {
  skip_unless_spatial()
  mixed_boundary <- sf::st_sf(geometry = sf::st_sfc(
    sf::st_polygon(), sf::st_as_sfc(sf::st_bbox(c(xmin = -79, ymin = 36, xmax = -77, ymax = 38)))[[1]],
    crs = 4326
  ))
  locations <- mm_points(
    c("a", "a"), c(2013L, 2023L), c(100, 100), c(20, 40), x = c(-78, -78), y = c(37, 37)
  )
  mapped <- mysterymaps_hex_access_maps(locations, mixed_boundary, hex_km = 300)
  testthat::expect_true(base::nrow(mapped$hexagons) >= 1L)
})
