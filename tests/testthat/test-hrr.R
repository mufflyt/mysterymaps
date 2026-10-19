# Hospital Referral Regions. mysterymaps_hrr() downloads an 8 MB shapefile from
# the Dartmouth Atlas on first use, so the download itself is stubbed: what is
# tested is the transform, the AK/HI filter, and the guards -- not Dartmouth's
# uptime.

fake_hrr_sf <- function() {
  skip_if_not_installed("sf")
  cities <- c("CO-Denver", "CA-Sacramento", "AK-Anchorage", "HI-Honolulu",
              "PR-San Juan")
  geoms <- lapply(seq_along(cities), function(i) {
    x <- -110 + i
    sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x),
                              c(35, 35, 36, 36, 35))))
  })
  # Deliberately NOT 4326: mysterymaps_hrr() must transform it.
  sf::st_transform(
    sf::st_sf(hrrcity = cities, hrrnum = seq_along(cities),
              geometry = sf::st_sfc(geoms, crs = 4326)),
    5070)
}

# Stub the download+unzip step by writing the fixture to a real shapefile and
# handing back its path.
local_stub_hrr_shapefile <- function(env = parent.frame()) {
  skip_if_not_installed("sf")
  dir <- withr::local_tempdir(.local_envir = env)
  path <- file.path(dir, "hrr.shp")
  suppressWarnings(sf::st_write(fake_hrr_sf(), path, quiet = TRUE))
  local_mocked_bindings(ensure_hrr_shapefile = function(...) path,
                        .env = env)
  path
}

test_that("the shapefile is returned in EPSG:4326 whatever it was stored in", {
  # Everything downstream -- leaflet, the honeycomb grid, st_filter against
  # physician points -- assumes WGS84.
  skip_if_not_installed("sf")
  local_stub_hrr_shapefile()
  hrr <- suppressMessages(mysterymaps_hrr())
  expect_equal(sf::st_crs(hrr)$epsg, 4326L)
})

test_that("Alaska and Hawaii are dropped by default", {
  skip_if_not_installed("sf")
  local_stub_hrr_shapefile()
  hrr <- suppressMessages(mysterymaps_hrr())
  expect_false(any(grepl("^(AK|HI)", hrr$hrrcity)))
  # Puerto Rico is NOT part of the AK/HI filter and must survive it.
  expect_true(any(grepl("^PR-", hrr$hrrcity)))
})

test_that("remove_HI_AK = FALSE keeps every HRR for the inset maps", {
  skip_if_not_installed("sf")
  local_stub_hrr_shapefile()
  hrr <- suppressMessages(mysterymaps_hrr(remove_HI_AK = FALSE))
  expect_equal(nrow(hrr), 5L)
  expect_true(any(grepl("^AK-", hrr$hrrcity)))
  expect_true(any(grepl("^HI-", hrr$hrrcity)))
})

test_that("the filter matches a PREFIX, not a substring", {
  # "^(AK|HI)" rather than "AK|HI": an HRR whose city merely contains those
  # letters -- "MI-Saginaw" does not, but "OH-Akron" does -- must survive.
  skip_if_not_installed("sf")
  dir <- withr::local_tempdir()
  path <- file.path(dir, "hrr.shp")
  sf_obj <- fake_hrr_sf()
  sf_obj$hrrcity <- c("OH-Akron", "CA-Sacramento", "AK-Anchorage",
                      "HI-Honolulu", "PR-San Juan")
  suppressWarnings(sf::st_write(sf_obj, path, quiet = TRUE))
  local_mocked_bindings(ensure_hrr_shapefile = function(...) path)

  hrr <- suppressMessages(mysterymaps_hrr())
  expect_true("OH-Akron" %in% hrr$hrrcity)
})

test_that("sf is named in the error when it is not installed", {
  local_mocked_bindings(
    requireNamespace = function(package, ...) !identical(package, "sf"),
    .package = "base")
  expect_error(mysterymaps_hrr(), "'sf' is required")
})

