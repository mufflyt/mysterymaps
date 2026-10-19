#' Get Hospital Referral Region Shapefile
#'
#' Loads the Dartmouth Atlas Hospital Referral Region (HRR) shapefile,
#' transforming it to EPSG:4326 (WGS84) and optionally dropping Alaska and
#' Hawaii.  The shapefile (~8 MB) is downloaded on first use and cached in the
#' user's R cache directory for subsequent calls.
#'
#' @param remove_HI_AK Logical.  When `TRUE` (default), HRRs whose `hrrcity`
#'   starts with `"AK"` or `"HI"` are dropped from the returned object.
#'
#' @return An `sf` object with one row per HRR and columns:
#'   \describe{
#'     \item{`hrrcity`}{Character. HRR city identifier (e.g. `"CA-Sacramento"`).}
#'     \item{`hrrnum`}{Integer. Numeric HRR code from the Dartmouth Atlas.}
#'     \item{`geometry`}{sfc_MULTIPOLYGON in EPSG:4326 (WGS84).}
#'   }
#'   Additional columns from the raw shapefile may be present.
#' @seealso [ensure_hrr_shapefile()], [mysterymaps_hrr_maps()], [mysterymaps_map_base()]
#' @family geospatial helpers
#' @importFrom dplyr filter
#' @importFrom magrittr %>%
#' @export
#' @examplesIf interactive()
#' mysterymaps_hrr()
mysterymaps_hrr <- function(remove_HI_AK = TRUE) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Package 'sf' is required", call. = FALSE)
  }

  message("Loading necessary packages...")

  # Load the hospital referral region shapefile
  message("Getting the hospital referral region shapefile...")
  hrr_path <- ensure_hrr_shapefile()
  mysterymaps_hrr <- sf::read_sf(hrr_path)
  mysterymaps_hrr <- sf::st_transform(mysterymaps_hrr, 4326)

  # Optionally remove Hawaii and Alaska (all HRRs, not just the largest cities)
  if (remove_HI_AK) {
    mysterymaps_hrr <- mysterymaps_hrr %>%
      dplyr::filter(!stringr::str_detect(.data$hrrcity, "^(AK|HI)"))
  }

  # Provide information about the function's purpose
  message("Hospital Referral Region shapefile loaded.")
  message("This function creates an sf file of hospital referral regions.")
  message("For more information: https://data.dartmouthatlas.org/supplemental/")

  return(mysterymaps_hrr)
}

