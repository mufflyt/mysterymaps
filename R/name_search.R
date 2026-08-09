#' Add a name search box over the map's marker layers
#'
#' @description
#' Puts a search control on the map that finds markers by their label text and
#' zooms to the match — the "where is this provider" question a reader asks
#' first, which panning and zooming answers badly.
#'
#' @details
#' Implemented with `leaflet.extras::addSearchFeatures()`, which bundles the
#' Leaflet-search plugin as a local HTML dependency. A hand-rolled version of
#' this control bootstrapped the same plugin from a CDN, which makes the search
#' box quietly non-functional for anyone opening the saved HTML offline — and a
#' control that silently does nothing is worse than an absent one. There is no
#' CDN here; a self-contained widget stays self-contained.
#'
#' Markers must carry a `label`; that is what is searched.
#'
#' @section Which layers are searched:
#' `group` is required. Auto-detection was considered and rejected: leaflet
#' stores the group name positionally in the widget call list, which is
#' undocumented and changes between versions.
#'
#' @param map A leaflet widget with at least one marker layer.
#' @param group `character`: marker group(s) to search. Required.
#' @param placeholder `character(1)`: text shown in the empty box.
#' @param zoom `integer(1)`: zoom level applied to a match. Default 11.
#' @param position `character(1)`: control corner. Default `"topright"`.
#' @return The leaflet widget with the control attached; unchanged, with a
#'   warning, if `leaflet.extras` is unavailable.
#' @family map-templates
#' @export
mysterymaps_name_search <- function(map, group = NULL,
                                    placeholder = "Search…",
                                    zoom = 11L, position = "topright") {
  if (!requireNamespace("leaflet.extras", quietly = TRUE)) {
    warning("leaflet.extras is not installed; no search control added.",
            call. = FALSE)
    return(map)
  }

  if (is.null(group) || !length(group)) {
    # Deliberately no auto-detection. The group name is stored positionally in
    # the widget's call list (index 5 for addCircleMarkers on leaflet 2.2),
    # which is undocumented and version-dependent -- exactly the kind of magic
    # that keeps working until it quietly does not. Callers know their own
    # layer names.
    stop("`group` is required: name the marker layer(s) to search, e.g. ",
         "mysterymaps_name_search(m, group = \"Providers\").", call. = FALSE)
  }

  leaflet.extras::addSearchFeatures(
    map, targetGroups = group,
    options = leaflet.extras::searchFeaturesOptions(
      zoom = zoom, openPopup = TRUE, firstTipSubmit = TRUE,
      autoCollapse = FALSE, hideMarkerOnCollapse = TRUE,
      position = position, textPlaceholder = placeholder))
}
