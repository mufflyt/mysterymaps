# Coverage surfaces are base groups with per-group legends. leaflet cannot do
# that on its own -- addLegend(group=) follows OVERLAY groups only -- so the
# registration attribute and the baselayerchange handler are the mechanism, and
# these tests are what keep them wired together.

test_that("one polygon and one legend are added per surface", {
  skip_if_not_installed("leaflet")
  m <- mysterymaps_add_coverage_surfaces(
    leaflet::leaflet(),
    surfaces = list("Within 30 minutes" = mm_surface(),
                    "Within 60 minutes" = mm_surface(w = 6)),
    colors = c("#08519c", "#3182bd"))

  calls <- mm_calls(m)
  expect_equal(sum(calls == "addPolygons"), 2L)
  expect_equal(sum(calls == "addLegend"), 2L)
})

test_that("group names come from the surfaces list, in order", {
  skip_if_not_installed("leaflet")
  m <- mysterymaps_add_coverage_surfaces(
    leaflet::leaflet(),
    surfaces = list("Within 30 minutes" = mm_surface(),
                    "Beyond 60 minutes" = mm_surface(w = 6)),
    colors = c("#08519c", "#cccccc"))

  reg <- attr(m, "mysterymaps_base_legends")
  expect_named(reg, c("Within 30 minutes", "Beyond 60 minutes"))
})

test_that("each legend carries the mm-lg class pair the switcher looks for", {
  # The handler hides ".mm-lg" and then shows ".mm-lg-<key>". A legend missing
  # either class is a legend that never reappears.
  skip_if_not_installed("leaflet")
  m <- mysterymaps_add_coverage_surfaces(
    leaflet::leaflet(),
    surfaces = list(A = mm_surface(), B = mm_surface(w = 6)),
    colors = "#08519c")

  legends <- Filter(function(cl) cl$method == "addLegend", m$x$calls)
  classes <- vapply(legends, function(cl) {
    args <- cl$args[[1]]
    as.character(args$className %||% args[["className"]] %||% "")
  }, character(1))

  expect_true(all(grepl("mm-lg", classes)))
  expect_true(any(grepl("mm-lg-s1", classes)))
  expect_true(any(grepl("mm-lg-s2", classes)))
})

test_that("colors, labels and titles recycle to the number of surfaces", {
  skip_if_not_installed("leaflet")
  m <- mysterymaps_add_coverage_surfaces(
    leaflet::leaflet(),
    surfaces = list(A = mm_surface(), B = mm_surface(), C = mm_surface()),
    colors = "#08519c",                 # one colour, three surfaces
    legend_titles = "Coverage")
  expect_equal(sum(mm_calls(m) == "addPolygons"), 3L)
  expect_length(attr(m, "mysterymaps_base_legends"), 3L)
})

test_that("REGRESSION: the popup rides on the surface, not a duplicate polygon", {
  # Adding a second invisible polygon to carry the popup doubled the geometry
  # in the saved widget -- 19.9 MB to 29.6 MB on the midwifery map -- and an
  # unfilled, unstroked polygon has nothing to click anyway.
  skip_if_not_installed("leaflet")
  m <- mysterymaps_add_coverage_surfaces(
    leaflet::leaflet(),
    surfaces = list(A = mm_surface(), B = mm_surface(w = 6)),
    colors = c("#08519c", "#3182bd"),
    popups = c("<b>A</b>", "<b>B</b>"))

  expect_equal(sum(mm_calls(m) == "addPolygons"), 2L)

  polys <- Filter(function(cl) cl$method == "addPolygons", m$x$calls)
  payload <- paste(vapply(polys, function(cl) paste(unlist(lapply(cl$args, as.character)),
                                                    collapse = " "),
                          character(1)), collapse = " ")
  expect_match(payload, "<b>A</b>", fixed = TRUE)
})

test_that("surfaces must be a NAMED list; group names are not optional", {
  skip_if_not_installed("leaflet")
  expect_error(
    mysterymaps_add_coverage_surfaces(leaflet::leaflet(),
                                      surfaces = list(mm_surface()),
                                      colors = "#08519c"))
  expect_error(
    mysterymaps_add_coverage_surfaces(leaflet::leaflet(),
                                      surfaces = list(), colors = "#08519c"))
})