test_that("each package mysterymaps_hrr_maps needs is named in its own error", {
  for (pkg in c("sf", "scales", "ggspatial", "rnaturalearth", "gridExtra",
                "ggplot2")) {
    local_mocked_bindings(
      requireNamespace = function(package, ...) !identical(package, pkg),
      .package = "base")
    expect_error(mysterymaps_hrr_maps(mm_points()),
                 sprintf("'%s' is required", pkg))
  }
})

# --------------------------------------------------------------------------
# mysterymaps_hrr_maps: the honeycomb figure
# --------------------------------------------------------------------------
#
# The real ne_countries() USA spans the dateline, which at 0.3-degree hex
# spacing makes a grid of a quarter of a million cells and a test that takes
# minutes. A stubbed rectangle large enough to clear the hard-coded
# `grid_id > 9546` cut exercises the same code path in seconds.

stub_usa <- function(env = parent.frame()) {
  skip_if_not_installed("sf")
  skip_if_not_installed("rnaturalearth")
  usa <- sf::st_sf(
    name = "United States of America",
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(-115, -80, -80, -115, -115),
                                c(28, 28, 50, 50, 28)))),
      crs = 4326))
  local_mocked_bindings(ne_countries = function(...) usa,
                        .package = "rnaturalearth", .env = env)
  usa
}

test_that("the honeycomb figure is built and written as both TIFF and PNG", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("ggspatial")
  skip_if_not_installed("gridExtra")
  skip_if_not_installed("scales")
  skip_if_not_installed("rnaturalearth")

  stub_usa()
  local_stub_hrr_shapefile()
  out <- withr::local_tempdir()

  grob <- suppressWarnings(suppressMessages(
    mysterymaps_hrr_maps(mm_points(6, lon = seq(-110, -85, length.out = 6),
                                   lat = seq(30, 48, length.out = 6)),
                         trait_map = "obgyn", honey_map = "all",
                         output_dir = out, dpi = 72, width = 5, height = 4)))

  expect_true(file.exists(file.path(out, "obgyn_all_honey.tiff")))
  expect_true(file.exists(file.path(out, "obgyn_all_honey.png")))
  expect_s3_class(grob, "gtable")
})

test_that("trait_map and honey_map name the output files", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("ggspatial")
  skip_if_not_installed("gridExtra")
  skip_if_not_installed("rnaturalearth")

  stub_usa()
  local_stub_hrr_shapefile()
  out <- withr::local_tempdir()

  suppressWarnings(suppressMessages(
    mysterymaps_hrr_maps(mm_points(4, lon = seq(-108, -90, length.out = 4),
                                   lat = seq(32, 46, length.out = 4)),
                         trait_map = "neurotology", honey_map = "subset",
                         output_dir = out, dpi = 72, width = 4, height = 3)))

  expect_setequal(list.files(out),
                  c("neurotology_subset_honey.tiff",
                    "neurotology_subset_honey.png"))
})

test_that("REGRESSION: s2 is restored after the map is built", {
  # mysterymaps_hrr_maps() turns spherical geometry off to make the grid
  # intersection tractable. Leaving it off silently changes the result of every
  # subsequent sf operation in the session.
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("ggspatial")
  skip_if_not_installed("gridExtra")
  skip_if_not_installed("rnaturalearth")

  stub_usa()
  local_stub_hrr_shapefile()

  # Set it explicitly rather than reading whatever the previous test left
  # behind: an earlier mysterymaps_hrr_maps() call in this same file turns s2
  # off, and a test that starts from FALSE passes without checking anything.
  before <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(before)), add = TRUE)
  suppressMessages(sf::sf_use_s2(TRUE))

  suppressWarnings(suppressMessages(
    mysterymaps_hrr_maps(mm_points(3, lon = c(-105, -95, -88),
                                   lat = c(35, 40, 45)),
                         output_dir = withr::local_tempdir(),
                         dpi = 72, width = 4, height = 3)))

  expect_true(sf::sf_use_s2())
})

