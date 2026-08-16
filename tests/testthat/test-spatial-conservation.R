# SPEC section 21: area conservation.
#
# Algebraic identities are the hardest thing for subtly broken spatial code to
# evade. A function can return plausible numbers for every hand-written example
# and still violate `intersection <= min(parents)` on the one input that
# matters. These identities hold for all valid inputs or the code is wrong.
#
# All areas are measured in square metres after projection to EPSG:5070, the
# equal-area CRS the package itself uses. Measuring in degrees is the specific
# error these tests exist to catch: it makes a Texas polygon and a North Dakota
# polygon of identical shape differ by roughly 30%.

skip_no_sf <- function() skip_if_not_installed("sf")

# Area in square metres, always via the equal-area projection.
mm_area <- function(x) {
  as.numeric(sum(sf::st_area(sf::st_transform(sf::st_geometry(x), 5070))))
}

# No sf_use_s2() toggling here: both operands are transformed to EPSG:5070
# first, and s2 applies only to geographic coordinates. Toggling per call was
# pure overhead, and mutating global spatial state inside a helper is the very
# thing test-state-leakage.R exists to catch.
mm_intersect_area <- function(a, b) {
  i <- suppressWarnings(sf::st_intersection(
    sf::st_transform(sf::st_geometry(a), 5070),
    sf::st_transform(sf::st_geometry(b), 5070)))
  if (!length(i)) return(0)
  as.numeric(sum(sf::st_area(i)))
}

test_that("intersection area is never negative", {
  skip_no_sf()
  mm_for_each_seed(mm_property_n(), function(seed) {
    a <- mm_random_rect(); b <- mm_random_rect()
    expect_gte(mm_intersect_area(a, b), 0)
  })
})

test_that("intersection area never exceeds either parent", {
  # The identity that catches an area computed in the wrong units, or an
  # intersection accidentally implemented as a union.
  skip_no_sf()
  mm_for_each_seed(mm_property_n(), function(seed) {
    a <- mm_random_rect(); b <- mm_random_rect()
    i <- mm_intersect_area(a, b)
    expect_lte(i, mm_area(a) * (1 + MM_AREA_TOL))
    expect_lte(i, mm_area(b) * (1 + MM_AREA_TOL))
  })
})

test_that("A intersect A equals A", {
  skip_no_sf()
  mm_for_each_seed(mm_property_n(), function(seed) {
    a <- mm_random_rect()
    expect_equal(mm_intersect_area(a, a), mm_area(a), tolerance = MM_AREA_TOL)
  })
})

test_that("disjoint polygons have exactly zero overlap", {
  skip_no_sf()
  a <- mm_rect(-100, 40, -99, 41)
  b <- mm_rect(-80, 30, -79, 31)
  expect_equal(mm_intersect_area(a, b), 0)
})

test_that("a contained polygon intersects to exactly its own area", {
  # The identity that catches a swapped numerator and denominator: if B lies
  # wholly inside A, the intersection IS B.
  skip_no_sf()
  outer <- mm_rect(-100, 40, -96, 44)
  inner <- mm_rect(-99, 41, -98, 42)
  expect_equal(mm_intersect_area(outer, inner), mm_area(inner),
               tolerance = MM_AREA_TOL)
})

test_that("union area is never smaller than either component", {
  skip_no_sf()
  mm_for_each_seed(mm_property_n(), function(seed) {
    a <- mm_random_rect(); b <- mm_random_rect()
    u <- sf::st_union(sf::st_transform(a, 5070), sf::st_transform(b, 5070))
    ua <- as.numeric(sum(sf::st_area(u)))
    expect_gte(ua, mm_area(a) * (1 - MM_AREA_TOL))
    expect_gte(ua, mm_area(b) * (1 - MM_AREA_TOL))
  })
})

test_that("a partition conserves area: the parts sum to the whole", {
  # Cut one polygon into mutually exclusive strips and intersect each with the
  # original. The sum must reconstruct the original area. This is the identity
  # that a dropped feature or a double-counted sliver cannot survive.
  #
  # Built directly in EPSG:5070 rather than in lon/lat. A rectangle defined by
  # four lon/lat corners reprojects to a quadrilateral with straight edges
  # between those corners; a strip cut from it reprojects to straight edges
  # between DIFFERENT corners. The two do not tile exactly, and the ~0.2%
  # shortfall is a densification artifact of the fixture, not a defect in the
  # code under test. Partitioning in the measurement CRS removes the artifact
  # and leaves the identity exact.
  skip_no_sf()
  whole <- mm_rect(-500000, 1800000, 500000, 2600000, crs = 5070)
  cuts <- seq(-500000, 500000, length.out = 5)
  parts <- lapply(seq_len(length(cuts) - 1L), function(i) {
    mm_rect(cuts[i], 1800000, cuts[i + 1L], 2600000, crs = 5070)
  })

  total <- sum(vapply(parts, function(p) mm_intersect_area(whole, p), numeric(1)))
  expect_equal(total, mm_area(whole), tolerance = MM_AREA_TOL)
})