#' Generate honeycomb hex maps for Hospital Referral Regions
#'
#' Joins physician point data to HRR polygons, computes per-HRR physician
#' counts, and renders a honeycomb choropleth of the contiguous US with
#' Alaska, Hawaii, and Puerto Rico as inset maps.  The figure is saved as
#' both `.tiff` and `.png` to `output_dir`.
#'
#' @param physician_sf An `sf` object with one row per physician.  Must have
#'   a `geometry` column of POINT geometries; CRS is auto-transformed to
#'   EPSG:4326 if needed.
#' @param trait_map Character scalar used as a label in the output filename
#'   (e.g. `"all"`, `"neurotology"`).  No validation; used as-is.
#' @param honey_map Character scalar used as a secondary label in the output
#'   filename (e.g. `"all"`).  No validation; used as-is.
#' @param output_dir Directory where generated figures are written. Defaults to a
#'   session-specific folder inside [tempdir()].
#' @param dpi Integer.  Raster resolution in DPI for the saved figure.  Default `600`.
#' @param width Numeric.  Figure width in inches.  Default `7`.
#' @param height Numeric.  Figure height in inches.  Default `5`.
#' @param min_count Integer.  Cells holding fewer than this many providers are
#'   coloured as suppressed (`na_color`) rather than drawn with their true
#'   count.  Default `2L`, the long-standing behaviour: a cell with exactly
#'   one provider is small-cell-suppressed rather than potentially
#'   identifying.  A cell with *zero* providers is a different, measured
#'   finding and is never suppressed by this argument -- see Details.
#' @param k Integer.  Target number of Jenks classes for the positive
#'   (at-or-above-`min_count`) cell counts, passed to
#'   [mysterymaps_jenks_zero_scale()].  Default `6`.
#' @param zero_color,na_color Colours for a cell with a measured zero count
#'   and a small-cell-suppressed cell, respectively.  Defaults match
#'   [mysterymaps_jenks_zero_scale()]'s own.
#'
#' @return Invisibly returns a `grob` object (from
#'   `gridExtra::arrangeGrob`) containing the arranged multi-panel map.
#'   Side effects: writes two files to `output_dir` -
#'   `<trait_map>_<honey_map>_honey.tiff` and
#'   `<trait_map>_<honey_map>_honey.png`.
#'
#' @details
#' Earlier versions of this function called [mm_honeycomb_counts()], which
#' drops every cell below `min_count` -- including genuine zero-count cells
#' -- so a region with no providers at all had no hexagon drawn rather than
#' one visibly shaded as zero. That is the same "zero is a category, not an
#' absence" problem this package's other choropleth builders have been fixed
#' for one at a time; this function was the one [mm_honeycomb_counts()] and
#' [mysterymaps_hex_bin_counts()] were originally extracted from, and had not
#' itself been updated to use either.
#'
#' This function now calls the internal full-grid counter (every cell in
#' `usa`, zero-count ones included) and classifies the result with
#' [mysterymaps_jenks_zero_scale()] instead of a continuous
#' `scale_fill_viridis_c()`: a true zero gets `zero_color` and its own
#' legend entry, a cell below `min_count` is suppressed to `na_color` with a
#' "Suppressed" legend entry (a measurement that exists but is not
#' separately reportable, not an unmeasured cell -- the two are different
#' claims, the same distinction [mysterymaps_hex_bin_rate()] makes for a
#' zero denominator), and cells at or above `min_count` are Jenks-classified.
#' The same scale -- computed once, before the contiguous/Alaska/Hawaii/
#' Puerto Rico split -- colours every panel, so the legend shown on the main
#' map is valid for the insets too.
#'
#' @seealso [mysterymaps_hrr()] to obtain the HRR `sf` object;
#'   [mysterymaps_map_base()], [mysterymaps_map_block_group()]
#' @family mapping
#' @importFrom dplyr mutate group_by summarize filter n
#' @importFrom magrittr %>%
#' @importFrom stringr str_detect
#' @export
#' @examplesIf interactive()
#' mysterymaps_hrr_maps(physician_sf)
mysterymaps_hrr_maps <- function(
    physician_sf,
    trait_map = "all",
    honey_map = "all",
    output_dir = NULL,
    dpi = 600,
    width = 7,
    height = 5,
    min_count = 2L,
    k = 6,
    zero_color = "#e0e0e0",
    na_color = "#ffffff"
) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Package 'sf' is required", call. = FALSE)
  }
  if (!requireNamespace("scales", quietly = TRUE)) {
    stop("Package 'scales' is required for mysterymaps_hrr_maps()", call. = FALSE)
  }

  if (!requireNamespace("ggspatial", quietly = TRUE)) {
    stop("Package 'ggspatial' is required for mysterymaps_hrr_maps()", call. = FALSE)
  }
  if (!requireNamespace("rnaturalearth", quietly = TRUE)) {
    stop("Package 'rnaturalearth' is required for mysterymaps_hrr_maps()", call. = FALSE)
  }
  if (!requireNamespace("gridExtra", quietly = TRUE)) {
    stop("Package 'gridExtra' is required for this function", call. = FALSE)
  }
  if (!requireNamespace("grid", quietly = TRUE)) {
    stop("Package 'grid' is required for this function", call. = FALSE)
  }
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for mysterymaps_hrr_maps(). Install with: install.packages('ggplot2')", call. = FALSE)
  }
  mm_validate_zero_aware_args(TRUE, k, digits = NULL, zero_color)
  checkmate::assert_int(min_count, lower = 0L)
  checkmate::assert_string(na_color)
  # Spherical geometry makes the 0.3-degree honeycomb intersection intractably
  # slow, so it goes off for the duration -- and comes back on afterwards.
  # Leaving it off silently changes the result of every sf operation the caller
  # runs next, in a session where nothing announced the change.
  old_s2 <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)
  suppressMessages(sf::sf_use_s2(FALSE))

  # Load USA shapefile
  message("Loading USA shapefile...")
  usa <- rnaturalearth::ne_countries(country = "United States of America", returnclass = "sf")
  usa <- sf::st_transform(usa, 4326)

  # Generate the HRR map (retain AK, HI, and PR for insets)
  hrr_map <- mysterymaps_hrr(remove_HI_AK = FALSE)

  # Intersect honeycomb grid with physician data to get physician counts --
  # the full grid, zero-count cells included, so a region with no providers
  # gets a visibly zero-shaded hexagon rather than no hexagon at all.
  message("Intersecting honeycomb grid with physician data...")
  honeycomb_grid_with_physicians <- mm_honeycomb_counts_full_grid(
    usa, physician_sf, value_col = "physician_count",
    cellsize = 0.3, southern_limit = 15)

  # A cell holding fewer than min_count providers is suppressed -- a
  # measurement that exists but is not separately reportable -- which is a
  # different claim from the true, measured zero a cell with NO providers
  # gets. Suppression therefore produces NA (mysterymaps_jenks_zero_scale()'s
  # "unmeasured" class), never folds into the zero class itself.
  honeycomb_grid_with_physicians$physician_count <- mm_suppress_small_cells(
    honeycomb_grid_with_physicians$physician_count, min_count)

  # One scale for every panel, computed before the contiguous/AK/HI/PR split,
  # so the legend shown on the main map is valid for the insets too.
  sc <- mysterymaps_jenks_zero_scale(
    honeycomb_grid_with_physicians$physician_count, k = k,
    zero_col = zero_color, na_col = na_color,
    na_label = sprintf("Suppressed (<%d provider%s)", min_count,
                       if (min_count == 1L) "" else "s"),
    palette = function(kk) viridisLite::viridis(kk, option = "viridis"))
  honeycomb_grid_with_physicians$.mm_fill_color <- sc$color(
    honeycomb_grid_with_physicians$physician_count)

  # Split data for contiguous US and insets
  message("Preparing contiguous and inset geographies...")
  contiguous_hrr <- hrr_map %>%
    dplyr::filter(!stringr::str_detect(.data$hrrcity, "^(AK|HI|PR)-"))
  alaska_hrr <- hrr_map %>% dplyr::filter(stringr::str_detect(.data$hrrcity, "^AK-"))
  hawaii_hrr <- hrr_map %>% dplyr::filter(stringr::str_detect(.data$hrrcity, "^HI-"))
  puerto_rico_hrr <- hrr_map %>% dplyr::filter(stringr::str_detect(.data$hrrcity, "^PR-"))

  contiguous_honey <- sf::st_filter(honeycomb_grid_with_physicians, contiguous_hrr)
  alaska_honey <- sf::st_filter(honeycomb_grid_with_physicians, alaska_hrr)
  hawaii_honey <- sf::st_filter(honeycomb_grid_with_physicians, hawaii_hrr)
  puerto_rico_honey <- sf::st_filter(honeycomb_grid_with_physicians, puerto_rico_hrr)

  map_theme <- ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      panel.background = ggplot2::element_rect(fill = "white", color = NA),
      plot.title = ggplot2::element_text(face = "bold", hjust = 0.5),
      axis.title = ggplot2::element_text(face = "bold"),
      legend.title = ggplot2::element_text(face = "bold"),
      legend.position = "bottom",
      legend.box = "horizontal",
      legend.margin = ggplot2::margin(t = 6)
    )

  build_region_plot <- function(hrr_data, honey_data, region_title, show_legend = FALSE, base_size = 10) {
    if (nrow(hrr_data) == 0) {
      return(
        ggplot2::ggplot() +
          ggplot2::theme_void() +
          ggplot2::annotate("text", x = 0.5, y = 0.5, label = paste("No data for", region_title), size = 3)
      )
    }

    ggplot2::ggplot() +
      ggplot2::geom_sf(data = hrr_data, fill = "#f5f5f5", color = "#4a4a4a", linewidth = 0.2) +
      ggplot2::geom_sf(
        data = honey_data,
        ggplot2::aes(fill = .data$.mm_fill_color),
        color = NA,
        alpha = 0.95
      ) +
      ggplot2::scale_fill_identity(
        name = "Physician count",
        guide = if (show_legend) "legend" else "none",
        breaks = sc$leg_cols,
        labels = sc$leg_labs
      ) +
      ggplot2::labs(title = region_title) +
      ggplot2::theme_minimal(base_size = base_size) +
      ggplot2::theme(
        axis.title = ggplot2::element_blank(),
        axis.text = ggplot2::element_blank(),
        axis.ticks = ggplot2::element_blank(),
        panel.grid = ggplot2::element_blank(),
        legend.position = if (show_legend) "bottom" else "none",
        plot.title = ggplot2::element_text(hjust = 0.5, face = "bold")
      )
  }

  message("Creating main map and insets...")
  main_map <- build_region_plot(contiguous_hrr, contiguous_honey, "Hospital Referral Regions", show_legend = TRUE, base_size = 12) +
    ggspatial::annotation_scale(location = "bl", width_hint = 0.25, bar_cols = c("black", "white")) +
    ggspatial::annotation_north_arrow(
      location = "br",
      which_north = "true",
      style = ggspatial::north_arrow_fancy_orienteering()
    ) +
    map_theme

  alaska_inset <- build_region_plot(alaska_hrr, alaska_honey, "Alaska")
  hawaii_inset <- build_region_plot(hawaii_hrr, hawaii_honey, "Hawaii")
  puerto_rico_inset <- build_region_plot(puerto_rico_hrr, puerto_rico_honey, "Puerto Rico")

  combined_insets <- gridExtra::arrangeGrob(alaska_inset, hawaii_inset, puerto_rico_inset, ncol = 3)
  combined_map <- gridExtra::arrangeGrob(main_map, combined_insets, heights = c(3, 1))

  # Print the plot
  grid::grid.newpage()
  grid::grid.draw(combined_map)

  # Ensure output directory exists
  if (is.null(output_dir)) {
    output_dir <- file.path(tempdir(), "hrr_maps"); dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  } else if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  output_stub <- file.path(output_dir, paste0(trait_map, "_", honey_map, "_honey"))
  message("Saving the map for Obstetrics & Gynecology submission...")
  ggplot2::ggsave(paste0(output_stub, ".tiff"), plot = combined_map, width = width, height = height, dpi = dpi, units = "in", compression = "lzw")
  ggplot2::ggsave(paste0(output_stub, ".png"), plot = combined_map, width = width, height = height, dpi = dpi, units = "in")

  invisible(combined_map)
}

