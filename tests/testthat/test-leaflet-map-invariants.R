# Cross-cutting INVARIANT tests for every mysterymaps function that builds a
# leaflet map.
#
# These differ from each function's own example-based tests: instead of
# pinning one input to one expected output, each test states a property that
# must hold for ANY valid input to ANY of these builders -- the same kind of
# structural contract leaflet itself never checks for you, because it will
# happily accept a duplicate group name, a mismatched legend, or an NA colour
# and render something that LOOKS like a map while quietly lying about its
# data. Several of the invariants here (zero-colour distinctness, legend
# length, unique layerIds) are exactly the failure classes documented in this
# session's own bug fixes and ported-code history.

testthat::local_edition(3)

skip_unless_spatial <- function() {
  testthat::skip_if_not_installed("sf")
  testthat::skip_if_not_installed("leaflet")
  testthat::skip_if_not_installed("leaflet.extras")
}

# ---- shared fixtures --------------------------------------------------------

# Three counties sharing one deliberately-mixed value column: an exact 0 and
# two distinct positive values. Every zero-aware colour-scale invariant below
# depends on this shape -- a fixture with no zero, or no positive value,
# would pass the zero-distinctness check for free and prove nothing.
.inv_counties <- function() {
  sf::st_sf(
    id = 1:3, label = c("A", "B", "C"), popup = c("<b>A</b>", "<b>B</b>", "<b>C</b>"),
    n = c(0L, 4L, 9L),
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
      sf::st_polygon(list(cbind(c(-98, -96, -96, -98, -98), c(39, 39, 41, 41, 39)))),
      sf::st_polygon(list(cbind(c(-96, -94, -94, -96, -96), c(39, 39, 41, 41, 39)))),
      crs = 4326))
}

.inv_points <- function(n = 2) {
  sf::st_as_sf(
    data.frame(id = paste0("P", seq_len(n)), label = paste0("Provider ", seq_len(n)),
              popup = paste0("<b>Provider ", seq_len(n), "</b>"),
              lon = -97 + seq_len(n) * 0.3, lat = rep(40, n)),
    coords = c("lon", "lat"), crs = 4326)
}

.inv_geo_multi <- function() {
  sf::st_sf(
    mm_id = c("A", "B", "C"), mm_label = c("A", "B", "C"),
    mm_popup = c("<b>A</b>", "<b>B</b>", "<b>C</b>"),
    mm_fill_time = c("#2166ac", "#67a9cf", "#d1e5f0"),
    mm_fill_supply = c("#67a9cf", "#2166ac", "#d1e5f0"),
    mm_no_access = c(TRUE, FALSE, FALSE),
    geometry = sf::st_geometry(.inv_counties()))
}

.inv_providers_mm <- function(n = 2) {
  pts <- .inv_points(n)
  pts$mm_id <- pts$id; pts$mm_label <- pts$label; pts$mm_popup <- pts$popup
  pts
}

# ---- one builder per leaflet-returning function, each tagged with what it supports ----

.builders <- list(
  choropleth_point_map = list(
    zero_aware = TRUE, has_layerid = FALSE, n_points = 2,
    build = function() {
      mysterymaps_choropleth_point_map(
        list(Count = .inv_counties()), .inv_points(2), point_fill = "#c2185b")
    }),
  county_access_map = list(
    zero_aware = TRUE, has_layerid = FALSE, n_points = 2,
    build = function() {
      mysterymaps_county_access_map(
        .inv_counties(), value_col = "n", label_col = "label", popup_col = "popup",
        points = .inv_points(2), point_label_col = "label", point_popup_col = "popup",
        search = NULL)
    }),
  access_choropleth_map = list(
    zero_aware = FALSE, has_layerid = TRUE, n_points = 2,
    build = function() {
      mysterymaps_access_choropleth_map(
        .inv_geo_multi(), .inv_providers_mm(2),
        highlight_lookup = list(A = "P1", B = "P2"),
        supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1),
        band_colors = c("#2166ac", "#67a9cf", "#d1e5f0"),
        band_labels = c("<=30 min", "<=60 min", ">60 min"),
        title_html = "<b>Example</b>")
    }),
  access_choropleth_map_multi = list(
    zero_aware = FALSE, has_layerid = TRUE, n_points = 2,
    build = function() {
      mysterymaps_access_choropleth_map_multi(
        geos = list(County = list(sf = .inv_geo_multi(),
                                  supply_pal = leaflet::colorNumeric("Blues", c(0, 1)),
                                  supply_values = c(0, 1))),
        providers = .inv_providers_mm(2), highlight_lookup = list(A = "P1", B = "P2"),
        band_colors = c("#2166ac", "#67a9cf", "#d1e5f0"),
        band_labels = c("<=30 min", "<=60 min", ">60 min"),
        title_html = "<b>Example</b>")
    })
)

