# Adversarial inputs for the leaflet map builders -- deliberately malformed
# or boundary-case data chosen to try to make these functions silently do the
# wrong thing (not just error). Three real bugs were found and fixed this way:
#
#  1. mysterymaps_access_choropleth_map_multi() keyed every polygon's layerId
#     off `mm_id` alone, sharing ONE leaflet layer registry across every
#     geography in `geos`. Two geographies with an overlapping id (County
#     "01", a Congressional District also "01") silently collided, which
#     would cross-wire click-to-highlight between unrelated geographies.
#  2. mysterymaps_count_points_in_polygons() and
#     mysterymaps_aggregate_values_to_polygons() both document that `id`
#     must be unique but never enforced it -- a duplicate id fanned out a
#     join/match and double-counted every point or value touching it.
#  3. mysterymaps_choropleth_point_map() on a zero-row layer failed with a
#     raw classInt internals error ("invalid 'type' (list) of argument"),
#     not a message naming the layer or the actual problem.
#  4. mysterymaps_access_choropleth_map() and ..._multi() had the identical
#     collision hazard as (1), one layer down: `providers$mm_id` is used
#     verbatim as each marker's layerId, so two providers sharing an id
#     silently collide (confirmed: the rendered layerId vector was literally
#     c("P1", "P1") for two different physicians, no error).
#  5. ..._multi()'s zip_centroids -> zoom-to-ZIP lookup used
#     sprintf("%05d", as.integer(zip)) with no validation first. A ZIP+4
#     string ("80202-1234") parses to NA, and sprintf("%05d", NA) is the
#     literal string "NA" -- a malformed ZIP became a real-looking, broken
#     lookup key instead of being dropped.
#  6. ..._multi() let a geography carry `mm_fill_coverage` (a column) with
#     no matching `coverage_pal`/`coverage_values` (the palette itself),
#     and failed inside leaflet::addLegend() with "argument is of length
#     zero" -- naming neither the geography nor the real problem.
#  7. mysterymaps_access_choropleth_map() (singular) crashed with the same
#     cryptic "invalid 'type' (list) of argument" whenever `mm_no_access`
#     was all FALSE -- i.e. whenever every area has access, an entirely
#     normal and GOOD outcome. The multi-geography sibling already guards
#     this exact failure (its own comment names it: "adding a zero-row
#     polygon layer errors in leaflet's bbox expansion"); the singular
#     function never got the same fix. Found while writing a fixture for
#     finding 4 above and discovering it broke for an unrelated reason.
#
# This file is deliberately NOT about re-testing already-covered behavior
# (see test-leaflet-map-invariants.R and each function's own test file) --
# every test here exists because it found something real, or guards the
# specific fix for something that did.

testthat::local_edition(3)

skip_unless_spatial <- function() {
  testthat::skip_if_not_installed("sf")
  testthat::skip_if_not_installed("leaflet")
  testthat::skip_if_not_installed("leaflet.extras")
}

.sab_square <- function(x, w = 1) {
  sf::st_polygon(list(cbind(c(x, x + w, x + w, x, x), c(39, 39, 41, 41, 39))))
}

.sab_geo <- function(ids) {
  sf::st_sf(
    mm_id = ids, mm_label = ids, mm_popup = paste0("<b>", ids, "</b>"),
    mm_fill_time = rep("#2166ac", length(ids)), mm_fill_supply = rep("#67a9cf", length(ids)),
    mm_no_access = rep(FALSE, length(ids)),
    geometry = sf::st_sfc(lapply(seq_along(ids), function(i) .sab_square(-100 + i)), crs = 4326))
}

.sab_provider <- function() {
  sf::st_as_sf(data.frame(mm_id = "P1", mm_label = "P1", mm_popup = "P1", lon = -99, lat = 40),
              coords = c("lon", "lat"), crs = 4326)
}

# =============================================================================
# 1. Cross-geography mm_id collision in mysterymaps_access_choropleth_map_multi()
# =============================================================================
testthat::test_that("SABOTEUR: two geographies sharing an mm_id error instead of cross-wiring click-to-highlight", {
  skip_unless_spatial()
  county_geo <- .sab_geo(c("01", "02"))
  cd_geo     <- .sab_geo(c("01", "03"))   # "01" collides with county "01"
  testthat::expect_error(
    mysterymaps_access_choropleth_map_multi(
      geos = list(County = list(sf = county_geo,
                                supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1)),
                 `Congressional District` = list(sf = cd_geo,
                                supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1))),
      providers = .sab_provider(), highlight_lookup = list(`01` = "P1"),
      band_colors = "#2166ac", band_labels = "<=30 min", title_html = "<b>t</b>"),
    "unique across EVERY geography.*01")
})

testthat::test_that("non-colliding ids across geographies still build successfully", {
  skip_unless_spatial()
  county_geo <- .sab_geo(c("01", "02"))
  cd_geo     <- .sab_geo(c("03", "04"))   # disjoint from county ids
  m <- mysterymaps_access_choropleth_map_multi(
    geos = list(County = list(sf = county_geo,
                              supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1)),
               `Congressional District` = list(sf = cd_geo,
                              supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1))),
    providers = .sab_provider(), highlight_lookup = list(`01` = "P1"),
    band_colors = "#2166ac", band_labels = "<=30 min", title_html = "<b>t</b>")
  testthat::expect_s3_class(m, "leaflet")
})