#' Suppress honeycomb cells below a provider-count threshold
#'
#' Split out of [mysterymaps_hrr_maps()] for the same reason
#' [mm_honeycomb_counts()] was: that function returns a `gtable`, so a
#' suppression threshold that silently swallowed the wrong cells -- the true
#' zeros it must NOT touch, say -- would be invisible to any assertion about
#' the function's output.
#'
#' @param counts `numeric`: a `physician_count`-style column, zero-inclusive
#'   (from `mm_honeycomb_counts_full_grid()`).
#' @param min_count `integer(1)`: counts strictly between `0` and this become
#'   `NA` (suppressed). `0` itself and counts `>= min_count` pass through
#'   unchanged -- a true zero is a different, measured claim from a
#'   suppressed small cell and must never be relabelled into it.
#' @return `counts`, with small-but-nonzero values replaced by `NA`.
#' @family geospatial
#' @keywords internal
#' @noRd
mm_suppress_small_cells <- function(counts, min_count) {
  below_threshold <- counts > 0 & counts < min_count
  counts[below_threshold] <- NA_real_
  counts
}

#' Count providers per honeycomb cell over a study-area polygon
#'
#' Split out of [mysterymaps_hrr_maps()] because the count it produces was the
#' one thing that function could not be tested on: it returns a `gtable`, so a
#' cell losing every provider it holds is invisible to any assertion about the
#' output.
#'
#' @section The row-index filter this replaces:
#' The line here used to be `dplyr::filter(grid_id > 9546L)`, commented
#' `# Filter out Palmyra Atoll`. `grid_id` is `dplyr::row_number()` over
#' `sf::st_make_grid()`, whose cells run in longitude order across the bounding
#' box of `usa` -- so the cut removed the 9,546 WESTERNMOST cells, whatever
#' happened to be in them, and moved whenever Natural Earth shipped a polygon
#' with a different extent.
#'
#' Measured against the current polygon (bbox 171.8W-67.0W, 18.9N-71.4N): the
#' cut removed 1,223 cells containing US land -- 1,214 in western Alaska, 9 in
#' Hawaii -- among them Honolulu, Kauai and Nome. Palmyra Atoll sits at 5.9N,
#' outside that bounding box altogether, so the filter never once removed the
#' thing it named. What it removed was every physician in Honolulu, from a map
#' whose caller had just asked for Hawaii by name (`remove_HI_AK = FALSE`) and
#' which draws a Hawaii inset. The inset rendered empty and read as a workforce
#' finding.
#'
#' The intent -- keep a far-flung outlying territory from stretching the map --
#' is kept and expressed as geography, which cannot drift with a data release.
#' The southernmost point of the fifty states is Ka Lae, Hawaii, at 18.9N;
#' `southern_limit` sits well below it and well above Palmyra.
#'
#' @param usa `sf`: the study-area polygon the grid is built over and clipped to.
#' @param physician_sf `sf`: provider points.
#' @param cellsize `numeric(1)`: hexagon size in degrees.
#' @param min_count `integer(1)`: cells holding fewer than this many providers
#'   are dropped rather than drawn. Two is the long-standing behaviour and is a
#'   small-cell suppression choice, not a rendering detail -- a cell with one
#'   provider is drawn exactly like a cell with none.
#' @param southern_limit `numeric(1)`: cells entirely south of this latitude are
#'   outlying territory, not study area.
#' @return An `sf` of cells carrying a `physician_count`.
#' @family geospatial
#' @keywords internal
mm_honeycomb_counts <- function(usa, physician_sf, cellsize = 0.3,
                                min_count = 2L, southern_limit = 15) {
  # This function owns the setting rather than inheriting it. Clipping tens of
  # thousands of hexagons to a coastline leaves degenerate slivers that s2
  # rejects outright ("Loop 0 is not valid: Edge 3 is degenerate"), so with
  # spherical geometry on the count does not come out wrong -- it does not come
  # out at all. It used to work only because its one caller happened to have
  # switched s2 off a few lines earlier, which made the count a function of the
  # session as much as of the data.
  old_s2 <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)
  suppressMessages(sf::sf_use_s2(FALSE))

  usa <- sf::st_transform(usa, 4326)

  grid <- sf::st_make_grid(usa, c(cellsize, cellsize), what = "polygons",
                           square = FALSE) %>%
    sf::st_sf() %>%
    dplyr::mutate(grid_id = dplyr::row_number()) %>%
    sf::st_intersection(usa)

  in_scope <- sf::st_sfc(sf::st_polygon(list(cbind(
    c(-180, 180, 180, -180, -180),
    c(southern_limit, southern_limit, 90, 90, southern_limit)))), crs = 4326)
  grid <- grid[lengths(sf::st_intersects(grid, in_scope)) > 0L, , drop = FALSE]

  counts <- sf::st_intersection(grid, sf::st_transform(physician_sf, 4326)) %>%
    dplyr::group_by(.data$grid_id) %>%
    dplyr::summarize(physician_count = dplyr::n(), .groups = "drop") %>%
    dplyr::filter(.data$physician_count >= min_count)

  sf::st_join(grid, counts) %>%
    dplyr::filter(!is.na(.data$physician_count))
}

