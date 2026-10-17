#' Small-multiple dot map, one panel per pathway
#'
#' @description
#' Facets a physician dot map by a grouping column -- typically a
#' certification or training pathway -- so each pathway's geographic
#' footprint is visible on its own panel instead of overplotted in one
#' colour-coded map. Optionally adds a combined "All Pathways Combined" panel
#' first, for a baseline readers can compare the per-pathway panels against.
#'
#' @details
#' `pathway_var`'s raw values become the facet titles verbatim, which makes
#' any abbreviation in the source data (`"OBGYN"`, `"ABU"`) land directly on
#' the figure. Pass `pathway_labels`, a named character vector mapping raw
#' values to full words (e.g. `c(OBGYN = "Obstetrics and Gynecology", ABU =
#' "Urology")`), to recode them before faceting; this function does not
#' expand abbreviations on its own.
#'
#' Jitter uses [mysterymaps_jitter_points()] with the same deterministic,
#' under-2-mile default as [mysterymaps_physician_dot_map()], applied once
#' before faceting so a physician's dot sits at the same jittered position in
#' every panel it appears in.
#'
#' Points are coloured by pathway (the same grouping that drives the facets),
#' using [ggplot2::scale_color_hue()] unless `palette` is supplied. Every
#' per-pathway panel is then visually uniform, as expected -- but the "All
#' Pathways Combined" panel keeps each point's own pathway colour rather than
#' flattening to one colour, so it works as a real overview rather than a
#' silhouette of the dataset.
#'
#' @param points `sf` POINT layer, one row per physician.
#' @param basemap `sf` polygon layer to draw beneath the points in every panel.
#' @param pathway_var `character(1)`: column in `points` identifying the pathway.
#' @param pathway_labels Optional named character vector recoding raw
#'   `pathway_var` values to full-word facet and legend labels. `NULL` uses the
#'   raw values as-is.
#' @param include_combined_panel `logical(1)`: add an "All Pathways Combined"
#'   panel containing every point. Default `TRUE`.
#' @param title,subtitle,caption Character labels. `NULL` omits.
#' @param palette Optional named colour vector for `pathway_var` (after
#'   `pathway_labels` recoding), e.g. `c("Urology" = "#009E73")`. `NULL` uses
#'   a hue scale.
#' @param point_size,point_alpha Point aesthetics.
#' @param crs Projection for display. Default EPSG:5070 (Albers Equal Area),
#'   appropriate for the contiguous United States.
#' @param jitter_miles,jitter_seed Passed to [mysterymaps_jitter_points()].
#'   Defaults `1.5` and `42`.
#' @param ncol Number of facet columns. `NULL` lets [ggplot2::facet_wrap()] choose.
#'
#' @return A `ggplot` object. The caller saves it; this function writes nothing.
#' @family mapping
#' @export
mysterymaps_pathway_small_multiples_map <- function(points,
                                                     basemap,
                                                     pathway_var,
                                                     pathway_labels = NULL,
                                                     include_combined_panel = TRUE,
                                                     title = NULL,
                                                     subtitle = NULL,
                                                     caption = NULL,
                                                     palette = NULL,
                                                     point_size = 1.6,
                                                     point_alpha = 0.9,
                                                     crs = 5070,
                                                     jitter_miles = 1.5,
                                                     jitter_seed = 42,
                                                     ncol = NULL) {
  for (pkg in c("sf", "ggplot2")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("mysterymaps_pathway_small_multiples_map() needs the '", pkg,
           "' package, which is a Suggests dependency. Install it to use ",
           "this function.", call. = FALSE)
    }
  }
  checkmate::assert_class(points, "sf")
  checkmate::assert_class(basemap, "sf")
  checkmate::assert_string(pathway_var)
  checkmate::assert_subset(pathway_var, names(points))
  checkmate::assert_flag(include_combined_panel)
  if (nrow(points) == 0L) {
    stop("mysterymaps_pathway_small_multiples_map(): `points` has zero rows.",
         call. = FALSE)
  }

  points <- mysterymaps_jitter_points(points, miles = jitter_miles, seed = jitter_seed)

  panel_label <- as.character(points[[pathway_var]])
  if (!is.null(pathway_labels)) {
    recoded <- pathway_labels[panel_label]
    panel_label <- ifelse(is.na(recoded), panel_label, recoded)
  }
  # .mm_group carries the real pathway through unchanged, even on the
  # duplicated combined-panel rows, so colour reflects pathway in every
  # panel; .mm_panel is the facet key and gets overridden for that duplicate.
  points$.mm_group <- panel_label
  points$.mm_panel <- panel_label

  panels <- points
  if (include_combined_panel) {
    combined <- points
    combined$.mm_panel <- "All Pathways Combined"
    panels <- rbind(combined, panels)
  }
  panel_levels <- unique(panels$.mm_panel)
  if (include_combined_panel) {
    panel_levels <- c("All Pathways Combined",
                      setdiff(panel_levels, "All Pathways Combined"))
  }
  panels$.mm_panel <- factor(panels$.mm_panel, levels = panel_levels)

  basemap_p <- sf::st_transform(basemap, crs = crs)
  panels_p <- sf::st_transform(panels, crs = crs)

  color_scale <- if (is.null(palette) || length(palette) == 0L) {
    ggplot2::scale_color_hue(name = NULL, na.value = "grey50")
  } else {
    ggplot2::scale_color_manual(values = palette, name = NULL, na.value = "grey50")
  }

  ggplot2::ggplot() +
    ggplot2::geom_sf(data = basemap_p, fill = "#f8f9fa", color = "gray40",
                     linewidth = 0.25) +
    ggplot2::geom_sf(data = panels_p, mapping = ggplot2::aes(color = .data$.mm_group),
                     size = point_size, alpha = point_alpha, shape = 16, stroke = 0.2) +
    color_scale +
    ggplot2::facet_wrap(~.mm_panel, ncol = ncol) +
    ggplot2::labs(title = title, subtitle = subtitle, caption = caption) +
    ggplot2::coord_sf(crs = sf::st_crs(crs), datum = NA) +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(size = ggplot2::rel(1.15), face = "bold"),
      plot.title.position = "plot",
      plot.caption = ggplot2::element_text(size = ggplot2::rel(0.7),
                                           colour = "grey35", hjust = 0),
      strip.text = ggplot2::element_text(face = "bold"),
      legend.position = "bottom")
}