testthat::test_that("duplicate mm_id WITHIN a single geography also errors (same hazard, one geography)", {
  skip_unless_spatial()
  geo_with_dupe <- .sab_geo(c("01", "01"))
  testthat::expect_error(
    mysterymaps_access_choropleth_map_multi(
      geos = list(County = list(sf = geo_with_dupe,
                                supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1))),
      providers = .sab_provider(), highlight_lookup = list(`01` = "P1"),
      band_colors = "#2166ac", band_labels = "<=30 min", title_html = "<b>t</b>"),
    "unique across EVERY geography")
})

# =============================================================================
# 2. Duplicate `id` fans out the join/match in the two spatial helpers
# =============================================================================
testthat::test_that("SABOTEUR: a duplicate polygon id errors instead of double-counting points", {
  skip_unless_spatial()
  dup_polys <- sf::st_sf(id = c(1L, 1L, 2L),
    geometry = sf::st_sfc(.sab_square(-100), .sab_square(-99), .sab_square(-98), crs = 4326))
  pts <- sf::st_as_sf(data.frame(lon = c(-99.5, -98.5), lat = c(39.5, 39.5)),
                      coords = c("lon", "lat"), crs = 4326)
  testthat::expect_error(
    mysterymaps_count_points_in_polygons(dup_polys, pts),
    "duplicate value.*1")
})

testthat::test_that("unique polygon ids still count correctly (no false-positive from the new guard)", {
  skip_unless_spatial()
  polys <- sf::st_sf(id = c(1L, 2L),
    geometry = sf::st_sfc(.sab_square(-100), .sab_square(-98), crs = 4326))
  pts <- sf::st_as_sf(data.frame(lon = c(-99.5, -97.5), lat = c(39.5, 39.5)),
                      coords = c("lon", "lat"), crs = 4326)
  out <- mysterymaps_count_points_in_polygons(polys, pts)
  testthat::expect_identical(out$n, c(1L, 1L))
})

testthat::test_that("SABOTEUR: a duplicate source_poly id errors instead of double-counting the aggregate", {
  skip_unless_spatial()
  dup_polys <- sf::st_sf(id = c(1L, 1L, 2L),
    geometry = sf::st_sfc(.sab_square(-100), .sab_square(-99), .sab_square(-98), crs = 4326))
  region <- sf::st_sf(id = "R1", geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-101, -95, -95, -101, -101), c(38, 38, 42, 42, 38)))), crs = 4326))
  testthat::expect_error(
    mysterymaps_aggregate_values_to_polygons(
      dup_polys, data.frame(id = c(1, 1, 2), n = c(10, 10, 5)), region, value_col = "n"),
    "duplicate value.*1")
})

# =============================================================================
# 3. Zero-row layer in mysterymaps_choropleth_point_map()
# =============================================================================
testthat::test_that("SABOTEUR: a zero-row layer names itself in the error instead of leaking a classInt internals error", {
  skip_unless_spatial()
  empty_counties <- sf::st_sf(id = integer(0), label = character(0), popup = character(0),
                              n = integer(0), geometry = sf::st_sfc(crs = 4326))
  pts <- sf::st_as_sf(data.frame(lon = -97, lat = 40, label = "P", popup = "P"),
                      coords = c("lon", "lat"), crs = 4326)
  testthat::expect_error(
    mysterymaps_choropleth_point_map(list(Count = empty_counties), pts, point_fill = "#c2185b"),
    "zero rows.*Count")
})

testthat::test_that("one empty layer among several non-empty ones is named specifically, not the whole call", {
  skip_unless_spatial()
  nonempty <- .sab_geo("01"); nonempty$n <- 3L; nonempty$label <- "A"; nonempty$popup <- "A"
  empty <- sf::st_sf(mm_id = character(0), n = integer(0), label = character(0), popup = character(0),
                     geometry = sf::st_sfc(crs = 4326))
  pts <- sf::st_as_sf(data.frame(lon = -97, lat = 40, label = "P", popup = "P"),
                      coords = c("lon", "lat"), crs = 4326)
  testthat::expect_error(
    mysterymaps_choropleth_point_map(list(Full = nonempty, Empty = empty), pts, point_fill = "#c2185b"),
    "Empty")
})

# =============================================================================
# 4. Duplicate provider mm_id collides on the marker layerId (same hazard as
#    the geography-id collision, one layer down).
# =============================================================================
.sab_dup_providers <- function() {
  sf::st_as_sf(data.frame(mm_id = c("P1", "P1"), mm_label = c("Dr X", "Dr Y"),
                          mm_popup = c("X", "Y"), lon = c(-99, -96.7), lat = c(40, 40)),
              coords = c("lon", "lat"), crs = 4326)
}