.build <- function(name) .builders[[name]]$build()

# ---- call-structure accessors (positions pinned empirically; see commit msg) ----

.calls_of <- function(m, method) Filter(function(cl) identical(cl$method, method), m$x$calls)
.poly_fill     <- function(cl) cl$args[[4]]$fillColor
.poly_group    <- function(cl) cl$args[[3]]
.poly_layerid  <- function(cl) cl$args[[2]]
.marker_fill   <- function(cl) cl$args[[6]]$fillColor
.marker_group  <- function(cl) cl$args[[5]]
.marker_layerid <- function(cl) cl$args[[4]]
.legend_colors <- function(cl) cl$args[[1]]$colors
.legend_labels <- function(cl) cl$args[[1]]$labels

.is_hex_colour <- function(x) grepl("^#[0-9A-Fa-f]{3}$|^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$", x)

# `group` is one string per addPolygons()/addCircleMarkers() CALL (every
# feature in that call shares it) but is sometimes NULL (a groupless layer,
# e.g. mysterymaps_county_access_map()'s unfilled mesh outline, deliberately
# left out of every base group so it stays visible under all of them).
# `layerId` is the opposite shape: a per-FEATURE vector (one id per row,
# typically `~mm_id`), not one id per call.
.poly_groups_all    <- function(m) unlist(lapply(.calls_of(m, "addPolygons"), .poly_group))
.marker_groups_all  <- function(m) unlist(lapply(.calls_of(m, "addCircleMarkers"), .marker_group))
.poly_layerids_all   <- function(m) unlist(lapply(.calls_of(m, "addPolygons"), .poly_layerid))
.marker_layerids_all <- function(m) unlist(lapply(.calls_of(m, "addCircleMarkers"), .marker_layerid))

# =============================================================================
# INVARIANT 1: every builder returns a `leaflet` htmlwidget.
# =============================================================================
testthat::test_that("INVARIANT: every leaflet map builder returns a leaflet htmlwidget", {
  skip_unless_spatial()
  for (nm in names(.builders)) {
    m <- suppressWarnings(.build(nm))
    testthat::expect_true(inherits(m, "leaflet"), info = nm)
    testthat::expect_true(inherits(m, "htmlwidget"), info = nm)
  }
})

# =============================================================================
# INVARIANT 2: zero-aware builders never colour an exact 0 the same as any
# positive value. This is the whole point of mysterymaps_jenks_zero_scale();
# a colour collision here means a reader cannot tell "no provider" from
# "a provider happens to be rare", which this package has treated as a
# correctness bug (not a cosmetic one) in every map built on top of it.
# =============================================================================
testthat::test_that("INVARIANT: an exact-zero feature's colour never collides with a positive feature's", {
  skip_unless_spatial()
  zero_aware_builders <- names(Filter(function(b) b$zero_aware, .builders))
  testthat::expect_true(length(zero_aware_builders) > 0L)  # the fixture must exercise >=1 builder
  for (nm in zero_aware_builders) {
    m <- suppressWarnings(.build(nm))
    polys <- .calls_of(m, "addPolygons")
    # The one layer shaded by the zero-aware value column (mysterymaps_county_access_map
    # also adds an unfilled mesh outline with no fillColor; skip those).
    shaded <- Filter(function(cl) !is.null(.poly_fill(cl)) && length(.poly_fill(cl)) == 3L, polys)
    testthat::expect_true(length(shaded) == 1L, info = nm)
    fill <- .poly_fill(shaded[[1]])
    zero_colour <- fill[1]       # row 1 of .inv_counties() is the n = 0 row
    positive_colours <- fill[-1]
    testthat::expect_false(zero_colour %in% positive_colours, info = nm)
  }
})

# =============================================================================
# INVARIANT 3: every explicit legend's colours and labels are the same length.
# A mismatch doesn't error -- leaflet just mislabels or truncates colours
# silently, which is strictly worse than a crash.
# =============================================================================
testthat::test_that("INVARIANT: every legend's colours and labels have matching length", {
  skip_unless_spatial()
  for (nm in names(.builders)) {
    m <- suppressWarnings(.build(nm))
    legends <- .calls_of(m, "addLegend")
    testthat::expect_true(length(legends) > 0L, info = nm)
    for (leg in legends) {
      cols <- .legend_colors(leg); labs <- .legend_labels(leg)
      # A continuous pal=/values= legend renders `colors` as a single CSS
      # gradient string (not one colour per class) and `labels` as the break
      # ticks along it -- a different, leaflet-internal contract from the
      # discrete colors=/labels= pairing this invariant is actually about.
      if (is.null(cols) || is.null(labs)) next
      if (length(cols) == 1L && length(labs) != 1L) next
      testthat::expect_true(length(cols) == length(labs), info = paste(nm, "legend"))
    }
  }
})

