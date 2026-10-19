testthat::local_edition(3)

skip_unless_spatial <- function() {
  testthat::skip_if_not_installed("sf")
  testthat::skip_if_not_installed("leaflet")
  testthat::skip_if_not_installed("leaflet.extras")
}

.geo <- function(ids = c("A", "B"), no_access = c(TRUE, FALSE), extra = list()) {
  n <- length(ids)
  base <- list(
    mm_id = ids, mm_label = ids, mm_popup = paste0("<b>", ids, "</b>"),
    mm_fill_time = rep("#2166ac", n), mm_fill_supply = rep("#67a9cf", n),
    mm_no_access = no_access)
  df <- c(base, extra)
  sf::st_sf(as.data.frame(df[setdiff(names(df), "geometry")]),
           geometry = sf::st_sfc(lapply(seq_len(n), function(i) {
             x <- -100 + i
             sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x), c(39, 39, 41, 41, 39))))
           }), crs = 4326))
}

.providers <- function() {
  sf::st_as_sf(data.frame(mm_id = "P1", mm_label = "P1", mm_popup = "<b>P1</b>",
                          lon = -99, lat = 40), coords = c("lon", "lat"), crs = 4326)
}

.BC <- c("#2166ac", "#67a9cf")
.BL <- c("<=30 min", ">30 min")

# Searches every arg of a widget call (named or positional, nested or not) for
# a regex, without depending on leaflet's internal positional arg order.
.call_has_text <- function(cl, pattern) {
  any(vapply(cl$args, function(a) {
    s <- tryCatch(paste(unlist(a), collapse = "|"), error = function(e) "")
    grepl(pattern, s)
  }, logical(1)))
}

# ---- mysterymaps_access_choropleth_map() -----------------------------------

testthat::test_that("builds a leaflet widget with a time legend and a supply legend", {
  skip_unless_spatial()
  m <- mysterymaps_access_choropleth_map(
    .geo(), .providers(), highlight_lookup = list(A = "P1"),
    supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1),
    band_colors = .BC, band_labels = .BL, title_html = "<b>Example</b>")
  testthat::expect_s3_class(m, "leaflet")
  legends <- Filter(function(cl) cl$method == "addLegend", m$x$calls)
  testthat::expect_length(legends, 2L)
})

testthat::test_that("REGRESSION: the time and supply legends never show at once", {
  # addLegend(group=) only follows OVERLAY groups; time/supply are BASE
  # groups, so the original implementation showed both legends
  # simultaneously. The fix: each legend carries an mm-lg/mm-lg-<key> class,
  # and a baselayerchange listener (mysterymaps_base_legend_switcher()) shows
  # only the active one.
  skip_unless_spatial()
  m <- mysterymaps_access_choropleth_map(
    .geo(), .providers(), highlight_lookup = list(A = "P1"),
    supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1),
    band_colors = .BC, band_labels = .BL, title_html = "<b>Example</b>")
  legends <- Filter(function(cl) cl$method == "addLegend", m$x$calls)
  classNames <- vapply(legends, function(cl) cl$args[[1]]$className, character(1))
  testthat::expect_true(all(grepl("mm-lg", classNames)))
  testthat::expect_true(any(grepl("mm-lg-time", classNames)))
  testthat::expect_true(any(grepl("mm-lg-supply", classNames)))
  js <- m$jsHooks$render[[length(m$jsHooks$render)]]$code
  testthat::expect_match(js, "baselayerchange")
})

testthat::test_that("a missing required `mm_*` column names itself in the error", {
  skip_unless_spatial()
  geo <- .geo()
  geo$mm_fill_time <- NULL
  testthat::expect_error(
    mysterymaps_access_choropleth_map(
      geo, .providers(), highlight_lookup = list(A = "P1"),
      supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1),
      band_colors = .BC, band_labels = .BL, title_html = "<b>Example</b>"),
    "mm_fill_time")
})

# ---- mysterymaps_access_choropleth_map_multi() -----------------------------

