#' Internal helper to validate and prepare sf inputs for spatial workflows.
#'
#' This function ensures objects share a common CRS, have valid geometries,
#' contain the expected geometry types, possess sensible bounding boxes, and
#' do not contain empty geometries. Invalid geometries are repaired with
#' `sf::st_make_valid()` when possible.
#'
#' @param ... Named sf objects to validate.
#' @param expected_types Named list mapping object names to allowed geometry
#'   types. A character vector applies to all inputs when names are omitted.
#' @param auto_fix Logical indicating whether invalid geometries should be
#'   repaired automatically. Defaults to `TRUE`.
#' @param target_crs Optional CRS (numeric EPSG code, proj4string, or `sf::crs`
#'   object) that all objects should be transformed into before bounding box
#'   checks. When `NULL`, the CRS of the first object is used.
#' @param context Character string identifying the calling context for clearer
#'   error messages.
#'
#' @return A named list of validated sf objects.
#' @family geospatial
#' @keywords internal
validate_sf_inputs <- function(...,
                               expected_types = NULL,
                               auto_fix = TRUE,
                               target_crs = NULL,
                               context = "geospatial operation") {
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Package 'sf' is required", call. = FALSE)
  }

  objects <- list(...)
  if (!length(objects)) {
    stop("No sf objects supplied for validation.", call. = FALSE)
  }

  object_names <- names(objects)
  if (is.null(object_names) || any(!nzchar(object_names))) {
    object_names <- paste0("object_", seq_along(objects))
    names(objects) <- object_names
  }

  if (!is.null(expected_types)) {
    if (is.character(expected_types)) {
      expected_types <- rep(list(expected_types), length(objects))
      names(expected_types) <- object_names
    } else if (is.list(expected_types)) {
      missing_names <- setdiff(object_names, names(expected_types))
      if (length(missing_names)) {
        expected_types[missing_names] <- expected_types[[1]]
      }
    } else {
      stop("`expected_types` must be a character vector or named list.", call. = FALSE)
    }
  }

  # Check the class BEFORE reading a CRS off the first object. Passing a plain
  # data.frame is the commonest caller mistake, and st_crs() on one returns NA,
  # so leaving this until sanitize_object() reported "Reference CRS is missing"
  # -- an accurate statement about the wrong problem, sending the caller to
  # inspect a CRS that was never there.
  for (nm in object_names) {
    if (!inherits(objects[[nm]], "sf")) {
      stop(sprintf("`%s` must be an sf object for %s.", nm, context), call. = FALSE)
    }
  }

  ref_crs <- if (!is.null(target_crs)) {
    sf::st_crs(target_crs)
  } else {
    sf::st_crs(objects[[1]])
  }

  if (is.na(ref_crs)) {
    stop(sprintf("Reference CRS is missing for %s.", context), call. = FALSE)
  }

  # Rely on sf/PROJ CRS parsing instead of synthetic point/bbox checks that can
  # produce false negatives for some valid projected CRSs.
  if (is.na(ref_crs$wkt) || !nzchar(ref_crs$wkt)) {
    stop(sprintf("CRS validation failed for %s: unresolved CRS definition.", context))
  }

  sanitize_object <- function(obj, name) {
    if (!inherits(obj, "sf")) {
      stop(sprintf("`%s` must be an sf object for %s.", name, context), call. = FALSE)
    }
    if (!nrow(obj)) {
      stop(sprintf("`%s` has no rows; cannot proceed with %s.", name, context), call. = FALSE)
    }

    obj_crs <- sf::st_crs(obj)
    if (is.na(obj_crs)) {
      stop(sprintf("`%s` is missing a defined CRS for %s.", name, context), call. = FALSE)
    }

    if (!is.null(target_crs)) {
      obj <- sf::st_transform(obj, ref_crs)
    } else if (!identical(obj_crs, ref_crs)) {
      warning(sprintf(
        "`%s` CRS (%s) differs from reference CRS (%s) for %s; transforming automatically.",
        name,
        if (!is.na(obj_crs$input)) obj_crs$input else "unknown",
        if (!is.na(ref_crs$input)) ref_crs$input else "unknown",
        context
      ), call. = FALSE)
      obj <- sf::st_transform(obj, ref_crs)
    }

    geom <- sf::st_geometry(obj)
    if (is.null(geom)) {
      stop(sprintf("`%s` lacks a geometry column required for %s.", name, context), call. = FALSE)
    }

    empty_idx <- which(sf::st_is_empty(geom))
    if (length(empty_idx)) {
      stop(sprintf("`%s` contains empty geometries (rows: %s) incompatible with %s.",
                   name, paste(empty_idx, collapse = ", "), context), call. = FALSE)
    }

    invalid_idx <- which(!sf::st_is_valid(obj))
    if (length(invalid_idx)) {
      if (isTRUE(auto_fix)) {
        obj <- sf::st_make_valid(obj)
        still_invalid <- which(!sf::st_is_valid(obj))
        if (length(still_invalid)) {
          # s2 declines to repair a self-intersecting ring that the planar
          # algorithm splits cleanly into a MULTIPOLYGON -- and a
          # self-intersecting ring is precisely what a drive-time routing API
          # returns. Retry on the plane before giving up, restoring the
          # caller's s2 setting either way.
          old_s2 <- sf::sf_use_s2()
          on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)
          suppressMessages(sf::sf_use_s2(FALSE))
          obj <- sf::st_make_valid(obj)
          still_invalid <- which(!sf::st_is_valid(obj))
          suppressMessages(sf::sf_use_s2(old_s2))
        }
        if (length(still_invalid)) {
          stop(sprintf("`%s` has geometries that remain invalid after repair (rows: %s) during %s.",
                       name, paste(still_invalid, collapse = ", "), context), call. = FALSE)
        }
      } else {
        stop(sprintf("`%s` contains invalid geometries (rows: %s) disallowed in %s.",
                     name, paste(invalid_idx, collapse = ", "), context), call. = FALSE)
      }
    }

    if (!is.null(expected_types)) {
      allowed_types <- expected_types[[name]]
      if (is.null(allowed_types)) {
        allowed_types <- expected_types[[1]]
      }
      if (!is.null(allowed_types)) {
        geom_types <- unique(as.character(sf::st_geometry_type(obj)))
        if (!all(geom_types %in% allowed_types)) {
          stop(sprintf(
            "`%s` contains geometry types [%s]; expected only [%s] in %s.",
            name,
            paste(geom_types, collapse = ", "),
            paste(allowed_types, collapse = ", "),
            context
          ), call. = FALSE)
        }
      }
    }

    bbox <- sf::st_bbox(obj)
    if (any(!is.finite(bbox))) {
      stop(sprintf("`%s` has a bounding box with non-finite values in %s.", name, context), call. = FALSE)
    }
    if (bbox["xmin"] >= bbox["xmax"] || bbox["ymin"] >= bbox["ymax"]) {
      stop(sprintf("`%s` has a degenerate bounding box incompatible with %s.", name, context), call. = FALSE)
    }

    obj
  }

  objects <- Map(sanitize_object, objects, object_names)

  if (length(objects) > 1) {
    bbox_sfc <- lapply(objects, function(x) sf::st_as_sfc(sf::st_bbox(x)))
    bbox_intersection <- Reduce(sf::st_intersection, bbox_sfc)
    if (length(bbox_intersection) == 0 || all(sf::st_is_empty(bbox_intersection))) {
      stop(sprintf("Bounding boxes of supplied objects do not overlap for %s.", context), call. = FALSE)
    }
  }

  objects
}

