#' Catchment-redundancy choropleth map
#'
#' @description
#' Shows, for each target polygon, roughly how many distinct providers'
#' drive-time catchment areas reach it -- `1` means that area has exactly one
#' option within range, `0` means none do, and higher numbers mean more
#' redundant coverage. This is the complement of a simple access map: access
#' maps show whether a provider is reachable at all, this shows how much
#' choice a reader at that location actually has.
#'
#' @details
#' Redundancy is estimated with a sample grid rather than an exact polygon
#' overlay, because an exact pairwise overlay across many overlapping
#' catchments is expensive and the exact boundary of that overlay is not what
#' the map needs -- a representative per-polygon summary is. A regular point
#' grid (`grid_spacing_miles` apart, in EPSG:5070 meters) is laid over the
#' union of `catchments`' bounding box and `polygons`; each grid point counts
#' the number of **distinct** `provider_id_var` values among the catchments
#' containing it (`0` if none); each target polygon's value is the **median**
#' grid-point count among points falling inside it. Median, not mean, so one
#' corner with much higher or lower redundancy than the rest of a large,
#' irregularly-shaped polygon does not dominate its summary value.
#'
#' A small polygon can be narrower than `grid_spacing_miles` and catch zero
#' grid points at all -- on Virginia's independent cities (Lexington, Fairfax
#' City, Manassas, Manassas Park, Colonial Heights, Covington, Poquoson,
#' Emporia, Bristol, Charlottesville; all under 20 square miles) this left 10
#' of 133 polygons with no sample at all, rendered as a blank gap in
#' `na.value` even though they are not actually missing data. Any polygon the
#' grid misses entirely is sampled once more directly, at
#' [sf::st_point_on_surface()] (guaranteed to land inside the polygon, unlike
#' a bounding-box centroid, which can fall outside an irregular shape).
#'
#' A redundancy count is classified, not coloured continuously: `0` --
#' nothing covers this area at all -- is as categorically different from `1`
#' as `1` is different from `5`, and a continuous `scale_fill_viridis_c()`
#' (the original implementation) puts `0` at the dark end of the same
#' gradient as every low-but-nonzero value, where it reads as merely "low
#' redundancy" rather than the "no option at all" finding it actually is.
#' [mysterymaps_jenks_zero_scale()] with `digits = NULL` gives whole-number
#' legend labels appropriate to a count and puts `0` in its own class, so it
#' replaces the old `scale_fill_viridis_c()` plus a hand-written
#' integer-breaks helper.
#'
#' `catchments` must contain exactly one row per `(provider, band)` you want
#' counted. If `catchments` holds multiple drive-time bands per provider,
#' filter to a single band before calling this function -- passing all bands
#' at once would double-count the same provider at a point reachable within
#' more than one of their bands.
#'
#' @param catchments `sf` polygon layer, one row per provider catchment
#'   (single drive-time band; see Details).
#' @param polygons `sf` polygon layer: the target areas to summarize onto
#'   (e.g. counties).
#' @param provider_id_var `character(1)`: column in `catchments` identifying
#'   the distinct provider.
#' @param title,subtitle,caption Character labels. `NULL` omits.
#' @param grid_spacing_miles `numeric(1)`: sample grid spacing, in miles.
#'   Default `5`. Smaller is more accurate and slower.
#' @param k `integer(1)`: target number of Jenks classes for the positive
#'   (1-or-more) redundancy counts, passed to
#'   [mysterymaps_jenks_zero_scale()]. Default `6`.
#' @param zero_color,na_color Colours for a measured-zero (no coverage at
#'   all) and an unmeasured polygon, respectively. Defaults match
#'   [mysterymaps_jenks_zero_scale()]'s own.
#' @param crs Projection for display. Default EPSG:5070 (Albers Equal Area),
#'   appropriate for the contiguous United States.
#'
#' @return A `ggplot` object. The caller saves it; this function writes nothing.
#' @family mapping
#' @export
#' @examplesIf interactive()
#' counties <- sf::st_sf(
#'   geometry = sf::st_sfc(lapply(1:2, function(i) {
#'     x <- -100 + i
#'     sf::st_polygon(list(cbind(c(x, x + 1, x + 1, x, x), c(40, 40, 41, 41, 40))))
#'   }), crs = 4326)
#' )
#' # county 1 is covered by provider A only, county 2 by both A and B
#' catch_a <- sf::st_sf(provider = "A", geometry = sf::st_sfc(
#'   sf::st_polygon(list(cbind(c(-99, -97, -97, -99, -99), c(40, 40, 42, 42, 40)))),
#'   crs = 4326))
#' catch_b <- sf::st_sf(provider = "B", geometry = sf::st_sfc(
#'   sf::st_polygon(list(cbind(c(-98, -97, -97, -98, -98), c(40, 40, 41, 41, 40)))),
#'   crs = 4326))
#' mysterymaps_catchment_redundancy_map(
#'   rbind(catch_a, catch_b), counties, provider_id_var = "provider",
#'   grid_spacing_miles = 10)
mysterymaps_catchment_redundancy_map <- function(catchments,
                                                  polygons,
                                                  provider_id_var,
                                                  title = NULL,
                                                  subtitle = NULL,
                                                  caption = NULL,
                                                  grid_spacing_miles = 5,
                                                  k = 6,
                                                  zero_color = "#e0e0e0",
                                                  na_color = "#ffffff",
                                                  crs = 5070) {
  for (pkg in c("sf", "ggplot2")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("mysterymaps_catchment_redundancy_map() needs the '", pkg,
           "' package, which is a Suggests dependency. Install it to use ",
           "this function.", call. = FALSE)
    }
  }
  checkmate::assert_class(catchments, "sf")
  checkmate::assert_class(polygons, "sf")
  checkmate::assert_string(provider_id_var)
  checkmate::assert_subset(provider_id_var, names(catchments))
  checkmate::assert_number(grid_spacing_miles, lower = 0.01)
  checkmate::assert_int(k, lower = 1L)
  if (nrow(catchments) == 0L) {
    stop("mysterymaps_catchment_redundancy_map(): `catchments` has zero rows.",
         call. = FALSE)
  }
  if (nrow(polygons) == 0L) {
    stop("mysterymaps_catchment_redundancy_map(): `polygons` has zero rows.",
         call. = FALSE)
  }

  old_s2 <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)
  suppressMessages(sf::sf_use_s2(FALSE))
  if (!all(sf::st_is_valid(catchments))) catchments <- sf::st_make_valid(catchments)
  if (!all(sf::st_is_valid(polygons))) polygons <- sf::st_make_valid(polygons)

  catchments_p <- sf::st_transform(catchments, 5070)
  polygons_p <- sf::st_transform(polygons, 5070)

  cell_m <- grid_spacing_miles * 1609.344
  grid_pts <- sf::st_as_sf(
    sf::st_make_grid(sf::st_union(polygons_p), cellsize = cell_m, what = "centers"))
  grid_pts$.mm_grid_id <- seq_len(nrow(grid_pts))

  hits <- sf::st_join(grid_pts, catchments_p, join = sf::st_within, left = TRUE)
  redundancy <- stats::aggregate(
    hits[[provider_id_var]], by = list(.mm_grid_id = hits$.mm_grid_id),
    FUN = function(x) length(unique(x[!is.na(x)])))
  names(redundancy) <- c(".mm_grid_id", ".mm_redundancy")
  grid_pts <- merge(grid_pts, redundancy, by = ".mm_grid_id", all.x = TRUE)
  grid_pts$.mm_redundancy[is.na(grid_pts$.mm_redundancy)] <- 0L

  within_list <- sf::st_within(grid_pts, polygons_p)
  poly_row <- vapply(within_list, function(ix) if (length(ix)) ix[1] else NA_integer_,
                     integer(1))
  summary_df <- stats::aggregate(
    list(redundancy = grid_pts$.mm_redundancy[!is.na(poly_row)]),
    by = list(.mm_poly_row = poly_row[!is.na(poly_row)]), FUN = stats::median)

  polygons_p$.mm_redundancy <- NA_real_
  polygons_p$.mm_redundancy[summary_df$.mm_poly_row] <- summary_df$redundancy

  # A polygon narrower than the grid spacing catches zero grid points and
  # would otherwise render as a blank "no data" gap despite having a real,
  # computable answer. Sample it directly at a point guaranteed to lie inside it.
  missed_rows <- which(is.na(polygons_p$.mm_redundancy))
  if (length(missed_rows)) {
    fallback_pts <- sf::st_sf(
      .mm_fallback_id = seq_along(missed_rows),
      geometry = suppressWarnings(sf::st_point_on_surface(sf::st_geometry(polygons_p)[missed_rows])))
    fallback_hits <- sf::st_join(fallback_pts, catchments_p, join = sf::st_within, left = TRUE)
    fallback_counts <- stats::aggregate(
      fallback_hits[[provider_id_var]], by = list(.mm_fallback_id = fallback_hits$.mm_fallback_id),
      FUN = function(x) length(unique(x[!is.na(x)])))
    polygons_p$.mm_redundancy[missed_rows[fallback_counts$.mm_fallback_id]] <- fallback_counts$x
  }

  polygons_disp <- sf::st_transform(polygons_p, crs = crs)

  sc <- mysterymaps_jenks_zero_scale(
    polygons_disp$.mm_redundancy, k = k, zero_col = zero_color, na_col = na_color,
    palette = function(kk) viridisLite::viridis(kk, option = "viridis"))
  polygons_disp$.mm_fill_color <- sc$color(polygons_disp$.mm_redundancy)

  ggplot2::ggplot() +
    ggplot2::geom_sf(data = polygons_disp, mapping = ggplot2::aes(fill = .data$.mm_fill_color),
                     color = "white", linewidth = 0.15) +
    ggplot2::scale_fill_identity(
      name = "Number of Overlapping Physician\nCatchment Areas", guide = "legend",
      breaks = sc$leg_cols, labels = sc$leg_labs) +
    ggplot2::labs(title = title, subtitle = subtitle, caption = caption) +
    ggplot2::coord_sf(crs = sf::st_crs(crs), datum = NA) +
    ggplot2::theme_void(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(size = ggplot2::rel(1.15), face = "bold"),
      plot.title.position = "plot",
      plot.caption = ggplot2::element_text(size = ggplot2::rel(0.7),
                                           colour = "grey35", hjust = 0),
      legend.position = "bottom")
}