# --------------------------------------------------------------------------
# mm_honeycomb_counts: the per-cell provider count
# --------------------------------------------------------------------------
#
# Split out of mysterymaps_hrr_maps() so it can be asserted at all. The figure
# is a gtable, so a cell silently losing every provider it holds is invisible
# to any test of the output -- which is how the filter below survived.

hex_area <- function(lon = c(-172, -66), lat = c(19, 71)) {
  skip_if_not_installed("sf")
  sf::st_sf(name = "study area", geometry = sf::st_sfc(sf::st_polygon(list(
    cbind(lon[c(1, 2, 2, 1, 1)], lat[c(1, 1, 2, 2, 1)]))), crs = 4326))
}

hex_points <- function(lon, lat) {
  sf::st_as_sf(data.frame(id = seq_along(lon), lon = lon, lat = lat),
               coords = c("lon", "lat"), crs = 4326)
}

test_that("REGRESSION: providers in the westernmost cells are still counted", {
  # The defect this replaced was `dplyr::filter(grid_id > 9546L)`, commented
  # "Filter out Palmyra Atoll". grid_id is row_number() over st_make_grid(),
  # whose cells run in LONGITUDE order across the bounding box -- so the cut
  # deleted the 9,546 westernmost cells whatever was in them. Against the
  # current Natural Earth polygon that is 1,223 land cells including Honolulu,
  # Kauai and Nome, while Palmyra (5.9N) was never in the bbox at all.
  skip_if_not_installed("sf")
  area <- hex_area()

  # Two co-located providers in the far west, two in the far east. Co-located
  # rather than merely nearby: a 0.05-degree gap can straddle a cell boundary,
  # leaving one provider per cell, which min_count then suppresses -- a test
  # failure about the fixture rather than about the filter.
  pts <- hex_points(c(-171.5, -171.5, -67.5, -67.5), c(21.4, 21.4, 44.0, 44.0))

  out <- suppressWarnings(suppressMessages(
    mm_honeycomb_counts(area, pts, cellsize = 0.3)))

  lons <- sf::st_coordinates(suppressWarnings(sf::st_centroid(out)))[, 1]
  expect_true(any(lons < -170))     # the western pair survived
  expect_true(any(lons > -70))      # and so did the eastern
  expect_equal(sum(out$physician_count), 4L)
})

test_that("REGRESSION: cell ordering is longitudinal, which is why an index cut is unsafe", {
  # Pinning the sf property that made the old filter dangerous. If st_make_grid
  # ever ordered by latitude instead, a row-index cut would delete a different
  # band -- equally wrong, differently shaped. Either way it is not geography.
  skip_if_not_installed("sf")
  g <- sf::st_make_grid(hex_area(lon = c(-120, -100), lat = c(30, 40)),
                        c(1, 1), what = "polygons", square = FALSE)
  ctr <- sf::st_coordinates(suppressWarnings(sf::st_centroid(g)))
  first <- ctr[seq_len(20), ]; last <- ctr[seq.int(length(g) - 19, length(g)), ]
  expect_lt(max(first[, 1]), min(last[, 1]))   # first cells are all west of last
})

