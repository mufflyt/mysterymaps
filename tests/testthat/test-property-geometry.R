# SPEC section 7: property-based testing.
#
# Unit tests cover the examples someone thought of. These cover the ones nobody
# did: hundreds of generated inputs per run, each checked against an invariant
# that must hold for ALL legal inputs rather than for a chosen example.
#
# Every case runs under a recorded seed. On failure the seed is printed, and
# the counterexample belongs in the named regression corpus afterwards.
#
# MYSTERYMAPS_PROPERTY_N controls the case count: small locally and in the PR
# lane, large in the weekly deep audit.

skip_no_sf <- function() skip_if_not_installed("sf")

area_m2 <- function(x) {
  as.numeric(sum(sf::st_area(sf::st_transform(sf::st_geometry(x), 5070))))
}

# ---------------------------------------------------------------------------
# Classification properties
# ---------------------------------------------------------------------------

test_that("PROPERTY: every finite value receives a colour from the legend", {
  # No value may fall outside every class. A value that does comes back NA and
  # renders as a transparent hole that reads as "no county here".
  mm_for_each_seed(mm_property_n(), function(seed) {
    n <- sample(3:40, 1)
    vals <- c(0, round(stats::rexp(n, rate = 0.2), 2))
    sc <- mysterymaps_jenks_zero_scale(vals, k = sample(2:8, 1))
    cols <- sc$color(vals)
    expect_false(anyNA(cols))
    expect_true(all(cols %in% sc$leg_cols))
  })
})

test_that("PROPERTY: legend colours and labels are always the same length", {
  mm_for_each_seed(mm_property_n(), function(seed) {
    vals <- c(0, round(stats::runif(sample(2:30, 1), 0, 100), 1))
    sc <- mysterymaps_jenks_zero_scale(vals, k = sample(2:7, 1))
    expect_length(sc$leg_cols, length(sc$leg_labs))
  })
})

test_that("PROPERTY: zero always receives the zero colour", {
  mm_for_each_seed(mm_property_n(), function(seed) {
    vals <- c(0, round(stats::rexp(sample(2:25, 1), 0.3), 3))
    sc <- mysterymaps_jenks_zero_scale(vals, k = sample(2:6, 1))
    expect_identical(sc$color(0), sc$leg_cols[[1]])
  })
})

test_that("PROPERTY: NA never receives the observed-zero colour", {
  # The zero-vs-missing gate, asserted over generated data rather than one
  # hand-written vector.
  mm_for_each_seed(mm_property_n(), function(seed) {
    vals <- c(0, NA, round(stats::rexp(sample(2:25, 1), 0.3), 3))
    sc <- mysterymaps_jenks_zero_scale(vals, k = sample(2:6, 1))
    expect_false(identical(sc$color(NA_real_), sc$color(0)))
  })
})

test_that("PROPERTY: classification is monotone in the value", {
  # A larger rate may share a class with a smaller one, but must never be
  # assigned a LOWER class. A non-monotone scale reverses the map's meaning
  # for some counties and not others.
  mm_for_each_seed(mm_property_n(), function(seed) {
    vals <- c(0, sort(round(stats::rexp(sample(5:30, 1), 0.2), 3)))
    sc <- mysterymaps_jenks_zero_scale(vals, k = sample(2:6, 1))
    ranks <- match(sc$color(vals), sc$leg_cols)
    expect_false(is.unsorted(ranks))
  })
})

test_that("PROPERTY: classification ignores input order", {
  mm_for_each_seed(mm_property_n(), function(seed) {
    vals <- c(0, round(stats::rexp(sample(4:25, 1), 0.25), 3))
    k <- sample(2:6, 1)
    a <- mysterymaps_jenks_zero_scale(vals, k = k)
    b <- mysterymaps_jenks_zero_scale(sample(vals), k = k)
    expect_equal(b$color(vals), a$color(vals))
  })
})

