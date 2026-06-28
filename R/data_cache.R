#' @keywords internal
NULL

# nocov start

mysterymaps_cache_dir <- function(...) {
  cache_root <- if (getRversion() >= "4.0.0") {
    tools::R_user_dir("mysterymaps", which = "cache")
  } else {
    file.path(path.expand("~"), ".cache", "mysterymaps")
  }
  if (!dir.exists(cache_root))
    dir.create(cache_root, recursive = TRUE, showWarnings = FALSE)
  if (missing(...)) cache_root else file.path(cache_root, ...)
}

ensure_hrr_shapefile <- function(quiet = TRUE) {
  cache_root    <- mysterymaps_cache_dir()
  archive_path  <- file.path(cache_root, "HRR_Bdry__AK_HI_unmodified.zip")
  shapefile_path <- file.path(
    cache_root, "HRR_Bdry__AK_HI_unmodified",
    "mysterycall_hrr-shapefile", "Hrr98Bdry_AK_HI_unmodified.shp"
  )

  if (!file.exists(shapefile_path)) {
    message("Downloading HRR boundary shapefile (~8 MB). This is a one-time operation.")
    mysterycall::mysterycall_download_file(
      "https://data.dartmouthatlas.org/downloads/geography/HRR_Bdry__AK_HI_unmodified.zip",
      archive_path, overwrite = TRUE, quiet = quiet
    )
    utils::unzip(archive_path, exdir = cache_root)
    macos_metadata <- file.path(cache_root, "__MACOSX")
    if (dir.exists(macos_metadata)) unlink(macos_metadata, recursive = TRUE, force = TRUE)
  }

  if (!file.exists(shapefile_path))
    stop(
      "Failed to retrieve the HRR boundary shapefile. ",
      "Please try again or download it manually from ",
      "https://data.dartmouthatlas.org/supplemental/.",
      call. = FALSE
    )

  shapefile_path
}

# nocov end