test_that("an outlying territory is excluded by latitude, not by row number", {
  # The intent the old filter claimed. Expressed as geography it cannot drift
  # when a data release changes the polygon's extent.
  skip_if_not_installed("sf")
  atoll <- sf::st_polygon(list(cbind(c(-162.2, -162.0, -162.0, -162.2, -162.2),
                                     c(5.8, 5.8, 6.0, 6.0, 5.8))))
  mainland <- sf::st_polygon(list(cbind(c(-160.5, -159.0, -159.0, -160.5, -160.5),
                                        c(21.8, 21.8, 22.3, 22.3, 21.8))))
  area <- sf::st_sf(name = "with atoll",
                    geometry = sf::st_sfc(sf::st_multipolygon(list(
                      list(atoll[[1]]), list(mainland[[1]]))), crs = 4326))

  pts <- hex_points(c(-162.1, -162.1, -159.8, -159.8), c(5.9, 5.9, 22.0, 22.0))
  out <- suppressWarnings(suppressMessages(
    mm_honeycomb_counts(area, pts, cellsize = 0.1)))

  lats <- sf::st_coordinates(suppressWarnings(sf::st_centroid(out)))[, 2]
  expect_false(any(lats < 15))       # the atoll's providers are gone
  expect_true(any(lats > 21))        # Kauai's are not
})

test_that("the southern limit sits below every one of the fifty states", {
  # Ka Lae, Hawaii, at 18.91N is the southernmost point of the fifty states.
  # A limit above it would repeat the original defect with a nicer comment.
  expect_lt(formals(mm_honeycomb_counts)$southern_limit, 18.91)
  expect_gt(formals(mm_honeycomb_counts)$southern_limit, 6.0)   # above Palmyra
})

test_that("min_count is a stated suppression threshold, not a rendering detail", {
  # A cell holding one provider is dropped, and drawn exactly like a cell
  # holding none. That is a small-cell suppression decision; pinned so it is a
  # choice someone can see rather than an inequality nobody reads.
  skip_if_not_installed("sf")
  area <- hex_area(lon = c(-105, -100), lat = c(38, 42))
  lone <- hex_points(-102.5, 40.0)

  expect_equal(nrow(suppressWarnings(suppressMessages(
    mm_honeycomb_counts(area, lone, cellsize = 0.5)))), 0L)
  expect_equal(nrow(suppressWarnings(suppressMessages(
    mm_honeycomb_counts(area, lone, cellsize = 0.5, min_count = 1L)))), 1L)
  expect_equal(formals(mm_honeycomb_counts)$min_count, 2L)
})

test_that("cells are clipped to the study area, and providers outside it are not counted", {
  skip_if_not_installed("sf")
  area <- hex_area(lon = c(-105, -100), lat = c(38, 42))
  outside <- hex_points(c(-90, -90), c(40, 40))
  expect_equal(nrow(suppressWarnings(suppressMessages(
    mm_honeycomb_counts(area, outside, cellsize = 0.5)))), 0L)
})

test_that("providers arriving in another CRS are counted in the same cells", {
  skip_if_not_installed("sf")
  area <- hex_area(lon = c(-105, -100), lat = c(38, 42))
  pts <- hex_points(c(-102.5, -102.5, -101.0, -101.0), c(40, 40, 39, 39))

  wgs <- suppressWarnings(suppressMessages(
    mm_honeycomb_counts(area, pts, cellsize = 0.5)))
  alb <- suppressWarnings(suppressMessages(
    mm_honeycomb_counts(area, sf::st_transform(pts, 5070), cellsize = 0.5)))
  expect_equal(sort(wgs$physician_count), sort(alb$physician_count))
  expect_equal(nrow(wgs), nrow(alb))
})

test_that("the count owns its s2 setting and gives it back", {
  # Clipping hexagons to a coastline leaves slivers that s2 rejects, so with
  # spherical geometry on the count does not come out wrong -- it errors. It
  # used to work only because its one caller had switched s2 off a few lines
  # earlier, which made the result a function of the session.
  skip_if_not_installed("sf")
  before <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(before)), add = TRUE)

  area <- hex_area(lon = c(-105, -100), lat = c(38, 42))
  pts <- hex_points(c(-102.5, -102.5), c(40, 40))

  results <- lapply(c(TRUE, FALSE), function(state) {
    suppressMessages(sf::sf_use_s2(state))
    out <- suppressWarnings(suppressMessages(
      mm_honeycomb_counts(area, pts, cellsize = 0.5)))
    c(n = nrow(out), total = sum(out$physician_count),
      restored = sf::sf_use_s2() == state)
  })
  expect_equal(results[[1]], results[[2]])
  expect_true(all(vapply(results, function(r) r[["restored"]] == 1, logical(1))))
})

