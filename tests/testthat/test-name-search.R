# The name-search control. Its group detection reads an UNDOCUMENTED position
# in leaflet's widget call list -- argument 5 of addCircleMarkers -- so it is
# validated and skipped with a warning rather than attached to nothing. These
# tests are what keep that contract honest across leaflet releases.

test_that("marker groups are detected from the map when group is NULL", {
  skip_if_not_installed("leaflet")
  skip_if_not_installed("leaflet.extras")
  m <- leaflet::addCircleMarkers(leaflet::leaflet(), data = mm_points(),
                                 group = "Provider locations", label = ~name)
  out <- mysterymaps_name_search(m)
  expect_s3_class(out, "leaflet")
  expect_true("addSearchFeatures" %in% mm_calls(out))
})

test_that("REGRESSION: the detected group is the group name, not another argument", {
  # leaflet::invokeMethod passes (lat, lng, radius, layerId, group, ...). If
  # that order changes, the control gets attached to a radius and silently
  # searches nothing.
  skip_if_not_installed("leaflet")
  skip_if_not_installed("leaflet.extras")
  m <- leaflet::addCircleMarkers(leaflet::leaflet(), data = mm_points(),
                                 group = "Provider locations", label = ~name)
  out <- mysterymaps_name_search(m)
  args <- mm_call_args(out, "addSearchFeatures")
  expect_true("Provider locations" %in% unlist(args))
})

test_that("a map with no markers warns and is returned unchanged", {
  # A search box attached to nothing looks functional and does nothing, which
  # is worse than no search box.
  skip_if_not_installed("leaflet")
  skip_if_not_installed("leaflet.extras")
  m <- leaflet::leaflet()
  expect_warning(out <- mysterymaps_name_search(m), "no marker groups found")
  expect_false("addSearchFeatures" %in% mm_calls(out))
})

test_that("an explicit group is used without inspecting the map", {
  skip_if_not_installed("leaflet")
  skip_if_not_installed("leaflet.extras")
  out <- mysterymaps_name_search(leaflet::leaflet(), group = "Providers")
  expect_true("addSearchFeatures" %in% mm_calls(out))
  expect_true("Providers" %in% unlist(mm_call_args(out, "addSearchFeatures")))
})

test_that("several marker groups are all searched, without duplicates", {
  skip_if_not_installed("leaflet")
  skip_if_not_installed("leaflet.extras")
  m <- leaflet::leaflet()
  m <- leaflet::addCircleMarkers(m, data = mm_points(2), group = "A", label = ~name)
  m <- leaflet::addCircleMarkers(m, data = mm_points(2), group = "B", label = ~name)
  m <- leaflet::addCircleMarkers(m, data = mm_points(2), group = "A", label = ~name)

  args <- unlist(mm_call_args(mysterymaps_name_search(m), "addSearchFeatures"))
  groups <- args[args %in% c("A", "B")]
  expect_setequal(groups, c("A", "B"))
  expect_length(groups, 2L)
})

test_that("the placeholder and zoom reach the control options", {
  skip_if_not_installed("leaflet")
  skip_if_not_installed("leaflet.extras")
  out <- mysterymaps_name_search(leaflet::leaflet(), group = "P",
                                 placeholder = "Find a midwife",
                                 zoom = 13L, position = "topright")
  flat <- unlist(mm_call_args(out, "addSearchFeatures"))
  expect_true("Find a midwife" %in% flat)
  expect_true(13L %in% flat || "13" %in% as.character(flat))
  expect_true("topright" %in% flat)
})

test_that("REGRESSION: the plugin ships locally rather than from a CDN", {
  # An earlier version loaded leaflet-search from a CDN to save a few hundred
  # kilobytes in a 15-20 MB file. The cost was that the search box was inert
  # for anyone opening the saved map offline.
  skip_if_not_installed("leaflet")
  skip_if_not_installed("leaflet.extras")
  out <- mysterymaps_name_search(leaflet::leaflet(), group = "P")

  deps <- out$dependencies
  srcs <- vapply(deps, function(d) paste(unlist(d$src), collapse = " "),
                 character(1))
  expect_false(any(grepl("^https?://", srcs)))
  expect_true(any(grepl("search", vapply(deps, function(d) d$name, character(1)),
                        ignore.case = TRUE)))
})

test_that("without leaflet.extras it warns and returns the map untouched", {
  skip_if_not_installed("leaflet")
  local_mocked_bindings(
    requireNamespace = function(package, ...) !identical(package, "leaflet.extras"),
    .package = "base")
  m <- leaflet::leaflet()
  expect_warning(out <- mysterymaps_name_search(m), "leaflet.extras is not installed")
  expect_identical(out, m)
})