testthat::test_that("SABOTEUR: duplicate providers$mm_id errors instead of colliding on marker layerId (singular)", {
  skip_unless_spatial()
  geo <- .sab_geo(c("A", "B"))
  testthat::expect_error(
    mysterymaps_access_choropleth_map(
      geo, .sab_dup_providers(), highlight_lookup = list(A = "P1"),
      supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1),
      band_colors = "#2166ac", band_labels = "<=30 min", title_html = "<b>t</b>"),
    "providers\\$mm_id.*duplicate.*P1")
})

testthat::test_that("SABOTEUR: duplicate providers$mm_id errors instead of colliding on marker layerId (multi)", {
  skip_unless_spatial()
  geo <- .sab_geo(c("A", "B"))
  testthat::expect_error(
    mysterymaps_access_choropleth_map_multi(
      geos = list(County = list(sf = geo,
                                supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1))),
      providers = .sab_dup_providers(), highlight_lookup = list(A = "P1"),
      band_colors = "#2166ac", band_labels = "<=30 min", title_html = "<b>t</b>"),
    "providers\\$mm_id.*duplicate.*P1")
})

testthat::test_that("non-duplicate providers still build successfully", {
  skip_unless_spatial()
  geo <- .sab_geo(c("A", "B"))
  m <- mysterymaps_access_choropleth_map(
    geo, .sab_provider(), highlight_lookup = list(A = "P1"),
    supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1),
    band_colors = "#2166ac", band_labels = "<=30 min", title_html = "<b>t</b>")
  testthat::expect_s3_class(m, "leaflet")
})

# =============================================================================
# 5. A malformed ZIP (e.g. ZIP+4) must be dropped, not turned into a lookup
#    key literally named "NA".
# =============================================================================
testthat::test_that("SABOTEUR: a ZIP+4 entry is dropped from the zoom-to-ZIP lookup, not turned into key \"NA\"", {
  skip_unless_spatial()
  geo <- .sab_geo("A")
  zips <- data.frame(zip = c("80202", "80202-1234"), lat = c(39.75, 39.76), lon = c(-104.99, -104.98))
  m <- mysterymaps_access_choropleth_map_multi(
    geos = list(County = list(sf = geo,
                              supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1))),
    providers = .sab_provider(), highlight_lookup = list(A = "P1"),
    band_colors = "#2166ac", band_labels = "<=30 min", title_html = "<b>t</b>", zip_centroids = zips)
  zip_keys <- names(m$jsHooks$render[[length(m$jsHooks$render)]]$data$zips)
  testthat::expect_identical(zip_keys, "80202")
})

# =============================================================================
# 6. mm_fill_coverage without coverage_pal/coverage_values must name the
#    geography and the actual missing argument, not leak a leaflet internals
#    error from inside addLegend().
# =============================================================================
testthat::test_that("SABOTEUR: mm_fill_coverage without coverage_pal/coverage_values names the geography, not a leaflet internals error", {
  skip_unless_spatial()
  geo_cov <- .sab_geo("A")
  geo_cov$mm_fill_coverage <- "#123456"
  testthat::expect_error(
    mysterymaps_access_choropleth_map_multi(
      geos = list(County = list(sf = geo_cov,
                                supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1))),
      providers = .sab_provider(), highlight_lookup = list(A = "P1"),
      band_colors = "#2166ac", band_labels = "<=30 min", title_html = "<b>t</b>"),
    "County.*coverage_pal")
})

# =============================================================================
# 7. Zero access-deserts (mm_no_access all FALSE) must still build --
#    "everywhere has access" is a normal, good outcome, not an edge case
#    that should crash the map.
# =============================================================================
testthat::test_that("SABOTEUR: mysterymaps_access_choropleth_map() builds when there are zero access-deserts", {
  skip_unless_spatial()
  geo <- .sab_geo(c("A", "B"))   # .sab_geo()'s mm_no_access is all FALSE
  m <- mysterymaps_access_choropleth_map(
    geo, .sab_provider(), highlight_lookup = list(A = "P1"),
    supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1),
    band_colors = "#2166ac", band_labels = "<=30 min", title_html = "<b>t</b>")
  testthat::expect_s3_class(m, "leaflet")
  layers_call <- Filter(function(cl) cl$method == "addLayersControl", m$x$calls)[[1]]
  testthat::expect_false("No access" %in% layers_call$args[[2]])
})

testthat::test_that("the access-desert overlay still renders when at least one desert exists (regression)", {
  skip_unless_spatial()
  geo <- .sab_geo(c("A", "B")); geo$mm_no_access <- c(TRUE, FALSE)
  m <- mysterymaps_access_choropleth_map(
    geo, .sab_provider(), highlight_lookup = list(A = "P1"),
    supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1),
    band_colors = "#2166ac", band_labels = "<=30 min", title_html = "<b>t</b>")
  layers_call <- Filter(function(cl) cl$method == "addLayersControl", m$x$calls)[[1]]
  testthat::expect_true("No access" %in% layers_call$args[[2]])
  testthat::expect_true(any(vapply(m$x$calls, function(cl) cl$method == "hideGroup", logical(1))))
})