#' Hex-bin point counts over any study-area boundary, keeping zero cells
#'
#' @description
#' The `include_zero_cells = TRUE` path of [mysterymaps_hex_bin_counts()]:
#' identical grid construction to [mm_honeycomb_counts()] (same s2 handling,
#' same `southern_limit` clip), but every cell is returned -- a
#' `dplyr::left_join()` plus `dplyr::coalesce(0L)` in place of the inner
#' count-and-filter -- so "zero points landed here" and "this cell was
#' suppressed" are never the same output. Internal; use
#' [mysterymaps_hex_bin_counts()].
#' @keywords internal
#' @noRd
mm_honeycomb_counts_full_grid <- function(boundary_sf, points_sf, value_col = "count",
                                          cellsize = 0.3, southern_limit = -90) {
  old_s2 <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)
  suppressMessages(sf::sf_use_s2(FALSE))

  boundary_4326 <- sf::st_transform(boundary_sf, 4326)

  grid <- sf::st_make_grid(boundary_4326, c(cellsize, cellsize), what = "polygons",
                           square = FALSE) %>%
    sf::st_sf() %>%
    dplyr::mutate(grid_id = dplyr::row_number()) %>%
    sf::st_intersection(boundary_4326)

  in_scope <- sf::st_sfc(sf::st_polygon(list(cbind(
    c(-180, 180, 180, -180, -180),
    c(southern_limit, southern_limit, 90, 90, southern_limit)))), crs = 4326)
  grid <- grid[lengths(sf::st_intersects(grid, in_scope)) > 0L, , drop = FALSE]

  counts <- sf::st_intersection(grid, sf::st_transform(points_sf, 4326)) %>%
    dplyr::group_by(.data$grid_id) %>%
    dplyr::summarize(.mm_count = dplyr::n(), .groups = "drop")

  # A SPATIAL join (st_join), exactly as mm_honeycomb_counts() uses, not an
  # attribute join on grid_id: st_intersection(grid, boundary) upstream can
  # slice one hex into several polygon fragments along an irregular
  # coastline, all carrying the SAME grid_id, so an attribute join fans out
  # across every fragment that shares an id instead of matching the one
  # fragment counts' geometry actually overlaps.
  out <- sf::st_join(grid[, "grid_id"], counts[, ".mm_count"]) %>%
    dplyr::mutate(.mm_count = dplyr::coalesce(.data$.mm_count, 0L))
  names(out)[names(out) == ".mm_count"] <- value_col
  out
}

