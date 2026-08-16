# SPEC section 8: metamorphic testing.
#
# These are worth more than another hundred example unit tests. Most scientific
# outputs here have no simple known answer, but their behaviour under a
# controlled transformation is known exactly: shuffling rows, renaming keys or
# adding columns nobody reads must change nothing at all.
#
# A transformation that DOES change the answer has found a hidden dependence on
# ordering, on identity, or on incidental structure -- and every one of those
# produces a map that looks entirely normal.

skip_no_sf <- function() skip_if_not_installed("sf")

# The scientific content of a county map: the fill each geography received,
# keyed by geography rather than by position.
map_signature <- function(cty, value_col = "rate") {
  sc <- mysterymaps_jenks_zero_scale(cty[[value_col]], k = 6, digits = 1)
  sig <- stats::setNames(sc$color(cty[[value_col]]), cty$GEOID)
  list(fills = sig[order(names(sig))],
       legend = paste(sc$leg_cols, sc$leg_labs, sep = "="))
}

test_that("row permutation changes nothing", {
  skip_no_sf()
  base <- mm_counties(6)
  ref <- map_signature(base)

  mm_for_each_seed(mm_property_n(10L), function(seed) {
    expect_equal(map_signature(mm_shuffle_rows(base)), ref)
  })
})

test_that("harmless extra columns change nothing", {
  skip_no_sf()
  base <- mm_counties(6)
  expect_equal(map_signature(mm_add_noise_cols(base, 20L)), map_signature(base))
})

test_that("renaming geographic keys changes only the keys", {
  # Identifiers are labels. If the scientific answer depends on the literal
  # text of a GEOID, something is sorting or matching on it by accident.
  skip_no_sf()
  base <- mm_counties(6)
  renamed <- mm_rename_ids(base)
  expect_equal(unname(map_signature(renamed)$fills),
               unname(map_signature(base)$fills))
  expect_equal(map_signature(renamed)$legend, map_signature(base)$legend)
})

test_that("polygon vertex order does not change the classification", {
  # The same square wound the other way is the same square.
  skip_no_sf()
  base <- mm_counties(4)
  reversed <- base
  sf::st_geometry(reversed) <- sf::st_sfc(lapply(sf::st_geometry(base), function(g) {
    m <- g[[1]]
    sf::st_polygon(list(m[rev(seq_len(nrow(m))), , drop = FALSE]))
  }), crs = sf::st_crs(base))
  expect_equal(map_signature(reversed), map_signature(base))
})

test_that("a CRS round trip does not move any provider between geographies", {
  # 4326 -> 5070 -> 4326. Coordinates change representation and not place.
  skip_no_sf()
  pts <- mm_points(6, lon = seq(-99.4, -96.6, length.out = 6),
                   lat = seq(40.1, 40.9, length.out = 6))
  cty <- mm_counties(6)

  assign_state <- function(p, g) {
    lengths(suppressMessages(sf::st_intersects(p, g))) > 0
  }
  before <- assign_state(pts, cty)
  round_tripped <- sf::st_transform(sf::st_transform(pts, 5070), 4326)
  after <- assign_state(round_tripped, cty)

  expect_equal(after, before)
})

test_that("duplicate injection does not change the classification", {
  # Duplicating a county row must not move the Jenks breaks in a way that
  # recolours the others. It changes the weighting, so the test is on the
  # DISTINCT values, which is the scientifically meaningful invariant.
  skip_no_sf()
  base <- mm_counties(6)
  vals <- base$rate
  a <- mysterymaps_jenks_zero_scale(vals, k = 3)
  b <- mysterymaps_jenks_zero_scale(c(vals, vals), k = 3)
  expect_equal(b$color(vals), a$color(vals))
  expect_equal(b$leg_cols, a$leg_cols)
})

test_that("scaling every value by a positive constant preserves the ranking", {
  # Counts to counts-per-thousand: classes may move, order must not.
  vals <- c(0, 1, 4, 9, 25, 90)
  a <- mysterymaps_jenks_zero_scale(vals, k = 4)
  b <- mysterymaps_jenks_zero_scale(vals * 1000, k = 4)
  rank_of <- function(sc, v) match(sc$color(v), sc$leg_cols)
  expect_equal(rank_of(b, vals * 1000), rank_of(a, vals))
})

test_that("geographic partition recombines to the whole", {
  # Compute coverage over all counties at once, then in two halves, and
  # reassemble. A national figure that disagrees with the sum of its regions
  # has a cross-region dependence it should not have.
  skip_no_sf()
  cty <- mm_counties(6)
  surface <- mm_surface(x = -99.5, y = 40, w = 4, h = 1)

  covered <- function(g) {
    lengths(suppressMessages(sf::st_intersects(g, sf::st_geometry(surface)))) > 0
  }
  whole <- covered(cty)
  halves <- c(covered(cty[1:3, ]), covered(cty[4:6, ]))
  expect_equal(halves, whole)
})

test_that("repeated execution in one session is stable", {
  # Contaminated-session comparison: the tenth call must equal the first.
  skip_no_sf()
  cty <- mm_counties(6)
  ref <- map_signature(cty)
  for (i in 1:10) expect_equal(map_signature(cty), ref)
})

test_that("running the map builders in reverse order changes nothing", {
  # Order dependence between exported functions is the signature of shared
  # mutable state.
  skip_no_sf()
  skip_if_not_installed("leaflet")
  cty <- mm_counties(6)

  forward <- {
    mysterymaps_map_leaflet()
    mysterymaps_map_base()
    map_signature(cty)
  }
  reverse <- {
    map_signature(cty)
    mysterymaps_map_base()
    mysterymaps_map_leaflet()
    map_signature(cty)
  }
  expect_equal(reverse, forward)
})