#' Measure area on the globe, not in whatever CRS the caller stored it in
#'
#' The idiom this replaces is `as.numeric(sf::st_area(x)) / 1e6`, and it is
#' wrong in two independent ways that both produce a plausible number.
#'
#' @section The unit belongs to the CRS, not to the metre:
#' `sf::st_area()` returns a `units` object in the linear unit the CRS declares,
#' so dividing by `1e6` yields square kilometres only when that unit happens to
#' be the metre. Several US state plane systems are in US survey feet. EPSG:2232,
#' NAD83 / Colorado Central, is an ordinary choice for a Colorado study, and
#' there a polygon of 147,582 km2 measures 1,588,550 -- a factor of 10.76, with
#' no warning, because the arithmetic is valid and only the unit is wrong.
#'
#' @section A conformal projection preserves shape, not area:
#' Worse, because unit conversion cannot see it. In EPSG:3857 the same polygon
#' measures roughly 1.8x its true size at latitude 42 -- in metres, from a
#' metre-declaring CRS. Web Mercator is the default of every slippy map, so a
#' surface arriving straight off a web tile pipeline carries this silently.
#'
#' Both are avoided by not measuring in the caller's CRS at all: the geometry is
#' transformed to EPSG:4326 and measured geodesically, which is correct
#' everywhere rather than inside one projection's zone. That matters here --
#' [mysterymaps_guard_water_masks()] is handed Alaska and Hawaii, so no single
#' projected CRS (EPSG:5070 is CONUS) would do.
#'
#' @section Why s2 is forced on:
#' With `sf_use_s2(FALSE)`, `sf::st_area()` routes geodetic area through
#' `lwgeom`, a Suggests that is absent on a bare runner -- so the measurement
#' would not merely differ with the caller's session state, it would error on
#' exactly the machines where nothing is installed. s2's authalic sphere reads
#' about 0.15% under the ellipsoid on a state-sized polygon, which is immaterial
#' to a 5x threshold and to a number in a popup; depending on what the caller
#' ran first is not. The setting is restored on exit.
#'
#' Geometry with no CRS errors rather than defaulting. Coordinates with an
#' unknown unit are not a reason to assume metres, and assuming is the whole
#' failure above.
#'
#' @param x `sf|sfc`: geometry to measure. Areas are summed across features.
#' @param unit `character(1)`: the unit to return, as `units` spells it --
#'   `"km^2"`, `"m^2"`, `"mi^2"`.
#' @return `numeric(1)`: total area in `unit`. Zero for empty input.
#' @family geospatial
#' @keywords internal
mm_area_in <- function(x, unit = "km^2") {
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Package 'sf' is required", call. = FALSE)
  }
  # sf itself imports units, so this is present wherever sf is; the guard keeps
  # the failure legible rather than surfacing as "there is no package 'units'".
  if (!requireNamespace("units", quietly = TRUE)) {
    stop("Package 'units' is required to convert areas between CRS units.",
         call. = FALSE)
  }

  g <- if (inherits(x, "sf")) sf::st_geometry(x) else x
  if (!length(g)) return(0)

  if (is.na(sf::st_crs(g))) {
    stop("cannot measure area: the geometry has no CRS, so its coordinates ",
         "carry no unit and cannot be located on the globe. Set one with ",
         "sf::st_crs().", call. = FALSE)
  }

  old <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(old)), add = TRUE)
  suppressMessages(sf::sf_use_s2(TRUE))

  # sum() over a units vector keeps the unit; set_units() converts from it and
  # errors rather than guessing if it is not convertible to an area.
  a <- sum(sf::st_area(sf::st_transform(g, 4326)))
  as.numeric(units::set_units(a, unit, mode = "standard"))
}