# --------------------------------------------------------------------------
# mysterymaps_hex_bin_counts: the exported, boundary-agnostic wrapper
# --------------------------------------------------------------------------

test_that("the output column is named value_col, not physician_count", {
  skip_if_not_installed("sf")
  area <- hex_area(lon = c(-105, -100), lat = c(38, 42))
  pts <- hex_points(-102.5, 40)

  out <- suppressWarnings(suppressMessages(
    mysterymaps_hex_bin_counts(area, pts, value_col = "flood_risk",
                               cellsize = 0.5)))

  expect_true("flood_risk" %in% names(out))
  expect_false("physician_count" %in% names(out))
  expect_equal(out$flood_risk, 1L)
})

test_that("min_count defaults to 1, unlike mm_honeycomb_counts's 2", {
  # mm_honeycomb_counts suppresses lone points by default because HRR maps
  # draw physician density; a generic hazard/accessibility map has no reason
  # to inherit that assumption, so a single point must survive here.
  skip_if_not_installed("sf")
  area <- hex_area(lon = c(-105, -100), lat = c(38, 42))
  lone <- hex_points(-102.5, 40.0)

  out <- suppressWarnings(suppressMessages(
    mysterymaps_hex_bin_counts(area, lone, cellsize = 0.5)))
  expect_equal(nrow(out), 1L)
  expect_equal(out$count, 1L)
})

test_that("include_zero_cells returns the full grid, zero cells included", {
  # The default path never produces a zero-count row at all (a cell with no
  # points never enters the inner-join side), so a reader cannot tell "zero,
  # measured" from "not drawn". include_zero_cells = TRUE must return every
  # cell in the boundary, with an explicit 0 where nothing landed.
  skip_if_not_installed("sf")
  area <- hex_area(lon = c(-105, -100), lat = c(38, 42))
  lone <- hex_points(-102.5, 40.0)

  without_zeros <- suppressWarnings(suppressMessages(
    mysterymaps_hex_bin_counts(area, lone, cellsize = 0.5)))
  with_zeros <- suppressWarnings(suppressMessages(
    mysterymaps_hex_bin_counts(area, lone, cellsize = 0.5, include_zero_cells = TRUE)))

  expect_gt(nrow(with_zeros), nrow(without_zeros))
  expect_true(any(with_zeros$count == 0L))
  expect_equal(sum(with_zeros$count), 1L)
  expect_false(anyNA(with_zeros$count))
})

# ---- SABOTEUR: cellsize = 0 -------------------------------------------------
# REAL BUG, FIXED. checkmate::assert_number(cellsize, lower = 0) allows 0.
# sf::st_make_grid() asked for a grid of zero-size hexagons rejects it with
# an unrelated, cryptic error ("invalid '(to - from)/by'") rather than
# naming cellsize or the real cause.
test_that("SABOTEUR: cellsize = 0 errors clearly instead of a cryptic grid-construction failure", {
  skip_if_not_installed("sf")
  area <- hex_area(lon = c(-105, -100), lat = c(38, 42))
  lone <- hex_points(-102.5, 40.0)
  expect_error(
    mysterymaps_hex_bin_counts(area, lone, cellsize = 0),
    "strictly positive"
  )
})

test_that("include_zero_cells ignores min_count rather than silently honouring it", {
  # Suppressing small counts and asserting a cell is a true zero are
  # different, incompatible claims; min_count must not quietly drop a
  # below-threshold cell to zero (or out of the grid) in this mode.
  skip_if_not_installed("sf")
  area <- hex_area(lon = c(-105, -100), lat = c(38, 42))
  pts <- hex_points(c(-102.5, -102.5), c(40, 40))

  out <- suppressWarnings(suppressMessages(
    mysterymaps_hex_bin_counts(area, pts, cellsize = 0.5, min_count = 5L,
                               include_zero_cells = TRUE)))
  expect_equal(sum(out$count), 2L)
})

