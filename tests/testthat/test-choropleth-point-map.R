testthat::local_edition(3)

skip_unless_spatial <- function() {
  testthat::skip_if_not_installed("sf")
  testthat::skip_if_not_installed("leaflet")
  testthat::skip_if_not_installed("leaflet.extras")
}

.layer <- function(n = c(0L, 4L)) {
  sf::st_sf(
    id = seq_along(n), n = n, label = paste("County", seq_along(n)),
    popup = paste0("<b>County ", seq_along(n), "</b>"),
    geometry = sf::st_sfc(lapply(seq_along(n), function(i) {
      x <- -100 + i
      sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x), c(40, 40, 41, 41, 40))))
    }), crs = 4326))
}

.points <- function() {
  sf::st_as_sf(data.frame(lon = -98.5, lat = 40.5, label = "Provider", popup = "<b>Provider</b>"),
              coords = c("lon", "lat"), crs = 4326)
}

testthat::test_that("builds a leaflet widget with one polygon layer per named group", {
  skip_unless_spatial()
  m <- mysterymaps_choropleth_point_map(list(Count = .layer()), .points(), point_fill = "#c2185b")
  testthat::expect_s3_class(m, "leaflet")
  methods <- vapply(m$x$calls, function(cl) cl$method, character(1))
  testthat::expect_true("addPolygons" %in% methods)
  testthat::expect_true("addCircleMarkers" %in% methods)
})

testthat::test_that("each layer gets its own legend, and only the default layer's shows", {
  skip_unless_spatial()
  m <- suppressWarnings(mysterymaps_choropleth_point_map(
    list(A = .layer(), B = .layer(c(1L, 2L))), .points(), point_fill = "#c2185b",
    default_layer = "B"))
  classNames <- vapply(Filter(function(cl) cl$method == "addLegend", m$x$calls),
                       function(cl) cl$args[[1]]$className, character(1))
  testthat::expect_true(any(grepl("leg-A", classNames)))
  testthat::expect_true(any(grepl("leg-B", classNames)))
  js <- m$jsHooks$render[[length(m$jsHooks$render)]]$code
  testthat::expect_match(js, "show\\('B'\\)")
})

testthat::test_that("default_layer must be one of the names of `layers`", {
  skip_unless_spatial()
  testthat::expect_error(
    mysterymaps_choropleth_point_map(list(A = .layer()), .points(), point_fill = "#c2185b",
                                     default_layer = "nope"))
})

testthat::test_that("a zero-count layer still gets its own zero class, not folded into the gradient", {
  skip_unless_spatial()
  m <- mysterymaps_choropleth_point_map(list(Count = .layer(c(0L, 0L, 5L))), .points(),
                                        point_fill = "#c2185b")
  leg <- Filter(function(cl) cl$method == "addLegend", m$x$calls)[[1]]
  testthat::expect_true(any(grepl("^0$|0", leg$args[[1]]$labels)))
})

testthat::test_that("point_legend adds a separate top-right legend", {
  skip_unless_spatial()
  m <- mysterymaps_choropleth_point_map(
    list(Count = .layer()), .points(), point_fill = "#c2185b",
    point_legend = list(colors = "#c2185b", labels = "Provider", title = "Legend"))
  legends <- Filter(function(cl) cl$method == "addLegend", m$x$calls)
  testthat::expect_length(legends, 2L)   # 1 choropleth + 1 point legend
})
