mk_counties <- function(n = 6) {
  skip_if_not_installed("sf")
  polys <- lapply(seq_len(n), function(i) {
    x <- -100 + i; y <- 40
    sf::st_polygon(list(cbind(c(x, x+1, x+1, x, x), c(y, y, y+1, y+1, y))))
  })
  # rep_len, not a literal of six: the rates used to be hard-coded at length 6
  # while the geometry followed n, so any n but the default failed in st_sf().
  # Two zeroes stay first -- zero is its own colour class and needs to exist.
  sf::st_sf(rate = rep_len(c(0, 0, 1.5, 3, 8, 20), n),
            tooltip = paste0("<b>County ", seq_len(n), "</b>"),
            profile = paste0("County ", seq_len(n), " profile."),
            geometry = sf::st_sfc(polys, crs = 4326))
}

test_that("the template returns a leaflet map with the county layer", {
  skip_if_not_installed("leaflet")
  m <- mysterymaps_county_access_map(mk_counties(), "rate", "tooltip", "profile",
                                     notes = NULL, search = NULL)
  expect_s3_class(m, "leaflet")
  calls <- vapply(m$x$calls, function(c) c$method, character(1))
  expect_true("addPolygons" %in% calls)
  expect_true("addLegend" %in% calls)
})

test_that("a missing column is named, not silently ignored", {
  skip_if_not_installed("leaflet")
  expect_error(
    mysterymaps_county_access_map(mk_counties(), "nope", "tooltip", "profile"),
    "no column 'nope'")
})

test_that("REGRESSION: points use no custom pane, and canvas is shared", {
  skip_if_not_installed("sf")
  skip_if_not_installed("leaflet")
  pts <- sf::st_as_sf(data.frame(name = c("A Person", "B Person"),
                                 pop = c("<b>A</b>", "<b>B</b>"),
                                 lon = c(-99.5, -98.5), lat = c(40.5, 40.5)),
                      coords = c("lon", "lat"), crs = 4326)
  m <- mysterymaps_county_access_map(mk_counties(), "rate", "tooltip", "profile",
                                     points = pts, point_label_col = "name",
                                     point_popup_col = "pop", search = NULL)
  # A high-zIndex pane gives markers their own canvas covering the whole map,
  # and that canvas swallows every click -- including on empty ground. On the
  # midwifery map this silently disabled all 3,109 county popups.
  calls <- vapply(m$x$calls, function(c) c$method, character(1))
  expect_false("addMapPane" %in% calls)
  expect_true(isTRUE(m$x$options$preferCanvas))
})

test_that("the notes panel renders vintages, linking those that have a URL", {
  skip_if_not_installed("leaflet")
  v <- data.frame(source = c("AMCB roster", "ACS"), vintage = c("2026", "2019-2023"),
                  url = c("https://example.org", NA))
  m <- mysterymaps_county_access_map(
    mk_counties(), "rate", "tooltip", "profile", search = NULL,
    notes = list(title = "Notes", sections = list("Shading" = "is a rate."),
                 vintages = v, as_of = "2026"))
  ctl <- Filter(function(c) c$method == "addControl", m$x$calls)
  html <- paste(vapply(ctl, function(c) as.character(c$args[[1]]), character(1)),
                collapse = "")
  expect_match(html, "Data as of 2026")
  expect_match(html, "AMCB roster")
  expect_match(html, "2019-2023")
  expect_match(html, 'href="https://example.org"', fixed = TRUE)
})

test_that("a No data entry reaches the rendered legend when counties are NA", {
  skip_if_not_installed("leaflet")
  # The Colorado fixture carries two measured zeroes and two unmeasured
  # counties on purpose. Both must survive every stage between the data frame
  # and the legend -- the distinction is worthless if it is lost in assembly.
  co <- co_counties()
  co$tip <- paste0("<b>", co$name, "</b>")
  co$profile <- co$name
  m <- suppressWarnings(
    mysterymaps_county_access_map(co, "rate", "tip", "profile",
                                  notes = NULL, search = NULL))
  leg <- Filter(function(c) c$method == "addLegend", m$x$calls)
  expect_length(leg, 1L)
  expect_true("No data" %in% unlist(leg[[1]]$args))
  expect_true("#e0e0e0" %in% unlist(leg[[1]]$args))
})

test_that("legend_labels must match the legend it is replacing", {
  skip_if_not_installed("leaflet")
  # An NA county adds a legend entry, so a hand-written label vector sized for
  # complete data is now wrong. It must say so rather than shift every label.
  co <- co_counties()
  co$tip <- co$profile <- co$name
  expect_error(
    suppressWarnings(
      mysterymaps_county_access_map(co, "rate", "tip", "profile", search = NULL,
                                    legend_labels = c("none", "low", "high"))),
    "legend_labels has 3 entries")
})

test_that("notes refuse to render without a vintage table", {
  # A map whose sources span 2013 to 2026 and says only "2026" asserts a
  # currency it does not have.
  # Matched, not bare: an unmatched expect_error() also passes when the call
  # fails for an unrelated reason, which would hide the requirement itself.
  expect_error(mysterymaps_notes_panel(structure(list(), class = "leaflet"),
                                       title = "N", sections = list(a = "b"),
                                       vintages = list()),
               "is.data.frame\\(vintages\\)")
})
