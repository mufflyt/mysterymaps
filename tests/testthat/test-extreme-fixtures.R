# SPEC section 41: extreme-case scientific fixtures.
#
# Tiny inputs with analytically obvious answers. They are simple and they are
# where a national pipeline actually breaks, because a rare subspecialty really
# does produce a country that is almost entirely zero.

skip_no_sf <- function() skip_if_not_installed("sf")

test_that("no providers nationally: every measured geography is an observed zero", {
  cty <- mm_counties(6)
  cty$rate <- rep(0, 6)
  sc <- mysterymaps_jenks_zero_scale(cty$rate)
  expect_length(unique(sc$color(cty$rate)), 1L)
  expect_identical(sc$leg_labs, "0")
  expect_false("No data" %in% sc$leg_labs)
})

test_that("one provider nationally: exactly one geography is non-zero", {
  cty <- mm_counties(6)
  cty$rate <- c(0, 0, 0, 0, 0, 1)
  sc <- mysterymaps_jenks_zero_scale(cty$rate)
  cols <- sc$color(cty$rate)
  expect_equal(sum(cols != sc$leg_cols[[1]]), 1L)
  expect_identical(cols[[6]], sc$leg_cols[[2]])
})

test_that("all supply in one geography leaves every other at observed zero", {
  cty <- mm_counties(6)
  cty$rate <- c(0, 0, 0, 0, 0, 250)
  sc <- mysterymaps_jenks_zero_scale(cty$rate)
  cols <- sc$color(cty$rate)
  expect_length(unique(cols[1:5]), 1L)
  expect_identical(unique(cols[1:5]), sc$leg_cols[[1]])
})

test_that("every geography identical: one class for the whole country", {
  sc <- mysterymaps_jenks_zero_scale(rep(3.5, 50))
  expect_length(unique(sc$color(rep(3.5, 50))), 1L)
})

test_that("one provider duplicated many times is still one geography's worth", {
  # The dedup identity at map level: repeating the same value does not create
  # new classes.
  a <- mysterymaps_jenks_zero_scale(c(0, 7))
  b <- mysterymaps_jenks_zero_scale(c(0, rep(7, 1000)))
  expect_equal(b$leg_cols, a$leg_cols)
  expect_equal(b$color(7), a$color(7))
})

test_that("a single provider exactly on a boundary is assigned by a stated rule", {
  # The rule is st_intersects' closed predicate, and it is s2-dependent; see
  # test-boundary-and-state.R. What must not happen is an error or a silent
  # drop.
  skip_no_sf()
  g <- sf::st_sf(GEOID = c("west", "east"),
                 geometry = c(mm_rect(-1, 0, 0, 1), mm_rect(0, 0, 1, 1)))
  p <- sf::st_as_sf(data.frame(lon = 0, lat = 0.5),
                    coords = c("lon", "lat"), crs = 4326)
  hits <- suppressMessages(sf::st_intersects(p, g))[[1]]
  expect_gte(length(hits), 1L)
})

test_that("a country that is entirely unmeasured is not a country of zeros", {
  sc <- mysterymaps_jenks_zero_scale(rep(NA_real_, 50))
  expect_true(sc$leg_labs[[length(sc$leg_labs)]] == "No data")
  expect_true("No data" %in% sc$leg_labs)
  expect_false(identical(sc$color(NA_real_), "#e0e0e0"))
})

test_that("one measured zero among fifty unmeasured stays distinguishable", {
  # The scientifically hardest small case: the single county anyone actually
  # visited must not be lost among the ones nobody did.
  vals <- c(0, rep(NA_real_, 49))
  sc <- mysterymaps_jenks_zero_scale(vals)
  cols <- sc$color(vals)
  expect_false(identical(cols[[1]], cols[[2]]))
  expect_length(unique(cols), 2L)
})

test_that("a single county map builds", {
  skip_no_sf()
  skip_if_not_installed("leaflet")
  cty <- mm_counties(1, rate = 0)
  expect_no_error(
    mysterymaps_county_access_map(cty, "rate", "tooltip", "profile",
                                  notes = NULL, search = NULL))
})

test_that("a coverage gate with one provider reports n = 1", {
  skip_no_sf()
  res <- suppressMessages(mysterymaps_gate_provider_coverage(
    mm_points(1), mm_surface(x = -101, y = 39, w = 6, h = 4)))
  expect_equal(res$n, 1L)
  expect_equal(res$n_outside, 0L)
})

test_that("an empty provider set is not a 100% coverage failure", {
  # 0/0 must not become 100% missing, which would abort a legitimate run over
  # a geography with no providers to check.
  skip_no_sf()
  empty <- mm_points(3)[0, ]
  res <- suppressMessages(mysterymaps_gate_provider_coverage(
    empty, mm_surface(x = -101, y = 39, w = 6, h = 4)))
  expect_equal(res$n, 0L)
  expect_equal(res$pct_outside, 0)
})
