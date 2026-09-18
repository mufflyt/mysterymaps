# The ported dot map must actually draw its points.
#
# The function this was ported from rendered maps with NO DOTS: it reported
# success, printed the physician count into the caption, and produced a
# complete-looking map whose entire subject was missing. Nothing errored and no
# test went red. These assertions exist so that cannot recur here.

testthat::local_edition(3)

skip_unless_spatial <- function() {
  testthat::skip_if_not_installed("sf")
  testthat::skip_if_not_installed("ggplot2")
}

fixture <- function(n = 12L) {
  set.seed(1)
  pts <- sf::st_as_sf(
    data.frame(id = seq_len(n),
               grp = rep(c("a", "b"), length.out = n),
               lon = runif(n, -120, -75),
               lat = runif(n, 26, 47)),
    coords = c("lon", "lat"), crs = 4326)
  poly <- sf::st_as_sf(sf::st_sfc(
    sf::st_polygon(list(cbind(c(-125, -66, -66, -125, -125),
                              c(24, 24, 50, 50, 24)))), crs = 4326))
  list(pts = pts, poly = poly)
}

testthat::test_that("the point layer reaches the plot", {
  # THE regression. Counting layers is the check the original would have failed:
  # its assembled plot carried states, a north arrow and a scale bar, and no
  # physician layer, while 601 points had reached the plotting code.
  skip_unless_spatial()
  f <- fixture()
  p <- mysterymaps_physician_dot_map(f$pts, f$poly)
  testthat::expect_s3_class(p, "ggplot")
  geoms <- vapply(p$layers, function(L) class(L$geom)[1], character(1))
  testthat::expect_gte(sum(geoms == "GeomSf"), 2L)   # basemap AND points
  n_rows <- vapply(p$layers, function(L)
    if (inherits(L$data, "sf")) nrow(L$data) else NA_integer_, integer(1))
  testthat::expect_true(any(n_rows == nrow(f$pts), na.rm = TRUE),
                        info = "no layer carries the physician rows")
})

testthat::test_that("the coloured path builds, with and without a palette", {
  # scale_color_manual(values = NULL) raises "Insufficient values in manual
  # scale", which made the original error outright whenever color_var was
  # supplied without a palette.
  skip_unless_spatial()
  f <- fixture()
  testthat::expect_s3_class(
    mysterymaps_physician_dot_map(f$pts, f$poly, color_var = "grp"), "ggplot")
  testthat::expect_s3_class(
    mysterymaps_physician_dot_map(f$pts, f$poly, color_var = "grp",
                                  palette = c(a = "red", b = "blue")), "ggplot")
})

testthat::test_that("a zero-row input names the likely cause", {
  # "no physicians found" reads as an empty population. It is almost always a
  # label mismatch upstream, and the message must say so.
  skip_unless_spatial()
  f <- fixture()
  testthat::expect_error(
    mysterymaps_physician_dot_map(f$pts[0, ], f$poly),
    "FILTER MISMATCH")
})

testthat::test_that("the caller's s2 setting is restored", {
  # Repair must happen in planar mode (st_make_valid fixes 44 of 49 state
  # polygons under s2, all 49 without), but leaking sf_use_s2(FALSE) into the
  # session changes the behaviour of every later spatial call.
  skip_unless_spatial()
  f <- fixture()
  before <- sf::sf_use_s2()
  invisible(mysterymaps_physician_dot_map(f$pts, f$poly))
  testthat::expect_identical(sf::sf_use_s2(), before)
})

testthat::test_that("NEGATIVE CONTROL: no bare `if` is an operand of `+`", {
  # The parse-level hazard that caused the original defect: a bare `if` inside a
  # ggplot `+` chain extends as far right as possible and swallows the rest of
  # the chain, so the layer never joins the plot and nothing errors.
  #
  # This inspects the AST of the INSTALLED function rather than reading
  # R/physician_dot_map.R. Two reasons: under R CMD check the sources are not
  # on disk, and a line-oriented regex cannot see `... + if (x) a else b`
  # written on a single line, which is the same defect. Comments do not survive
  # parsing, so a comment mentioning `if` can never trip this.
  .plus_has_if <- function(e) {
    if (!is.call(e)) return(FALSE)
    if (identical(e[[1L]], as.name("+"))) {
      for (k in seq_along(e)[-1L]) {
        a <- tryCatch(e[[k]], error = function(err) NULL)
        if (is.call(a) && identical(a[[1L]], as.name("if"))) return(TRUE)
      }
    }
    for (k in seq_along(e)) {
      a <- tryCatch(e[[k]], error = function(err) NULL)
      if (!is.null(a) && isTRUE(tryCatch(.plus_has_if(a), error = function(err) FALSE)))
        return(TRUE)
    }
    FALSE
  }

  # POSITIVE CONTROL: the detector must actually fire on the real defect shape,
  # or the assertion below would pass for free on any function at all.
  testthat::expect_true(.plus_has_if(quote(a + if (z) b else c)))
  testthat::expect_true(.plus_has_if(quote(ggplot() + geom_sf(d) + if (z) x else y)))
  testthat::expect_false(.plus_has_if(quote(a + b + c)))
  testthat::expect_false(.plus_has_if(quote({ lyr <- if (z) x else y; a + lyr })))

  testthat::expect_false(.plus_has_if(body(mysterymaps_physician_dot_map)))
})
