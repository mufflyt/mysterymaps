# SPEC sections 24 and 25: map semantics and classification metamorphism.
#
# A map that renders can still be scientifically wrong. Everything here tests
# the object BEFORE rendering -- the join, the keys, the breaks, the legend --
# and then renders it, because a constructor that returns a ggplot is not
# evidence that a map exists.

skip_no_leaflet <- function() skip_if_not_installed("leaflet")

# The colours a leaflet choropleth actually painted, in row order.
#
# leaflet::addPolygons records (data, layerId, group, options, ...), and
# fillColor lives inside the options list rather than as a positional
# argument. Reading position 4 wholesale returns the options list itself,
# which is how this helper first reported 16 colours for 6 counties.
fill_colours <- function(m, i = 1L) {
  args <- mm_call_args(m, "addPolygons", i)
  opts <- args[[4]]
  unname(unlist(opts$fillColor))
}

# ---------------------------------------------------------------------------
# Breakpoints: exhaustive, mutually exclusive, correctly closed
# ---------------------------------------------------------------------------

test_that("every value lands in exactly one class", {
  # Exhaustive and mutually exclusive. A value that matches no class comes back
  # NA and renders transparent; a value matching two is a coding error that
  # findInterval hides.
  vals <- c(0, 0.4, 1, 2.5, 7, 19, 250)
  sc <- mysterymaps_jenks_zero_scale(vals, k = 4)
  cols <- sc$color(vals)

  expect_length(cols, length(vals))
  expect_false(anyNA(cols))
  expect_true(all(cols %in% sc$leg_cols))
})

test_that("the legend has exactly one entry per distinct class colour", {
  # A legend describing a transformation the map did not perform is worse than
  # no legend.
  vals <- c(0, 1, 2, 5, 9, 40)
  sc <- mysterymaps_jenks_zero_scale(vals, k = 4)
  expect_length(sc$leg_cols, length(sc$leg_labs))
  expect_equal(length(unique(sc$leg_cols)), length(sc$leg_cols))
  expect_true(all(sc$color(vals) %in% sc$leg_cols))
})

test_that("a value exactly on a breakpoint enters the documented interval", {
  # Interval closure is where a classification silently shifts a county one
  # class up or down. findInterval(rightmost.closed, all.inside) means
  # [lo, hi) everywhere except the final class, which is [lo, hi].
  vals <- c(0, 1, 2, 3, 4, 5, 6, 7, 8, 100)
  sc <- mysterymaps_jenks_zero_scale(vals, k = 3)
  brks <- classInt::classIntervals(vals[vals > 0], n = 3, style = "jenks")$brks
  brks <- unique(brks)

  # Each interior break belongs to the class ABOVE it, not below.
  for (b in brks[-c(1, length(brks))]) {
    just_below <- sc$color(b - 1e-9)
    at_break   <- sc$color(b)
    expect_false(identical(just_below, at_break),
                 info = sprintf("break %s must open a new class", b))
  }
  # The maximum belongs to the top class rather than falling off the end.
  expect_identical(sc$color(max(vals)), sc$leg_cols[[length(sc$leg_cols)]])
})

test_that("breakpoints are ordered", {
  vals <- c(0, 1, 3, 7, 15, 60, 400)
  brks <- unique(classInt::classIntervals(vals[vals > 0], n = 4,
                                          style = "jenks")$brks)
  expect_false(is.unsorted(brks))
})

# ---------------------------------------------------------------------------
# Classification metamorphism (SPEC 25)
# ---------------------------------------------------------------------------

test_that("classification is invariant to input row order", {
  vals <- c(0, 1, 2.5, 7, 19, 44, 250)
  base <- mysterymaps_jenks_zero_scale(vals, k = 4)

  mm_for_each_seed(mm_property_n(8L), function(seed) {
    shuffled <- sample(vals)
    perm <- mysterymaps_jenks_zero_scale(shuffled, k = 4)
    # Same classes, and each value keeps its colour regardless of position.
    expect_equal(perm$leg_cols, base$leg_cols)
    expect_equal(perm$leg_labs, base$leg_labs)
    expect_equal(perm$color(vals), base$color(vals))
  })
})

test_that("constant input produces one class for every geography", {
  sc <- mysterymaps_jenks_zero_scale(rep(4, 6))
  cols <- sc$color(rep(4, 6))
  expect_length(unique(cols), 1L)
})