test_that("southern_limit defaults to -90, unlike mm_honeycomb_counts's US-specific 15", {
  # A boundary south of 15N (e.g. most of South America, Africa, Australia)
  # must not be silently emptied by a default built for HRR/US maps.
  skip_if_not_installed("sf")
  area <- hex_area(lon = c(-70, -65), lat = c(-35, -30))  # Buenos Aires-ish
  pts <- hex_points(c(-67.5, -67.5), c(-32.5, -32.5))

  out <- suppressWarnings(suppressMessages(
    mysterymaps_hex_bin_counts(area, pts, cellsize = 0.5)))
  expect_equal(nrow(out), 1L)
})

test_that("cellsize and min_count still pass through to the honeycomb count", {
  skip_if_not_installed("sf")
  area <- hex_area(lon = c(-105, -100), lat = c(38, 42))
  pts <- hex_points(c(-102.5, -102.5, -102.5), c(40, 40, 40))

  suppressed <- suppressWarnings(suppressMessages(
    mysterymaps_hex_bin_counts(area, pts, cellsize = 0.5, min_count = 4L)))
  kept <- suppressWarnings(suppressMessages(
    mysterymaps_hex_bin_counts(area, pts, cellsize = 0.5, min_count = 3L)))

  expect_equal(nrow(suppressed), 0L)
  expect_equal(nrow(kept), 1L)
  expect_equal(kept$count, 3L)
})

test_that("arguments are validated before any sf work happens", {
  expect_error(mysterymaps_hex_bin_counts(data.frame(x = 1), hex_points(1, 1)),
               class = "simpleError")
  area <- hex_area(lon = c(-105, -100), lat = c(38, 42))
  expect_error(mysterymaps_hex_bin_counts(area, data.frame(x = 1)),
               class = "simpleError")
  expect_error(mysterymaps_hex_bin_counts(area, hex_points(1, 1), value_col = 1),
               class = "simpleError")
})

test_that("REGRESSION: include_zero_cells matches via spatial join, not grid_id", {
  # grid_id is assigned BEFORE st_intersection(grid, boundary) runs, and that
  # intersection can slice one hex into several disjoint polygon fragments
  # along an irregular boundary -- every fragment inherits the SAME grid_id.
  # An attribute join (left_join(by = "grid_id")) fans out across every
  # fragment sharing an id; only a spatial join (st_join(), matching each
  # fragment to the specific counts geometry that overlaps IT) gets this
  # right. Caught by running the real CONUS boundary: 757 nonzero cells with
  # a naive attribute join, versus 609 -- the drop-zero path's true count --
  # once fixed. This inspects the source for the regression directly, since
  # a synthetic boundary that reliably fragments a hex cell at a chosen
  # cellsize is fragile to construct and the real-boundary numbers above are
  # the actual evidence the fix is correct.
  body_text <- paste(deparse(body(mm_honeycomb_counts_full_grid)), collapse = "\n")
  expect_true(grepl("st_join", body_text, fixed = TRUE))
  expect_false(grepl("left_join", body_text, fixed = TRUE))
})

# --------------------------------------------------------------------------
# mm_suppress_small_cells: the suppression step mysterymaps_hrr_maps() now
# applies to the full-grid count. Split out directly testable for the same
# reason mm_honeycomb_counts() was (see its own doc comment): the caller
# returns a gtable, so a suppression bug would be invisible to any assertion
# about mysterymaps_hrr_maps()'s output.
# --------------------------------------------------------------------------

test_that("a true zero passes through unsuppressed", {
  expect_equal(mm_suppress_small_cells(c(0, 0, 0), min_count = 2L), c(0, 0, 0))
})

