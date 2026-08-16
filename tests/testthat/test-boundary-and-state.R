# SPEC sections 27 (boundary assignment) and 34 (global-state leakage).
#
# Boundary cases decide which geography a provider belongs to. Double-counting
# a provider whose point touches two adjoining polygons inflates national
# supply by exactly the number of providers who live on a border.
#
# Leakage decides whether the answer depends on what ran first. Both produce
# maps that are internally consistent and wrong.

skip_no_sf <- function() skip_if_not_installed("sf")

# Two counties sharing the vertical edge at x = 0.
adjoining <- function() {
  sf::st_sf(GEOID = c("west", "east"),
            geometry = c(mm_rect(-1, 0, 0, 1), mm_rect(0, 0, 1, 1)))
}

point_at <- function(x, y) {
  sf::st_as_sf(data.frame(name = "p", lon = x, lat = y),
               coords = c("lon", "lat"), crs = 4326)
}

n_assigned <- function(p, g) {
  sum(lengths(suppressMessages(sf::st_intersects(p, g))))
}

test_that("a point clearly inside belongs to exactly one geography", {
  skip_no_sf()
  expect_equal(n_assigned(point_at(-0.5, 0.5), adjoining()), 1L)
})

test_that("a point clearly outside belongs to none", {
  skip_no_sf()
  expect_equal(n_assigned(point_at(5, 5), adjoining()), 0L)
})

test_that("a point just inside a boundary stays on its own side", {
  skip_no_sf()
  g <- adjoining()
  west <- suppressMessages(sf::st_intersects(point_at(-1e-9, 0.5), g))[[1]]
  east <- suppressMessages(sf::st_intersects(point_at( 1e-9, 0.5), g))[[1]]
  expect_equal(g$GEOID[west], "west")
  expect_equal(g$GEOID[east], "east")
})

test_that("HAZARD: boundary assignment depends on the global s2 setting", {
  # Found by this suite, and the most order-dependent thing in the spatial
  # stack: a point lying exactly on a shared edge matches ONE polygon under
  # spherical geometry and TWO under planar.
  #
  #   sf_use_s2(TRUE)  -> 1 match   (the edge is assigned to one side)
  #   sf_use_s2(FALSE) -> 2 matches (the closed predicate matches both)
  #
  # So a caller who aggregates providers per geography gets a different
  # national count depending on a global option that some other function may
  # have changed. There is no error and both maps look correct.
  #
  # This is pinned rather than fixed because st_intersects belongs to sf, not
  # to mysterymaps. What mysterymaps owes is a deterministic answer of its own
  # regardless of the caller's setting -- which is the next test.
  skip_no_sf()
  before <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(before)), add = TRUE)

  suppressMessages(sf::sf_use_s2(TRUE))
  spherical <- n_assigned(point_at(0, 0.5), adjoining())

  suppressMessages(sf::sf_use_s2(FALSE))
  planar <- n_assigned(point_at(0, 0.5), adjoining())

  expect_equal(spherical, 1L)
  expect_equal(planar, 2L)
  expect_false(spherical == planar)
})

test_that("the coverage gate answers identically whatever s2 the caller had", {
  # The package-owned guarantee. mysterymaps_gate_provider_coverage() forces
  # s2 off for its own work and restores it, so its verdict cannot depend on
  # whatever the caller's session happened to be set to.
  skip_no_sf()
  before <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(before)), add = TRUE)

  surface <- mm_surface(x = -100, y = 40, w = 2, h = 2)
  edge_provider <- point_at(-100, 41)

  verdicts <- lapply(c(TRUE, FALSE), function(state) {
    suppressMessages(sf::sf_use_s2(state))
    res <- suppressMessages(
      mysterymaps_gate_provider_coverage(edge_provider, surface))
    c(n = res$n, n_outside = res$n_outside)
  })
  expect_equal(verdicts[[1]], verdicts[[2]])
})

test_that("a shared-corner point matches every polygon meeting there", {
  skip_no_sf()
  quad <- sf::st_sf(
    GEOID = c("nw", "ne", "sw", "se"),
    geometry = c(mm_rect(-1, 0, 0, 1), mm_rect(0, 0, 1, 1),
                 mm_rect(-1, -1, 0, 0), mm_rect(0, -1, 1, 0)))
  expect_equal(n_assigned(point_at(0, 0), quad), 4L)
})