test_that("an all-zero column is a map of observed zeros, not an error", {
  sc <- mysterymaps_jenks_zero_scale(rep(0, 8))
  expect_identical(unique(sc$color(rep(0, 8))), "#e0e0e0")
  expect_identical(sc$leg_labs, "0")
})

test_that("one extreme outlier does not collapse every other class", {
  # Jenks is chosen precisely because a single 4,000 must not push the other
  # 3,108 counties into one bin.
  vals <- c(0, 1, 2, 3, 4, 5, 6, 7, 8, 4000)
  sc <- mysterymaps_jenks_zero_scale(vals, k = 5)
  cols <- sc$color(vals[vals > 0 & vals < 4000])
  expect_gt(length(unique(cols)), 1L)
})

test_that("adding NAs does not move any observed value between classes", {
  # The metamorphic form of the zero-vs-missing gate: making data MORE
  # incomplete must not recolour the parts that were measured.
  vals <- c(0, 1, 4, 9, 25, 90)
  base <- mysterymaps_jenks_zero_scale(vals, k = 4)
  gappy <- mysterymaps_jenks_zero_scale(c(vals, NA, NA, NA), k = 4)
  expect_equal(gappy$color(vals), base$color(vals))
})

test_that("equal values receive equal classes, deterministically", {
  # If national ranking is a reported finding, ties must not reorder.
  vals <- c(0, 5, 5, 5, 12, 12, 40)
  sc <- mysterymaps_jenks_zero_scale(vals, k = 3)
  expect_length(unique(sc$color(c(5, 5, 5))), 1L)
  expect_length(unique(sc$color(c(12, 12))), 1L)
})

# ---------------------------------------------------------------------------
# The join (SPEC 24)
# ---------------------------------------------------------------------------

test_that("the county join multiplies no features", {
  # A join that duplicates rows draws the same county twice, doubling its
  # apparent supply and its ink.
  skip_no_leaflet()
  cty <- mm_counties(6)
  m <- mysterymaps_county_access_map(cty, "rate", "tooltip", "profile",
                                     notes = NULL, search = NULL, mesh = FALSE)
  expect_length(fill_colours(m), nrow(cty))
})

test_that("every supplied geography is represented, and no other", {
  skip_no_leaflet()
  cty <- mm_counties(6)
  m <- mysterymaps_county_access_map(cty, "rate", "tooltip", "profile",
                                     notes = NULL, search = NULL, mesh = FALSE)
  sc <- mysterymaps_jenks_zero_scale(cty$rate, k = 6, digits = 1)
  expect_equal(fill_colours(m), sc$color(cty$rate))
})

test_that("geographic keys are unique before the map is built", {
  # Duplicate GEOIDs are the mechanism by which a join multiplies features.
  cty <- mm_counties(6)
  expect_equal(anyDuplicated(cty$GEOID), 0L)
})

test_that("the choropleth legend describes the scale the map used", {
  skip_no_leaflet()
  cty <- mm_counties(6)
  m <- mysterymaps_county_access_map(cty, "rate", "tooltip", "profile",
                                     legend_title = "Providers per 1,000",
                                     notes = NULL, search = NULL)
  legend <- mm_call_args(m, "addLegend")
  flat <- unlist(legend)
  sc <- mysterymaps_jenks_zero_scale(cty$rate, k = 6, digits = 1)
  expect_true(all(sc$leg_cols %in% flat))
  expect_true("Providers per 1,000" %in% flat)
})

test_that("a value column of all NA does not silently produce a blank map", {
  # The join-against-the-wrong-key signature. It must be visible in the legend
  # as no-data rather than rendered as a nationwide observed zero.
  skip_no_leaflet()
  cty <- mm_counties(6)
  cty$rate <- NA_real_
  m <- mysterymaps_county_access_map(cty, "rate", "tooltip", "profile",
                                     notes = NULL, search = NULL)
  flat <- unlist(mm_call_args(m, "addLegend"))
  expect_true(any(grepl("No data", flat, fixed = TRUE)))
})

test_that("the map is built from the requested value column, not a neighbour", {
  # Two numeric columns; picking the wrong one produces a perfectly plausible
  # and completely different map.
  skip_no_leaflet()
  cty <- mm_counties(6)
  cty$decoy <- rev(cty$rate)
  m <- mysterymaps_county_access_map(cty, "rate", "tooltip", "profile",
                                     notes = NULL, search = NULL, mesh = FALSE)
  by_rate  <- mysterymaps_jenks_zero_scale(cty$rate,  k = 6, digits = 1)
  by_decoy <- mysterymaps_jenks_zero_scale(cty$decoy, k = 6, digits = 1)
  expect_equal(fill_colours(m), by_rate$color(cty$rate))
  expect_false(isTRUE(all.equal(fill_colours(m), by_decoy$color(cty$decoy))))
})