test_that("DOCUMENTED: a lon/lat partition does NOT conserve area, and why", {
  # Measured, not assumed: partitioning the same rectangle in geographic
  # coordinates loses 0.26% of its area, and that gap is CONSTANT under
  # densification -- 100 km and 2 km give the identical error. So it is not a
  # sampling artifact that a finer mesh would remove.
  #
  # It is geodesy. Edges are treated as great circles, and a great circle
  # across 4 degrees of longitude bows further from the parallel than four
  # great circles across 1 degree each do. A "rectangle" in lon/lat is
  # therefore not the union of its lon/lat sub-rectangles.
  #
  # This is precisely why mysterymaps measures in EPSG:5070 rather than in
  # degrees: the same partition IS exact there (previous test). A national
  # coverage figure assembled from per-state lon/lat pieces would carry this
  # error, and it varies with latitude, so it would read as a north-south
  # gradient in the workforce.
  skip_no_sf()

  partition_error <- function(km) {
    step <- units::set_units(km, "km")
    whole <- sf::st_segmentize(mm_rect(-100, 40, -96, 44), dfMaxLength = step)
    cuts <- seq(-100, -96, length.out = 5)
    parts <- lapply(seq_len(4L), function(i) {
      sf::st_segmentize(mm_rect(cuts[i], 40, cuts[i + 1L], 44),
                        dfMaxLength = step)
    })
    total <- sum(vapply(parts, function(p) mm_intersect_area(whole, p),
                        numeric(1)))
    abs(total - mm_area(whole)) / mm_area(whole)
  }

  coarse <- partition_error(100)
  fine   <- partition_error(10)

  # Small, but real: well below anything that could move a map class, and far
  # above floating-point noise.
  expect_gt(coarse, 1e-4)
  expect_lt(coarse, 1e-2)

  # And flat: refining the mesh tenfold changes the error by 2 parts per
  # million (2.640632e-3 -> 2.640637e-3). A sampling artifact would shrink by
  # orders of magnitude; this does not move. That is the evidence that the gap
  # is geodesy rather than discretisation.
  expect_equal(fine, coarse, tolerance = 1e-4)
})

test_that("REGRESSION: densification units are stated, not inferred", {
  # dfMaxLength carries UNITS. On a geographic CRS sf reads a bare number as
  # METRES, so `dfMaxLength = 0.05` -- written meaning 0.05 degrees --
  # densified one rectangle to 50,331,649 vertices and took the whole suite to
  # 9.8 GB. Guard the fixture so that cannot come back.
  skip_no_sf()
  seg <- sf::st_segmentize(mm_rect(-100, 40, -96, 44),
                           dfMaxLength = units::set_units(10, "km"))
  expect_lt(nrow(sf::st_coordinates(seg)), 1000L)
})

test_that("mysterymaps_calculate_overlap conserves block-group area", {
  # The package's own overlap numbers, not a hand-rolled reimplementation:
  # each block group's intersected area must not exceed its own area.
  skip_no_sf()
  out <- withr::local_tempdir()
  bg <- mm_block_groups(4)
  suppressWarnings(suppressMessages(
    mysterymaps_calculate_overlap(bg, mm_isochrones(), 30, out)))

  tbl <- utils::read.csv(file.path(out, "intersect_30_minutes.csv"),
                         colClasses = c(GEOID = "character"))
  bg_area <- vapply(seq_len(nrow(bg)), function(i) mm_area(bg[i, ]), numeric(1))
  names(bg_area) <- bg$GEOID

  for (i in seq_len(nrow(tbl))) {
    expect_lte(tbl$intersect_area[i],
               bg_area[[as.character(tbl$GEOID[i])]] * (1 + 1e-6))
    expect_gte(tbl$intersect_area[i], 0)
  }
})

test_that("overlap proportion is bounded by 0 and 1", {
  # An overlap above 1 means area was double counted; below 0 means a sign
  # error. Either produces a choropleth that looks fine.
  skip_no_sf()
  out <- withr::local_tempdir()
  suppressWarnings(suppressMessages(
    mysterymaps_calculate_overlap(mm_block_groups(4), mm_isochrones(), 30, out)))

  tbl <- utils::read.csv(file.path(out, "intersect_30_minutes.csv"),
                         colClasses = c(GEOID = "character"))
  bg <- mm_block_groups(4)
  for (i in seq_len(nrow(tbl))) {
    a <- mm_area(bg[bg$GEOID == as.character(tbl$GEOID[i]), ])
    prop <- tbl$intersect_area[i] / a
    expect_gte(prop, 0)
    expect_lte(prop, 1 + 1e-6)
  }
})

test_that("a fully covered block group reports complete overlap", {
  # The analytic case with a known answer: an isochrone covering everything
  # must give every block group an overlap of 1, not 0.999 and not 1.4.
  skip_no_sf()
  out <- withr::local_tempdir()
  bg <- mm_block_groups(3)
  everything <- sf::st_sf(
    drive_time = 30, data_year = 2020,
    geometry = mm_rect(-105, 35, -90, 45))

  suppressWarnings(suppressMessages(
    mysterymaps_calculate_overlap(bg, everything, 30, out)))
  tbl <- utils::read.csv(file.path(out, "intersect_30_minutes.csv"),
                         colClasses = c(GEOID = "character"))

  for (i in seq_len(nrow(tbl))) {
    a <- mm_area(bg[bg$GEOID == as.character(tbl$GEOID[i]), ])
    expect_equal(tbl$intersect_area[i] / a, 1, tolerance = 1e-6)
  }
})