#' Hex-bin point counts over any study-area boundary
#'
#' Builds a hexagonal grid over `boundary_sf`, counts how many `points_sf`
#' fall in each cell, and returns the cells that cleared `min_count` -- the
#' GEOLYTIX-style "bin points into hexagons, shade by count" map, generalized
#' from the HRR/physician case in [mysterymaps_hrr_maps()] to any boundary and
#' any point dataset. It is a thin, renaming wrapper around
#' [mm_honeycomb_counts()], which carries the tested fixes (coastline slivers
#' under s2, the westernmost-cells defect, CRS transforms); this function adds
#' no new hex-counting logic of its own.
#'
#' @param boundary_sf `sf`: polygon(s) defining the study area the grid is
#'   built over and clipped to.
#' @param points_sf `sf`: point data to count per hex cell. Transformed to
#'   `boundary_sf`'s CRS automatically if it arrives in another one.
#' @param value_col `character(1)`: name of the output count column. Default
#'   `"count"`.
#' @param cellsize `numeric(1)`: hexagon size in the units of `boundary_sf`'s
#'   CRS (degrees, if left in EPSG:4326). Default `0.3`.
#' @param min_count `integer(1)`: cells holding fewer than this many points
#'   are dropped rather than returned -- small-cell suppression, not a
#'   rendering detail. Default `1L` (no suppression). Ignored when
#'   `include_zero_cells = TRUE` (see below).
#' @param southern_limit `numeric(1)`: cells entirely south of this latitude
#'   are dropped. [mm_honeycomb_counts()] defaults this to `15` to cut
#'   outlying US territory out of HRR maps; that is wrong for a boundary that
#'   is not the continental US (it would silently delete most of the Southern
#'   Hemisphere), so this wrapper defaults to `-90`, i.e. no clipping.
#' @param include_zero_cells `logical(1)`: return every hex cell in
#'   `boundary_sf`, including ones no point fell in, with `value_col = 0`
#'   there, instead of silently omitting them. Default `FALSE`, matching
#'   [mm_honeycomb_counts()]'s original point-counting behaviour. A reader
#'   cannot tell "zero, measured" from "not drawn" on a map with gaps in the
#'   grid -- the distinction [mysterymaps_jenks_zero_scale()] and
#'   [mysterymaps_hex_bin_rate()] both exist to preserve. `min_count` does
#'   not apply in this mode: suppressing small counts and asserting that a
#'   cell is a true zero are different, incompatible claims about the same
#'   cell.
#' @return An `sf` of hex cells carrying a `value_col` count column. With the
#'   default `include_zero_cells = FALSE`, cells with fewer than `min_count`
#'   points are not returned at all; with `include_zero_cells = TRUE`, every
#'   cell in `boundary_sf` is returned, zero-count ones included.
#' @seealso [mysterymaps_hrr_maps()], which wraps [mm_honeycomb_counts()] for
#'   the HRR/physician use case with AK/HI/PR insets baked in;
#'   [mysterymaps_hex_bin_rate()], which always returns the full grid because
#'   a rate needs to distinguish zero from missing.
#' @family geospatial
#' @export
#' @examplesIf interactive()
#' mysterymaps_hex_bin_counts(boundary_sf, points_sf, value_col = "flood_risk")
#' mysterymaps_hex_bin_counts(boundary_sf, points_sf, include_zero_cells = TRUE)
mysterymaps_hex_bin_counts <- function(boundary_sf, points_sf,
                                        value_col = "count",
                                        cellsize = 0.3,
                                        min_count = 1L,
                                        southern_limit = -90,
                                        include_zero_cells = FALSE) {
  checkmate::assert_class(boundary_sf, "sf")
  checkmate::assert_class(points_sf, "sf")
  checkmate::assert_string(value_col)
  checkmate::assert_number(cellsize, lower = 0, finite = TRUE)
  if (cellsize == 0) {
    stop("mysterymaps_hex_bin_counts(): `cellsize` must be strictly positive. ",
         "0 asks sf::st_make_grid() for a grid of zero-size hexagons, which it ",
         "rejects with an unrelated, cryptic error (\"invalid '(to - from)/by'\") ",
         "rather than naming the real cause.", call. = FALSE)
  }
  checkmate::assert_int(min_count, lower = 1L)
  checkmate::assert_number(southern_limit, lower = -90, upper = 90)
  checkmate::assert_flag(include_zero_cells)

  if (include_zero_cells) {
    return(mm_honeycomb_counts_full_grid(boundary_sf, points_sf,
                                         value_col = value_col,
                                         cellsize = cellsize,
                                         southern_limit = southern_limit))
  }

  out <- mm_honeycomb_counts(boundary_sf, points_sf, cellsize = cellsize,
                             min_count = min_count,
                             southern_limit = southern_limit)
  names(out)[names(out) == "physician_count"] <- value_col
  out
}
