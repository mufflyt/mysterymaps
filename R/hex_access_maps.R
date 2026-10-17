#' Create population-weighted hexagonal accessibility maps
#'
#' Creates three publication-oriented maps from precomputed origin-level
#' travel times. Does not request routes or infer physician locations.
#'
#' @param origins An sf POINT object with one row per origin and year.
#' @param boundary An sf polygon defining the mapped region.
#' @param year_col,origin_col,pop_col,time_col Column names.
#' @param years Two comparison years, default 2013 and 2023.
#' @param hex_km Hexagon grid spacing in kilometers.
#' @param crs Equal-area projected CRS in meters.
#' @param min_coverage Minimum fraction of expected population with valid
#'   travel times for each hexagon-year.
#' @return A list containing hexagons, summaries, and three ggplot objects.
#' @export
mysterymaps_hex_access_maps <- function(
  origins,
  boundary,
  year_col = "year",
  origin_col = "origin_id",
  pop_col = "population",
  time_col = "travel_minutes",
  years = c(2013L, 2023L),
  hex_km = 10,
  crs = 5070,
  min_coverage = 1
) {
  base::message("Hex maps: validating inputs")
  if (!base::inherits(origins, "sf") ||
      !base::inherits(boundary, "sf")) {
    base::stop("origins and boundary must be sf objects")
  }
  fields <- c(year_col, origin_col, pop_col, time_col)
  if (!base::all(fields %in% base::names(origins))) {
    base::stop("Missing required origin fields")
  }
  if (base::anyDuplicated(fields) ||
      base::length(years) != 2L ||
      base::anyNA(years) ||
      years[1] == years[2] ||
      !base::is.finite(hex_km) ||
      hex_km <= 0 ||
      !base::is.finite(min_coverage) ||
      min_coverage <= 0 ||
      min_coverage > 1) {
    base::stop("Invalid column, year, hex size, or coverage settings")
  }
  if (base::is.na(sf::st_crs(origins)) ||
      base::is.na(sf::st_crs(boundary))) {
    base::stop("Both spatial inputs require a CRS")
  }
  if (!base::all(
    sf::st_geometry_type(origins) %in% c("POINT")
  )) {
    base::stop("origins must contain POINT geometries")
  }
  projected_crs <- sf::st_crs(crs)
  if (base::is.na(projected_crs) ||
      sf::st_is_longlat(
        sf::st_transform(boundary, projected_crs)
      )) {
    base::stop("crs must be a projected CRS in meters")
  }

  base::message("Hex maps: filtering requested years")
  selected <- origins[
    origins[[year_col]] %in% years,
    ,
    drop = FALSE
  ]
  if (base::nrow(selected) == 0L) {
    base::stop("No origins for requested years")
  }
  if (base::anyNA(selected[[origin_col]]) ||
      base::anyDuplicated(
        base::paste(
          selected[[origin_col]],
          selected[[year_col]],
          sep = "::"
        )
      )) {
    base::stop("Origin IDs must be unique within each year")
  }
  population <- selected[[pop_col]]
  travel <- selected[[time_col]]
  if (!base::is.numeric(population) ||
      base::anyNA(population) ||
      base::any(!base::is.finite(population)) ||
      base::any(population < 0) ||
      !base::is.numeric(travel) ||
      base::any(travel < 0, na.rm = TRUE) ||
      base::any(!base::is.finite(travel) & !base::is.na(travel))) {
    base::stop("Invalid population or travel-time values")
  }
  if (!base::all(years %in% selected[[year_col]])) {
    base::stop("Both requested years must be present")
  }

  base::message("Hex maps: constructing equal-area grid")
  region <- sf::st_transform(
    sf::st_make_valid(boundary),
    projected_crs
  )
  region <- sf::st_union(sf::st_geometry(region))
  grid <- sf::st_make_grid(
    region,
    cellsize = hex_km * 1000,
    square = FALSE
  )
  hexagons <- sf::st_sf(
    hex_id = base::seq_along(grid),
    geometry = grid
  )
  hexagons <- sf::st_filter(hexagons, region)
  hexagons <- sf::st_intersection(
    hexagons,
    sf::st_sf(geometry = region)
  )
  selected <- sf::st_transform(selected, projected_crs)
  selected <- sf::st_filter(selected, region)
  if (base::nrow(selected) == 0L) {
    base::stop("No origin points within boundary")
  }

  base::message("Hex maps: assigning points to hexagons")
  joined <- sf::st_join(
    selected,
    hexagons["hex_id"],
    join = sf::st_intersects,
    left = TRUE,
    largest = FALSE
  )
  # Boundary points can touch multiple cells; deterministically retain
  # the lowest hex_id so no population is counted twice.
  joined <- joined |>
    sf::st_drop_geometry() |>
    dplyr::arrange(
      .data[[year_col]],
      .data[[origin_col]],
      .data$hex_id
    ) |>
    dplyr::distinct(
      .data[[year_col]],
      .data[[origin_col]],
      .keep_all = TRUE
    )
  if (base::anyNA(joined$hex_id)) {
    base::stop("Some origins could not be assigned to a hexagon")
  }
  base::message("Hex maps: calculating weighted summaries")
  summaries <- joined |>
    dplyr::group_by(.data$hex_id, .data[[year_col]]) |>
    dplyr::summarise(
      total_population = base::sum(.data[[pop_col]]),
      valid_population = base::sum(
        .data[[pop_col]][!base::is.na(.data[[time_col]])]
      ),
      exposed_population = base::sum(
        .data[[pop_col]][
          !base::is.na(.data[[time_col]]) &
            .data[[time_col]] > 60
        ]
      ),
      weighted_minutes = {
        ok <- !base::is.na(.data[[time_col]]) &
          .data[[pop_col]] > 0
        if (base::any(ok)) {
          stats::weighted.mean(
            .data[[time_col]][ok],
            .data[[pop_col]][ok]
          )
        } else {
          NA_real_
        }
      },
      .groups = "drop"
    ) |>
    dplyr::mutate(
      coverage = dplyr::if_else(
        .data$total_population > 0,
        .data$valid_population / .data$total_population,
        NA_real_
      ),
      weighted_minutes = dplyr::if_else(
        .data$coverage >= min_coverage,
        .data$weighted_minutes,
        NA_real_
      ),
      exposed_population = dplyr::if_else(
        .data$coverage >= min_coverage,
        .data$exposed_population,
        NA_real_
      )
    )
  current <- summaries |>
    dplyr::filter(.data[[year_col]] == years[2]) |>
    dplyr::mutate(
      access_band = base::cut(
        .data$weighted_minutes,
        breaks = c(-base::Inf, 30, 60, 120, 180, base::Inf),
        labels = c("0-30", "30-60", "60-120",
                   "120-180", ">180"),
        right = TRUE
      )
    )
  earlier <- summaries |>
    dplyr::filter(.data[[year_col]] == years[1]) |>
    dplyr::select(
      .data$hex_id,
      earlier_minutes = .data$weighted_minutes
    )
  comparison <- current |>
    dplyr::inner_join(earlier, by = "hex_id") |>
    dplyr::mutate(
      change_minutes = .data$weighted_minutes -
        .data$earlier_minutes
    )
  if (base::nrow(comparison) == 0L) {
    base::stop("No shared hexagons across comparison years")
  }
  current_sf <- dplyr::left_join(
    hexagons, current, by = "hex_id"
  )
  comparison_sf <- dplyr::left_join(
    hexagons, comparison, by = "hex_id"
  )
  base_map <- function() {
    ggplot2::geom_sf(
      data = sf::st_sf(geometry = region),
      fill = NA,
      color = "#293646",
      linewidth = 0.35
    )
  }
  theme_map <- function() {
    ggplot2::theme_void() +
      ggplot2::theme(
        plot.title = ggplot2::element_text(
          face = "bold", size = 16
        ),
        plot.background = ggplot2::element_rect(
          fill = "#FAF8F2", color = NA
        )
      )
  }
  travel_map <- ggplot2::ggplot(current_sf) +
    ggplot2::geom_sf(
      ggplot2::aes(fill = .data$access_band),
      linewidth = 0.05, color = "white"
    ) +
    ggplot2::scale_fill_manual(
      values = c(
        "0-30" = "#50336E",
        "30-60" = "#8B73B1",
        "60-120" = "#67A3BB",
        "120-180" = "#AED4B5",
        ">180" = "#F4E5AE"
      ),
      na.value = "#D8D8D8",
      drop = FALSE,
      name = "Population-weighted minutes"
    ) +
    base_map() +
    ggplot2::labs(
      title = base::paste("Access in", years[2])
    ) +
    theme_map()
  exposure_map <- ggplot2::ggplot(current_sf) +
    ggplot2::geom_sf(
      ggplot2::aes(fill = .data$exposed_population),
      linewidth = 0.05, color = "white"
    ) +
    ggplot2::scale_fill_viridis_c(
      option = "magma", trans = "sqrt",
      na.value = "#D8D8D8",
      name = "Residents >60 minutes"
    ) +
    base_map() +
    ggplot2::labs(
      title = base::paste("Population exposure in", years[2])
    ) +
    theme_map()
  change_map <- ggplot2::ggplot(comparison_sf) +
    ggplot2::geom_sf(
      ggplot2::aes(fill = .data$change_minutes),
      linewidth = 0.05, color = "white"
    ) +
    ggplot2::scale_fill_gradient2(
      low = "#277B79",
      mid = "#F8F6EF",
      high = "#A44863",
      midpoint = 0,
      na.value = "#D8D8D8",
      name = "Change (minutes)"
    ) +
    base_map() +
    ggplot2::labs(
      title = base::paste(
        "Change in access:", years[1], "to", years[2]
      )
    ) +
    theme_map()
  base::message(
    "Hex maps complete: ",
    base::format(base::nrow(hexagons), big.mark = ","),
    " hexagons; ",
    base::format(base::nrow(summaries), big.mark = ","),
    " hexagon-years"
  )
  base::list(
    hexagons = hexagons,
    summaries = summaries,
    travel_map = travel_map,
    exposure_map = exposure_map,
    change_map = change_map
  )
}