# ---------------------------------------------------------------------------
# Independent reference implementation (SPEC 19)
# ---------------------------------------------------------------------------
#
# These exist because the mutation assault found them missing. Two
# high-consequence mutants SURVIVED the suite as originally written:
#
#   area_ratio_inverted      overlap = bg_area / intersect_area
#   left_join_becomes_inner  block groups with no overlap vanish
#
# Both survived for the same reason: the `overlap` column is never written to
# any artifact. It exists only to produce two percentile messages, and nothing
# asserted what those numbers actually were -- only that the words "50th
# Percentile" appeared. A test that checks a label rather than a value cannot
# tell a correct pipeline from an inverted one.
#
# The reference below recomputes the percentiles from first principles,
# without calling any package helper, and compares.

mm_reference_overlap <- function(bg, iso, minutes) {
  band <- iso[iso$drive_time == minutes, ]
  band <- sf::st_transform(sf::st_union(band), 5070)
  bg_p <- sf::st_transform(bg, 5070)

  vapply(seq_len(nrow(bg_p)), function(i) {
    one <- sf::st_geometry(bg_p[i, ])
    hit <- suppressWarnings(sf::st_intersection(one, band))
    ia <- if (!length(hit)) 0 else as.numeric(sum(sf::st_area(hit)))
    ia / as.numeric(sf::st_area(one))
  }, numeric(1))
}

# Pull the two percentiles back out of the messages, which is the only place
# the package reports them.
mm_reported_percentiles <- function(bg, iso, minutes, out) {
  msgs <- capture_messages(suppressWarnings(
    mysterymaps_calculate_overlap(bg, iso, minutes, out)))
  grab <- function(which) {
    line <- grep(which, msgs, value = TRUE)
    as.numeric(sub(".*: *([0-9.]+)%.*", "\\1", line[[1]]))
  }
  c(p50 = grab("50th Percentile"), p75 = grab("75th Percentile"))
}

test_that("reported percentiles match an independent reference calculation", {
  # MUTANT KILL: area_ratio_inverted, left_join_becomes_inner.
  skip_no_sf()
  bg <- mm_block_groups(4)
  iso <- mm_isochrones()

  reference <- mm_reference_overlap(bg, iso, 30)
  expected <- c(p50 = unname(round(stats::quantile(reference, 0.5), 4)) * 100,
                p75 = unname(round(stats::quantile(reference, 0.75), 4)) * 100)

  reported <- mm_reported_percentiles(bg, iso, 30, withr::local_tempdir())

  expect_equal(unname(reported[["p50"]]), unname(expected[["p50"]]),
               tolerance = 1e-3)
  expect_equal(unname(reported[["p75"]]), unname(expected[["p75"]]),
               tolerance = 1e-3)
})

test_that("overlap percentiles are proportions, never above 100 percent", {
  # MUTANT KILL: area_ratio_inverted. An inverted ratio is bg_area divided by
  # a smaller intersection, so it exceeds 1 for every partially covered block
  # group and is infinite for every uncovered one. It cannot stay under 100%.
  skip_no_sf()
  reported <- mm_reported_percentiles(mm_block_groups(4), mm_isochrones(), 30,
                                      withr::local_tempdir())
  expect_gte(reported[["p50"]], 0)
  expect_lte(reported[["p50"]], 100)
  expect_gte(reported[["p75"]], 0)
  expect_lte(reported[["p75"]], 100)
  expect_lte(reported[["p50"]], reported[["p75"]])
})

test_that("block groups with NO overlap stay in the denominator", {
  # MUTANT KILL: left_join_becomes_inner.
  #
  # This is the scientifically load-bearing one. Two of these four block groups
  # do not touch the 30-minute surface at all. They are zeros, not absences: a
  # place the drive-time band fails to reach is exactly the finding the map
  # exists to report. Dropping them from the join computes the median over the
  # covered ones only, and coverage rises from 8% to 48% without any error.
  skip_no_sf()
  bg <- mm_block_groups(4)
  reference <- mm_reference_overlap(bg, mm_isochrones(), 30)
  expect_equal(sum(reference == 0), 2L)

  reported <- mm_reported_percentiles(bg, mm_isochrones(), 30,
                                      withr::local_tempdir())

  # Median over all four (two of them zero), not over the two that overlap.
  median_all <- unname(round(stats::quantile(reference, 0.5), 4)) * 100
  median_covered <- unname(round(
    stats::quantile(reference[reference > 0], 0.5), 4)) * 100

  expect_equal(reported[["p50"]], median_all, tolerance = 1e-3)
  expect_false(isTRUE(all.equal(reported[["p50"]], median_covered,
                                tolerance = 1e-3)))
})