# =============================================================================
# INVARIANT 4: every group name used in a multi-layer map is unique. Leaflet's
# layer-toggle, the base-legend switcher, and this package's own per-layer
# legend-visibility JS (mysterymaps_choropleth_point_map(), the combined_js in
# mysterymaps_access_choropleth_map_multi()) all key off the group NAME --
# two layers sharing a name make one toggle control both, silently.
# =============================================================================
testthat::test_that("INVARIANT: group names are never reused for two different layers", {
  skip_unless_spatial()
  for (nm in names(.builders)) {
    m <- suppressWarnings(.build(nm))
    poly_groups   <- .poly_groups_all(m)
    marker_groups <- .marker_groups_all(m)
    all_groups <- c(poly_groups, marker_groups)
    all_groups <- all_groups[nzchar(all_groups)]
    testthat::expect_identical(all_groups, unique(all_groups), info = nm)
  }
})

# =============================================================================
# INVARIANT 5: where a function supports click-to-highlight (layerId-keyed),
# every layerId within one map is unique. A collision means
# map$layerManager$getLayer(id) resolves to the WRONG feature -- clicking one
# county would light up another county's providers.
# =============================================================================
testthat::test_that("INVARIANT: layerIds are unique within a single click-to-highlight map", {
  skip_unless_spatial()
  highlight_builders <- names(Filter(function(b) b$has_layerid, .builders))
  testthat::expect_true(length(highlight_builders) > 0L)
  for (nm in highlight_builders) {
    m <- suppressWarnings(.build(nm))
    poly_ids   <- .poly_layerids_all(m)
    marker_ids <- .marker_layerids_all(m)
    all_ids <- c(poly_ids, marker_ids)
    all_ids <- all_ids[nzchar(all_ids)]
    testthat::expect_identical(all_ids, unique(all_ids), info = nm)
  }
})

# =============================================================================
# INVARIANT 6: every row of the input point layer becomes exactly one rendered
# marker. A silent drop (e.g. an invalid-geometry filter upstream) would
# under-report providers with no error anywhere in the pipeline.
# =============================================================================
testthat::test_that("INVARIANT: every input point becomes exactly one marker, none dropped or duplicated", {
  skip_unless_spatial()
  for (nm in names(.builders)) {
    info <- .builders[[nm]]
    m <- suppressWarnings(.build(nm))
    marker_calls <- .calls_of(m, "addCircleMarkers")
    # The provider layer is the one marker call carrying as many rows as the
    # point fixture -- other addCircleMarkers calls in these functions are
    # invisible search-anchor points (radius ~0.1, one per polygon, not per
    # provider), which this invariant is not about.
    provider_calls <- Filter(function(cl) length(cl$args[[1]]) == info$n_points, marker_calls)
    testthat::expect_true(length(provider_calls) == 1L, info = nm)
  }
})

# =============================================================================
# INVARIANT 7: every colour actually emitted into a fillColor/color vector is
# a syntactically valid hex colour. An NA or empty string wouldn't error --
# leaflet silently falls back to a default/transparent render, which reads as
# "this feature has a value" when it does not.
# =============================================================================
testthat::test_that("INVARIANT: every fillColor/color value emitted is a valid hex colour", {
  skip_unless_spatial()
  for (nm in names(.builders)) {
    m <- suppressWarnings(.build(nm))
    for (cl in .calls_of(m, "addPolygons")) {
      for (field in c("fillColor", "color")) {
        vals <- cl$args[[4]][[field]]
        if (is.null(vals) || !is.character(vals)) next
        testthat::expect_true(all(.is_hex_colour(vals)), info = paste(nm, field))
      }
    }
    for (cl in .calls_of(m, "addCircleMarkers")) {
      for (field in c("fillColor", "color")) {
        vals <- cl$args[[6]][[field]]
        if (is.null(vals) || !is.character(vals)) next
        testthat::expect_true(all(.is_hex_colour(vals)), info = paste(nm, field))
      }
    }
  }
})

# =============================================================================
# INVARIANT 8: every builder's output is self-contained and saveable. This is
# the invariant a reader actually depends on -- a map that fails to save, or
# saves with broken/missing dependencies, is not a map at all.
# =============================================================================
testthat::test_that("INVARIANT: every map saves as a non-trivial, self-contained HTML file", {
  skip_unless_spatial()
  testthat::skip_if_not_installed("htmlwidgets")
  for (nm in names(.builders)) {
    m <- suppressWarnings(.build(nm))
    dest <- withr::local_tempfile(fileext = ".html")
    err <- tryCatch({
      htmlwidgets::saveWidget(m, dest, selfcontained = TRUE)
      NULL
    }, error = function(e) e)
    testthat::expect_true(is.null(err), info = paste(nm, if (!is.null(err)) conditionMessage(err) else ""))
    testthat::expect_true(file.info(dest)$size > 10000, info = nm)
  }
})