.multi_defaults <- function() {
  list(
    geos = list(County = list(sf = .geo(),
                              supply_pal = leaflet::colorNumeric("Blues", c(0, 1)),
                              supply_values = c(0, 1))),
    providers = .providers(), highlight_lookup = list(A = "P1"),
    band_colors = .BC, band_labels = .BL, title_html = "<b>Example</b>")
}

# A plain top-level override (never a recursive modifyList merge): an sf
# object IS a list under the hood, so merging a replacement `geos` entry
# recursively would silently keep columns from the default fixture instead
# of actually replacing it -- exactly the kind of silent-corruption hazard
# this package's own tests exist to avoid introducing elsewhere.
.multi_args <- function(...) {
  args <- .multi_defaults()
  overrides <- list(...)
  for (nm in names(overrides)) args[[nm]] <- overrides[[nm]]
  args
}

testthat::test_that("builds base groups per geography", {
  skip_unless_spatial()
  m <- do.call(mysterymaps_access_choropleth_map_multi, .multi_args())
  testthat::expect_s3_class(m, "leaflet")
  layers_call <- Filter(function(cl) cl$method == "addLayersControl", m$x$calls)[[1]]
  base_groups <- layers_call$args[[1]]
  testthat::expect_true("County: drive time" %in% base_groups)
  testthat::expect_true("County: supply" %in% base_groups)
})

testthat::test_that("a missing required `mm_*` column names the geography and the column", {
  skip_unless_spatial()
  geo <- .geo(); geo$mm_fill_supply <- NULL
  testthat::expect_error(
    do.call(mysterymaps_access_choropleth_map_multi,
           .multi_args(geos = list(County = list(
             sf = geo, supply_pal = leaflet::colorNumeric("Blues", c(0, 1)),
             supply_values = c(0, 1))))),
    "County.*mm_fill_supply")
})

testthat::test_that("provider_noun defaults to 'provider' and flows into the isochrone-band label", {
  skip_unless_spatial()
  iso_union <- sf::st_sf(band = c(30, 60), geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-99, -97, -97, -99, -99), c(39, 39, 41, 41, 39)))),
    sf::st_polygon(list(cbind(c(-99.5, -96.5, -96.5, -99.5, -99.5), c(38.5, 38.5, 41.5, 41.5, 38.5)))),
    crs = 4326))
  m <- do.call(mysterymaps_access_choropleth_map_multi, .multi_args(iso_union = iso_union))
  iso_call <- Filter(function(cl) cl$method == "addPolygons" &&
                       identical(cl$args[[3]], "Isochrone reach"), m$x$calls)[[1]]
  testthat::expect_true(.call_has_text(iso_call, "of a provider"))
})

testthat::test_that("provider_noun overrides the isochrone-band label text", {
  skip_unless_spatial()
  iso_union <- sf::st_sf(band = 30, geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-99, -97, -97, -99, -99), c(39, 39, 41, 41, 39)))), crs = 4326))
  m <- do.call(mysterymaps_access_choropleth_map_multi,
              .multi_args(iso_union = iso_union, provider_noun = "urogynecologist"))
  iso_call <- Filter(function(cl) cl$method == "addPolygons" &&
                       identical(cl$args[[3]], "Isochrone reach"), m$x$calls)[[1]]
  testthat::expect_true(.call_has_text(iso_call, "of a urogynecologist"))
})

testthat::test_that("isochrone band colours derive from the bands actually present, not a hardcoded set", {
  skip_unless_spatial()
  iso_union <- sf::st_sf(band = c(15, 45), geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-99, -97, -97, -99, -99), c(39, 39, 41, 41, 39)))),
    sf::st_polygon(list(cbind(c(-99.5, -96.5, -96.5, -99.5, -99.5), c(38.5, 38.5, 41.5, 41.5, 38.5)))),
    crs = 4326))
  m <- do.call(mysterymaps_access_choropleth_map_multi, .multi_args(iso_union = iso_union))
  iso_call <- Filter(function(cl) cl$method == "addPolygons" &&
                       identical(cl$args[[3]], "Isochrone reach"), m$x$calls)[[1]]
  testthat::expect_setequal(iso_call$args[[4]]$color, .BC)
})

