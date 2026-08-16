# The two base-map constructors. They look interchangeable and are not:
# mysterymaps_map_leaflet() is fixed at a CONUS view, mysterymaps_map_base()
# takes a centre, a zoom and an optional title control. Both are the foundation
# every other map in the package is built on, so a silent change to either
# moves every map at once.

test_that("mysterymaps_map_leaflet returns a leaflet widget", {
  skip_if_not_installed("leaflet")
  m <- mysterymaps_map_leaflet()
  expect_s3_class(m, "leaflet")
})

test_that("both base tile providers are offered, and both are in the control", {
  # A layer control listing a group that was never added renders a radio
  # button that does nothing.
  skip_if_not_installed("leaflet")
  m <- mysterymaps_map_leaflet()

  provider_groups <- vapply(
    Filter(function(cl) cl$method == "addProviderTiles", m$x$calls),
    function(cl) as.character(cl$args[[3]]), character(1))
  expect_setequal(provider_groups, c("CartoDB Voyager", "Toner Lite"))

  control <- mm_call_args(m, "addLayersControl")
  expect_setequal(unlist(control[[1]]), provider_groups)
})

test_that("a scale bar and a layers control are present", {
  skip_if_not_installed("leaflet")
  calls <- mm_calls(mysterymaps_map_leaflet())
  expect_true("addScaleBar" %in% calls)
  expect_true("addLayersControl" %in% calls)
})

test_that("the default view is the geographic centre of the US", {
  # setView is stored on the widget rather than recorded as a call, so it is
  # read off x$setView: c(lat, lng) then zoom.
  skip_if_not_installed("leaflet")
  view <- mysterymaps_map_leaflet()$x$setView
  expect_equal(view[[1]], c(39.8282, -98.5795))
  expect_equal(view[[2]], 3)
})

test_that("mysterymaps_map_leaflet returns invisibly", {
  # It is meant to be assigned or piped, not auto-printed into a browser as a
  # side effect of being called at the top level.
  skip_if_not_installed("leaflet")
  expect_invisible(mysterymaps_map_leaflet())
})

test_that("mysterymaps_map_base centres where it is told", {
  skip_if_not_installed("leaflet")
  view <- mysterymaps_map_base(lat = 39.74, lng = -104.99, zoom = 9)$x$setView
  expect_equal(view[[1]], c(39.74, -104.99))
  expect_equal(view[[2]], 9)
})

test_that("mysterymaps_map_base adds no title control by default", {
  skip_if_not_installed("leaflet")
  expect_false("addControl" %in% mm_calls(mysterymaps_map_base()))
})

test_that("a title is rendered as HTML inside a control", {
  skip_if_not_installed("leaflet")
  skip_if_not_installed("htmltools")
  m <- mysterymaps_map_base("<strong>Access map</strong>")
  expect_true("addControl" %in% mm_calls(m))
  html <- paste(as.character(mm_call_args(m, "addControl")[[1]]), collapse = "")
  expect_match(html, "Access map", fixed = TRUE)
  expect_match(html, "mysterycall-map-title", fixed = TRUE)
})

test_that("an empty-string title is treated as no title", {
  # mysterymaps_plot_isochrones() calls mysterymaps_map_base("") for exactly
  # this reason; an empty control would draw a blank white box over the map.
  skip_if_not_installed("leaflet")
  expect_false("addControl" %in% mm_calls(mysterymaps_map_base("")))
})

test_that("both constructors refuse to run without leaflet, by name", {
  # The error has to say which package to install; "could not find function
  # addProviderTiles" does not.
  local_mocked_bindings(
    requireNamespace = function(pkg, ...) if (pkg == "leaflet") FALSE else TRUE,
    .package = "base")
  expect_error(mysterymaps_map_leaflet(), "'leaflet' is required")
  expect_error(mysterymaps_map_base(), "'leaflet' is required")
})