test_that("registration accumulates rather than replacing", {
  # A choropleth legend registered first must survive the coverage surfaces
  # being added on top of it.
  skip_if_not_installed("leaflet")
  m <- mysterymaps_register_base_legend(leaflet::leaflet(), "Rate", key = "rate")
  m <- mysterymaps_add_coverage_surfaces(
    m, surfaces = list("Within 30 minutes" = mm_surface()), colors = "#08519c")

  reg <- attr(m, "mysterymaps_base_legends")
  expect_named(reg, c("Rate", "Within 30 minutes"))
  expect_identical(reg[["Rate"]], "rate")
})

test_that("a default key is a CSS-safe slug of the group name", {
  skip_if_not_installed("leaflet")
  m <- mysterymaps_register_base_legend(leaflet::leaflet(),
                                        "Within 30 minutes (drive)")
  key <- attr(m, "mysterymaps_base_legends")[["Within 30 minutes (drive)"]]
  expect_identical(key, "within30minutesdrive")
  expect_false(grepl("[^a-z0-9]", key))
})

test_that("the switcher attaches a baselayerchange handler naming the default", {
  skip_if_not_installed("leaflet")
  skip_if_not_installed("htmlwidgets")
  m <- mysterymaps_add_coverage_surfaces(
    leaflet::leaflet(),
    surfaces = list("Within 30 minutes" = mm_surface(),
                    "Within 60 minutes" = mm_surface(w = 6)),
    colors = c("#08519c", "#3182bd"))
  m <- mysterymaps_base_legend_switcher(m, default = "Within 60 minutes")

  js <- mm_onrender_js(m)
  expect_match(js, "baselayerchange", fixed = TRUE)
  expect_match(js, "Within 60 minutes", fixed = TRUE)
  expect_match(js, ".mm-lg", fixed = TRUE)
})

test_that("the switcher defaults to the first registered group", {
  skip_if_not_installed("leaflet")
  skip_if_not_installed("htmlwidgets")
  m <- mysterymaps_add_coverage_surfaces(
    leaflet::leaflet(),
    surfaces = list(First = mm_surface(), Second = mm_surface(w = 6)),
    colors = "#08519c")
  js <- mm_onrender_js(mysterymaps_base_legend_switcher(m))
  expect_match(js, 'DEF = "First"', fixed = TRUE)
})

test_that("the switcher is a no-op on a map with nothing registered", {
  # Documented as defensive: a base group with no legend leaves the legends
  # hidden rather than erroring.
  skip_if_not_installed("leaflet")
  m <- leaflet::leaflet()
  expect_identical(mysterymaps_base_legend_switcher(m), m)
})

test_that("zoom-gated labels encode the group, zoom floor and cap", {
  skip_if_not_installed("leaflet")
  skip_if_not_installed("htmlwidgets")
  js <- mm_onrender_js(
    mysterymaps_zoom_gated_labels(leaflet::leaflet(), group = "Providers",
                                  min_zoom = 11, max_labels = 250))
  expect_match(js, 'GRP = "Providers"', fixed = TRUE)
  expect_match(js, "MINZ = 11", fixed = TRUE)
  expect_match(js, "CAP = 250", fixed = TRUE)
})

test_that("zoom and cap are coerced to integers before reaching the JS", {
  # sprintf("%d", 9.0) errors on a double; a fractional zoom from a caller
  # would otherwise take out the whole map build.
  skip_if_not_installed("leaflet")
  skip_if_not_installed("htmlwidgets")
  js <- mm_onrender_js(
    mysterymaps_zoom_gated_labels(leaflet::leaflet(), group = "P",
                                  min_zoom = 9.0, max_labels = 400.0))
  expect_match(js, "MINZ = 9", fixed = TRUE)
  expect_match(js, "CAP = 400", fixed = TRUE)
})

test_that("the label handler refreshes on zoom, pan and layer add", {
  # Labels gated only on zoomend go stale the moment the reader pans.
  skip_if_not_installed("leaflet")
  skip_if_not_installed("htmlwidgets")
  js <- mm_onrender_js(
    mysterymaps_zoom_gated_labels(leaflet::leaflet(), group = "P"))
  expect_match(js, "zoomend moveend layeradd", fixed = TRUE)
})

test_that("a group name with quotes cannot break out of the generated JS", {
  skip_if_not_installed("leaflet")
  skip_if_not_installed("htmlwidgets")
  js <- mm_onrender_js(
    mysterymaps_zoom_gated_labels(leaflet::leaflet(), group = 'He said "hi"'))
  # jsonlite escapes it; an unescaped quote would terminate the string early.
  expect_match(js, '\\\\"hi\\\\"')
})