testthat::test_that("coverage_metric_label falls back to 'Coverage' and can be overridden", {
  skip_unless_spatial()
  geo_cov <- .geo(extra = list(mm_fill_coverage = c("#2166ac", "#67a9cf")))
  geo_entry <- list(County = list(
    sf = geo_cov, supply_pal = leaflet::colorNumeric("Blues", c(0, 1)), supply_values = c(0, 1),
    coverage_pal = leaflet::colorNumeric("Greens", c(0, 100)), coverage_values = c(0, 100)))

  m1 <- do.call(mysterymaps_access_choropleth_map_multi, .multi_args(geos = geo_entry))
  panel1 <- Filter(function(cl) cl$method == "addControl" &&
                     .call_has_text(cl, "mmp-geo"), m1$x$calls)[[1]]$args[[1]]
  testthat::expect_match(panel1, "value='coverage'> Coverage<")

  m2 <- do.call(mysterymaps_access_choropleth_map_multi,
               .multi_args(geos = geo_entry, coverage_metric_label = "My Coverage"))
  panel2 <- Filter(function(cl) cl$method == "addControl" &&
                     .call_has_text(cl, "mmp-geo"), m2$x$calls)[[1]]$args[[1]]
  testthat::expect_match(panel2, "value='coverage'> My Coverage<")
})

testthat::test_that("centroid_label drives both the toggle label and the marker popup heading", {
  skip_unless_spatial()
  cent <- sf::st_as_sf(data.frame(mm_label = "County", lon = -99, lat = 40),
                       coords = c("lon", "lat"), crs = 4326)
  m <- do.call(mysterymaps_access_choropleth_map_multi,
              .multi_args(centroids_by_geo = list(County = cent),
                         centroid_label = "Analysis point (women 65+ weighted)"))
  panel <- Filter(function(cl) cl$method == "addControl" &&
                    .call_has_text(cl, "mmp-geo"), m$x$calls)[[1]]$args[[1]]
  testthat::expect_match(panel, "Analysis point \\(women 65\\+ weighted\\)")
  marker_call <- Filter(function(cl) cl$method == "addCircleMarkers" &&
                          isTRUE(cl$args[[5]] == "County: centroid"), m$x$calls)[[1]]
  testthat::expect_true(.call_has_text(marker_call, "Analysis point \\(women 65\\+ weighted\\)"))
})

testthat::test_that("aria_label and desert_tooltip fall back to provider_noun-derived defaults", {
  skip_unless_spatial()
  m <- do.call(mysterymaps_access_choropleth_map_multi,
              .multi_args(provider_noun = "urogynecologist"))
  data_arg <- m$jsHooks$render[[length(m$jsHooks$render)]]$data
  testthat::expect_identical(data_arg$ariaLabel, "Interactive map of access to urogynecologists")
  panel <- Filter(function(cl) cl$method == "addControl" &&
                    .call_has_text(cl, "mmp-geo"), m$x$calls)[[1]]$args[[1]]
  testthat::expect_match(panel, "no urogynecologist in range")
})

testthat::test_that("aria_label and desert_tooltip can be overridden explicitly", {
  skip_unless_spatial()
  m <- do.call(mysterymaps_access_choropleth_map_multi,
              .multi_args(provider_noun = "urogynecologist",
                         aria_label = "Interactive map of access to urogynecologists",
                         desert_tooltip = "purple outline = no urogynecologist within 180 min"))
  data_arg <- m$jsHooks$render[[length(m$jsHooks$render)]]$data
  testthat::expect_identical(data_arg$ariaLabel, "Interactive map of access to urogynecologists")
  panel <- Filter(function(cl) cl$method == "addControl" &&
                    .call_has_text(cl, "mmp-geo"), m$x$calls)[[1]]$args[[1]]
  testthat::expect_match(panel, "purple outline = no urogynecologist within 180 min")
})