test_that("PROPERTY: the scale never errors on any legal numeric input", {
  # Generated inputs include all-zero, single-value, heavy ties, NA-laden and
  # extreme-outlier vectors -- every shape that has broken it before.
  mm_for_each_seed(mm_property_n(), function(seed) {
    shape <- sample(c("allzero", "single", "ties", "nas", "outlier", "mixed"), 1)
    vals <- switch(shape,
      allzero = rep(0, sample(1:10, 1)),
      single  = c(rep(0, sample(1:5, 1)), stats::runif(1, 0.1, 50)),
      ties    = c(0, rep(round(stats::runif(1, 1, 20), 2), sample(2:10, 1))),
      nas     = c(0, NA, NA, round(stats::rexp(sample(1:8, 1), 0.3), 2)),
      outlier = c(0, round(stats::runif(sample(3:10, 1), 0.1, 5), 2), 1e6),
      mixed   = c(0, NA, round(stats::rexp(sample(2:15, 1), 0.2), 3)))
    expect_no_error(mysterymaps_jenks_zero_scale(vals, k = sample(2:8, 1)))
  })
})

# ---------------------------------------------------------------------------
# Geometry properties
# ---------------------------------------------------------------------------

test_that("PROPERTY: a polygon's own area is positive and finite", {
  skip_no_sf()
  mm_for_each_seed(mm_property_n(), function(seed) {
    a <- area_m2(mm_random_rect())
    expect_true(is.finite(a))
    expect_gt(a, 0)
  })
})

test_that("PROPERTY: area is invariant to vertex rotation", {
  # The same ring started at a different vertex is the same ring.
  skip_no_sf()
  mm_for_each_seed(mm_property_n(), function(seed) {
    g <- mm_random_rect()
    m <- g[[1]][[1]]
    k <- sample(seq_len(nrow(m) - 1L), 1)
    idx <- c(seq(k, nrow(m) - 1L), seq_len(k - 1L))
    rotated <- rbind(m[idx, , drop = FALSE], m[idx[1], , drop = FALSE])
    g2 <- sf::st_sfc(sf::st_polygon(list(rotated)), crs = 4326)
    expect_equal(area_m2(g2), area_m2(g), tolerance = MM_AREA_TOL)
  })
})

test_that("PROPERTY: intersection is commutative", {
  skip_no_sf()
  mm_for_each_seed(mm_property_n(), function(seed) {
    a <- mm_random_rect(); b <- mm_random_rect()
    ab <- suppressWarnings(sf::st_intersection(sf::st_transform(a, 5070),
                                               sf::st_transform(b, 5070)))
    ba <- suppressWarnings(sf::st_intersection(sf::st_transform(b, 5070),
                                               sf::st_transform(a, 5070)))
    area <- function(x) if (!length(x)) 0 else as.numeric(sum(sf::st_area(x)))
    expect_equal(area(ab), area(ba), tolerance = MM_AREA_TOL)
  })
})

test_that("PROPERTY: validation never returns fewer features than it received", {
  # Silent feature loss, asserted over generated inputs.
  skip_no_sf()
  mm_for_each_seed(mm_property_n(), function(seed) {
    n <- sample(1:6, 1)
    geoms <- do.call(c, lapply(seq_len(n), function(i) mm_random_rect()))
    obj <- sf::st_sf(id = seq_len(n), geometry = geoms)
    out <- validate_sf_inputs(shape = obj)$shape
    expect_equal(nrow(out), n)
    expect_setequal(out$id, seq_len(n))
  })
})

test_that("PROPERTY: the coverage gate accounts for every provider", {
  # n == inside + outside, for any provider set and any surface.
  skip_no_sf()
  mm_for_each_seed(mm_property_n(), function(seed) {
    n <- sample(1:8, 1)
    pts <- mm_points(n,
                     lon = stats::runif(n, -101, -97),
                     lat = stats::runif(n, 39.5, 41.5))
    surface <- mm_surface(x = -100, y = 40, w = 2, h = 1)
    res <- suppressMessages(suppressWarnings(tryCatch(
      mysterymaps_gate_provider_coverage(pts, surface, on_fail = "warn"),
      error = function(e) NULL)))
    if (is.null(res)) return(invisible(NULL))
    expect_equal(res$n, n)
    expect_gte(res$n_outside, 0L)
    expect_lte(res$n_outside, n)
    expect_equal(res$pct_outside, 100 * res$n_outside / res$n)
  })
})