test_that("a count below min_count becomes NA, not zero and not itself", {
  expect_equal(mm_suppress_small_cells(c(1), min_count = 2L), NA_real_)
})

test_that("a count at or above min_count passes through unchanged", {
  expect_equal(mm_suppress_small_cells(c(2, 5, 100), min_count = 2L), c(2, 5, 100))
})

test_that("min_count = 1 suppresses nothing (every nonzero count already clears it)", {
  expect_equal(mm_suppress_small_cells(c(0, 1, 2, 5), min_count = 1L), c(0, 1, 2, 5))
})

test_that("REGRESSION: zero and suppressed are never the same value after this step", {
  # The defect this guards: folding 1-provider cells into 0 would make a
  # true "no providers at all" indistinguishable from "we are hiding a small
  # number" -- opposite failure modes, both wrong.
  out <- mm_suppress_small_cells(c(0, 1, 2), min_count = 2L)
  expect_equal(out[1], 0)
  expect_true(is.na(out[2]))
  expect_false(isTRUE(out[1] == out[2]))
})

# --------------------------------------------------------------------------
# mysterymaps_hrr_maps: zero-aware colouring (REGRESSION for the original
# bug -- mm_honeycomb_counts() dropped every cell below min_count, including
# true zeros, so a region with no providers drew no hexagon at all)
# --------------------------------------------------------------------------

test_that("REGRESSION: a true zero and a suppressed cell get different colours", {
  skip_if_not_installed("sf")
  area <- hex_area(lon = c(-105, -100), lat = c(38, 42))
  # One lone provider (will be suppressed at the default min_count = 2);
  # nothing anywhere else in the study area (true, measured zero).
  lone <- hex_points(-102.5, 40.0)

  full <- suppressWarnings(suppressMessages(
    mm_honeycomb_counts_full_grid(area, lone, value_col = "physician_count", cellsize = 0.5)))
  full$physician_count <- mm_suppress_small_cells(full$physician_count, min_count = 2L)

  sc <- mysterymaps_jenks_zero_scale(
    full$physician_count, k = 6, zero_col = "#e0e0e0", na_col = "#ffffff",
    na_label = "Suppressed (<2 providers)",
    palette = function(kk) viridisLite::viridis(kk, option = "viridis"))
  colors <- sc$color(full$physician_count)

  expect_true(any(colors == "#e0e0e0"))   # true zeros present
  expect_true(any(colors == "#ffffff"))   # the suppressed lone-provider cell
  expect_true(any(grepl("Suppressed", sc$leg_labs)))
})

test_that("the figure still builds with every cell suppressed or zero (no positive class at all)", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("ggspatial")
  skip_if_not_installed("gridExtra")
  skip_if_not_installed("rnaturalearth")

  stub_usa()
  local_stub_hrr_shapefile()

  grob <- suppressWarnings(suppressMessages(
    mysterymaps_hrr_maps(mm_points(1, lon = -108, lat = 35),
                         output_dir = withr::local_tempdir(), dpi = 72, width = 4, height = 3)))
  expect_s3_class(grob, "gtable")
})

test_that("min_count, k, zero_color and na_color are validated", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("ggspatial")
  skip_if_not_installed("gridExtra")
  skip_if_not_installed("rnaturalearth")

  stub_usa()
  local_stub_hrr_shapefile()
  pts <- mm_points(1, lon = -108, lat = 35)
  out <- withr::local_tempdir()

  expect_error(mysterymaps_hrr_maps(pts, output_dir = out, min_count = -1L))
  expect_error(mysterymaps_hrr_maps(pts, output_dir = out, k = 0L))
  expect_error(mysterymaps_hrr_maps(pts, output_dir = out, zero_color = 1))
  expect_error(mysterymaps_hrr_maps(pts, output_dir = out, na_color = 1))
})