test_that("the coverage gate counts a boundary provider as inside", {
  # A provider on the edge of their own isochrone is inside it. The gate must
  # not report them missing and manufacture a coverage defect.
  skip_no_sf()
  surface <- mm_surface(x = -100, y = 40, w = 2, h = 2)
  on_edge <- point_at(-100, 41)
  res <- suppressMessages(
    mysterymaps_gate_provider_coverage(on_edge, surface))
  expect_equal(res$n_outside, 0L)
})

test_that("a provider in a multipart geography is found in either part", {
  skip_no_sf()
  mp <- sf::st_sf(GEOID = "michigan", geometry = sf::st_sfc(
    sf::st_multipolygon(list(
      list(cbind(c(0, 1, 1, 0, 0), c(0, 0, 1, 1, 0))),
      list(cbind(c(3, 4, 4, 3, 3), c(0, 0, 1, 1, 0))))), crs = 4326))
  expect_equal(n_assigned(point_at(0.5, 0.5), mp), 1L)
  expect_equal(n_assigned(point_at(3.5, 0.5), mp), 1L)
})

# ---------------------------------------------------------------------------
# Global state (SPEC 34)
# ---------------------------------------------------------------------------

# Everything a function could change behind the caller's back.
capture_global_state <- function() {
  list(
    s2        = if (requireNamespace("sf", quietly = TRUE)) sf::sf_use_s2() else NA,
    wd        = normalizePath(getwd(), winslash = "/"),
    seed      = if (exists(".Random.seed", globalenv(), inherits = FALSE))
                  get(".Random.seed", globalenv(), inherits = FALSE) else NULL,
    tz        = Sys.timezone(),
    scipen    = getOption("scipen"),
    digits    = getOption("digits"),
    stringsAsFactors = getOption("stringsAsFactors"),
    warn      = getOption("warn"),
    ow        = getOption("OutDec"),
    locale    = Sys.getlocale("LC_COLLATE"),
    attached  = search()
  )
}

test_that("no exported map builder mutates global state", {
  skip_no_sf()
  skip_if_not_installed("leaflet")
  before <- capture_global_state()

  cty <- mm_counties(6)
  mysterymaps_jenks_zero_scale(cty$rate, k = 4)
  mysterymaps_map_leaflet()
  mysterymaps_map_base("t")
  mysterymaps_county_access_map(cty, "rate", "tooltip", "profile",
                                notes = NULL, search = NULL)
  suppressMessages(mysterymaps_gate_provider_coverage(
    mm_points(3), mm_surface(x = -101, y = 39, w = 6, h = 4)))

  expect_equal(capture_global_state(), before)
})

test_that("the overlap calculation leaves the working directory alone", {
  # It creates directories and writes files; it must not cd into them.
  skip_no_sf()
  before <- capture_global_state()
  out <- withr::local_tempdir()
  suppressWarnings(suppressMessages(
    mysterymaps_calculate_overlap(mm_block_groups(4), mm_isochrones(), 30, out)))
  expect_equal(capture_global_state(), before)
})

test_that("a failing call restores global state as completely as a passing one", {
  # The error path is where on.exit handlers get forgotten.
  skip_no_sf()
  before <- capture_global_state()
  expect_error(suppressMessages(mysterymaps_calculate_overlap(
    mm_block_groups(4), mm_isochrones(), 999, withr::local_tempdir())))
  expect_equal(capture_global_state(), before)
})

test_that("results are identical in a clean and a contaminated session", {
  # Run the scale after deliberately disturbing everything a function might
  # lean on. The answer must not notice.
  skip_no_sf()
  vals <- c(0, 1, 4, 9, 25, 90, NA)
  clean <- mysterymaps_jenks_zero_scale(vals, k = 4)

  before <- capture_global_state()
  on.exit({
    suppressMessages(sf::sf_use_s2(before$s2))
    options(scipen = before$scipen, digits = before$digits, warn = before$warn)
  }, add = TRUE)

  suppressMessages(sf::sf_use_s2(FALSE))
  options(scipen = 100, digits = 3, warn = 1)
  set.seed(999)

  contaminated <- mysterymaps_jenks_zero_scale(vals, k = 4)
  expect_equal(contaminated$color(vals), clean$color(vals))
  expect_equal(contaminated$leg_labs, clean$leg_labs)
})