test_that("coverage bands are mutually exclusive base groups, not overlays", {
  # Stacking translucent surfaces over a choropleth multiplies two colour
  # scales and yields a third belonging to neither.
  skip_no_leaflet()
  cty <- mm_counties(6)
  m <- mysterymaps_county_access_map(
    cty, "rate", "tooltip", "profile", notes = NULL, search = NULL,
    coverage = list("Within 30 minutes" = mm_surface(),
                    "Within 60 minutes" = mm_surface(w = 6)),
    coverage_colors = c("#08519c", "#3182bd"))

  ctl <- mm_call_args(m, "addLayersControl")
  base_groups <- unlist(ctl[[1]])
  expect_true(all(c("Within 30 minutes", "Within 60 minutes") %in% base_groups))
})

# ---------------------------------------------------------------------------
# The legend must describe the transformation the map actually performed
# ---------------------------------------------------------------------------
#
# Added because the mutation assault found this blind spot. Reversing the
# colour ramp (`cols <- rev(palette(k))`) SURVIVED the suite as written.
#
# Every existing ordering test compared a value's colour against `leg_cols`
# by position -- and reversing the palette reverses `leg_cols` too, so the
# positions still lined up and the tests stayed green. What does NOT reverse is
# the LABEL vector: labels are built from the break intervals in ascending
# order. So the map painted the highest-supply counties in the colour the
# legend captioned "1-4", and the lowest in the colour captioned "20-90".
#
# There is no error, the classes are still mutually exclusive and exhaustive,
# the ranking is still monotone in colour-space, and the map is exactly wrong.
# The only way to catch it is to tie each value's colour to the TEXT of the
# legend entry it received.

# Parse "1", "1-4", "0.0-2.5" (en dash) into c(lo, hi).
parse_legend_range <- function(label) {
  txt <- gsub("–", "-", label)
  if (!grepl("-", txt, fixed = TRUE)) {
    v <- suppressWarnings(as.numeric(txt))
    return(c(v, v))
  }
  parts <- suppressWarnings(as.numeric(strsplit(txt, "-", fixed = TRUE)[[1]]))
  parts[!is.na(parts)][1:2]
}

test_that("REGRESSION: a value's colour matches the legend entry that DESCRIBES it", {
  # MUTANT KILL: palette_reversed.
  vals <- c(0, 1, 2, 4, 7, 12, 20, 33, 51, 90)

  for (k in c(3L, 5L)) {
    sc <- mysterymaps_jenks_zero_scale(vals, k = k)
    positive <- vals[vals > 0]

    for (v in positive) {
      idx <- match(sc$color(v), sc$leg_cols)
      expect_false(is.na(idx),
                   label = sprintf("value %s got a colour not in the legend", v))

      rng <- parse_legend_range(sc$leg_labs[[idx]])
      expect_false(anyNA(rng),
                   label = sprintf("legend label '%s' is unparseable",
                                   sc$leg_labs[[idx]]))

      # The value must lie inside the interval its own legend line claims.
      # Break endpoints are rounded for display, so allow the label's own
      # rounding slack rather than demanding exactness.
      expect_true(v >= rng[1] - 1 && v <= rng[2] + 1,
                  label = sprintf(
                    "k=%d: value %s was painted the colour labelled '%s'",
                    k, v, sc$leg_labs[[idx]]))
    }
  }
})

test_that("REGRESSION: the darkest and lightest classes are not swapped", {
  # The same failure stated in the crudest possible way, as a backstop that
  # survives any future change to label formatting: the colour given to the
  # smallest positive value must be the FIRST positive legend colour, and the
  # colour given to the largest must be the LAST.
  vals <- c(0, 1, 2, 4, 7, 12, 20, 33, 51, 90)
  sc <- mysterymaps_jenks_zero_scale(vals, k = 4)
  positive <- sort(vals[vals > 0])

  # leg_cols is c(zero, positive classes ascending[, no-data]).
  first_positive <- sc$leg_cols[[2]]
  last_positive <- sc$leg_cols[[length(sc$leg_cols) - as.integer(("No data" %in% sc$leg_labs))]]

  expect_identical(sc$color(min(positive)), first_positive)
  expect_identical(sc$color(max(positive)), last_positive)
  expect_false(identical(first_positive, last_positive))
})
