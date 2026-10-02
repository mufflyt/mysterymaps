#' Geocode unique addresses from a file
#'
#' Reads an input dataset containing an `address` column, geocodes the unique
#' addresses, and returns the data with additional `latitude` and `longitude`
#' columns. Optionally writes the result to `output_file_path`.
#'
#' By default, addresses are geocoded with the free, keyless **US Census
#' Bureau Geocoding Services API** (`provider = "census"`). Pass
#' `provider = "google"` and a `google_maps_api_key` to geocode with
#' `ggmap::geocode()` instead (useful for non-US addresses, which the Census
#' API cannot handle).
#'
#' @param file_path Path to a CSV, RDS or XLSX file containing an `address`
#'   column.
#' @param google_maps_api_key A valid Google Maps API key. Only required when
#'   `provider = "google"`.
#' @param provider Which geocoding service to use: `"census"` (default, free,
#'   no key, US addresses only) or `"google"` (requires
#'   `google_maps_api_key`, works worldwide).
#' @param census_benchmark Character. The Census Bureau benchmark dataset
#'   used when `provider = "census"`. Defaults to `"Public_AR_Current"`, the
#'   current public address range benchmark. See
#'   <https://geocoding.geo.census.gov/geocoder/benchmarks> for other values.
#' @param output_file_path Optional path to save the geocoded dataset as CSV.
#' @param failed_output_path Optional path that captures rows that failed to
#'   geocode after all retries. When supplied, a timestamped backup is created
#'   before overwriting existing results.
#' @param notify Logical. If `TRUE`, play a notification sound when geocoding
#'   finishes (requires the optional `beepr` package). Defaults to `TRUE`.
#' @param quiet Logical flag controlling log verbosity. Defaults to the package
#'   quiet-mode option.
#' @param tracker Optional progress tracker created with [mysterycall_progress_tracker()].
#'   When supplied, the step named by `tracker_step` is automatically started and
#'   marked as complete or failed with an appropriate quality tier.
#' @param tracker_step Character string describing the step name used when
#'   updating `tracker`.
#'
#' @return A data frame with all original columns from the input file plus two
#'   new numeric columns:
#'   \describe{
#'     \item{`latitude`}{Numeric. Geographic latitude in decimal degrees
#'       (WGS 84). `NA` for addresses that failed geocoding after all retries.}
#'     \item{`longitude`}{Numeric. Geographic longitude in decimal degrees
#'       (WGS 84). `NA` for addresses that failed geocoding after all retries.}
#'   }
#'   Side effects: when `output_file_path` is non-`NULL`, the enriched data
#'   frame is written as CSV; when `failed_output_path` is non-`NULL`, rows
#'   that could not be geocoded are written separately (with a timestamped
#'   backup if the file already exists).
#'
#' @section Requirements:
#'   \strong{`provider = "census"` (default):} Requires the `httr2` and
#'   `curl` packages (listed in `Suggests`). No API key is needed. The Census
#'   Bureau batch geocoder only covers addresses in the United States; rows
#'   it cannot match (including non-US addresses) are returned with `NA`
#'   coordinates the same way a failed Google lookup would be.
#'
#'   \strong{`provider = "google"`:} Requires the `ggmap` package (listed in
#'   `Suggests`, not `Imports`) and a Google Maps Platform API key with the
#'   **Geocoding API** enabled. Steps to obtain a key:
#'   \enumerate{
#'     \item Create a project at <https://console.cloud.google.com/>.
#'     \item Enable the **Geocoding API** under APIs & Services > Library.
#'     \item Create a key under APIs & Services > Credentials.
#'     \item Enable **billing** on the project (required even for free-tier usage;
#'           Google provides a $200/month credit that covers ~40,000 geocodes).
#'   }
#'
#'   Common errors and remedies:
#'   \tabular{ll}{
#'     **Error message** \tab **Cause / fix** \cr
#'     `"ggmap is required"` \tab Run `install.packages("ggmap")`. \cr
#'     `"REQUEST_DENIED"` \tab Geocoding API not enabled for the key. \cr
#'     `"OVER_QUERY_LIMIT"` \tab Daily free quota (40,000 calls) exceeded. \cr
#'     `"INVALID_REQUEST"` \tab Malformed address string in the data.
#'   }
#'
#'   An invalid or expired Google key is only detected at the first geocoding
#'   request, not at function entry. Run [mysterycall_preflight_check()] with
#'   `check_apis = TRUE` before a long workflow to catch key problems early.
#'
#' @seealso [mysterycall_preflight_check()] to validate API keys before a long
#'   workflow; [mysterymaps_create_isochrones()] to compute drive-time polygons
#'   from geocoded coordinates.
#' @family geospatial helpers
#' @export
#' @examplesIf interactive()
#' # Default: free Census Bureau geocoder, no API key required.
#' result <- mysterymaps_geocode("addresses.csv")
#'
#' # Opt into Google's geocoder (e.g. for non-US addresses).
#' result <- mysterymaps_geocode("addresses.csv",
#'                                google_maps_api_key = "my_api_key",
#'                                provider = "google")
#' @importFrom readr read_csv write_csv
#' @importFrom dplyr left_join distinct mutate
#' @importFrom tibble tibble
#' @importFrom stats complete.cases
#'
mysterymaps_geocode <- function(file_path, google_maps_api_key = NULL,
                                     provider = c("census", "google"),
                                     census_benchmark = "Public_AR_Current",
                                     output_file_path = NULL,
                                     failed_output_path = NULL,
                                     notify = TRUE,
                                     quiet = getOption("mysterycall.quiet", FALSE),
                                     tracker = NULL,
                                     tracker_step = "Geocoding") {
  if (!file.exists(file_path)) {
    stop("Input file not found.", call. = FALSE)
  }

  provider <- match.arg(provider, c("census", "google"))

  # Read input based on extension
  ext <- tools::file_ext(file_path)
  data <- switch(tolower(ext),
                 csv = {
                   if (!requireNamespace("readr", quietly = TRUE)) {
                     stop("Package 'readr' is required to read CSV input.", call. = FALSE)
                   }
                   readr::read_csv(file_path, show_col_types = FALSE)
                 },
                 rds = readRDS(file_path),
                 xlsx = {
                   if (!requireNamespace("readxl", quietly = TRUE)) {
                     stop("Package 'readxl' is required to read Excel files", call. = FALSE)
                   }
                   readxl::read_excel(file_path)
                 },
                 stop("Unsupported file type: ", ext, call. = FALSE))

  if (!"address" %in% names(data)) {
    stop("The dataset must have a column named 'address' for geocoding.", call. = FALSE)
  }

  if (identical(provider, "google")) {
    if (!requireNamespace("ggmap", quietly = TRUE)) {
      stop("Package 'ggmap' is required for mysterymaps_geocode() with provider = \"google\"", call. = FALSE)
    }
    if (is.null(google_maps_api_key) || !nzchar(google_maps_api_key)) {
      stop("google_maps_api_key is required when provider = \"google\".", call. = FALSE)
    }
    ggmap::register_google(key = google_maps_api_key)
  }

  unique_add <- dplyr::distinct(data, address)
  total_unique <- nrow(unique_add)
  if (!isTRUE(quiet)) {
    message("  \u2139 ", sprintf("Geocoding %d unique address(es) via %s.", total_unique, provider))
    message("  \u2139 ", sprintf("Found %d total address records, %d unique", nrow(data), total_unique))
  }

  # tracker calls are no-ops; tracker is a mysterycall internal object
  invisible(NULL)  # progress_start placeholder

  extract_status <- function(msg) {
    code <- regmatches(msg, regexpr("\\b[0-9]{3}\\b", msg))
    if (length(code) && nzchar(code)) {
      return(paste("after", code))
    }
    msg_clean <- gsub("\\s+", " ", msg)
    paste("due to", substr(msg_clean, 1, 120))
  }

  max_attempts <- 3L
  base_delay <- 1
  coords <- tibble::tibble(lat = numeric(), lon = numeric())
  if (total_unique) {
    first_address <- unique_add$address[[1]]
    for (attempt in seq_len(max_attempts)) {
      attempt_result <- tryCatch({
        if (identical(provider, "google")) {
          ggmap::geocode(unique_add$address, key = google_maps_api_key)
        } else {
          mysterymaps_census_geocode(unique_add$address, benchmark = census_benchmark)
        }
      }, error = function(e) e)

      if (inherits(attempt_result, "error")) {
        reason <- extract_status(attempt_result$message)
        if (!isTRUE(quiet)) {
          message("  \u2139 ", sprintf(
            "Attempt %d/%d for address '%s' failed %s.",
            attempt, max_attempts, first_address, reason
          ))
        }

        if (attempt == max_attempts) {
          failure_reason <- sprintf("Geocoding failed after %d attempts: %s", max_attempts, attempt_result$message)
          if (!is.null(failed_output_path)) {
            failure_tbl <- tibble::tibble(address = unique_add$address, reason = failure_reason)
            readr::write_csv(failure_tbl, failed_output_path)
          }
          # tracker_fail is a no-op (tracker is a mysterycall internal)
          stop(failure_reason, call. = FALSE)
        }

        delay <- base_delay * 2^(attempt - 1)
        if (!isTRUE(quiet)) message("  \u2139 ", sprintf("Retrying geocode request in %.1f seconds...", delay))
        Sys.sleep(delay)
      } else {
        coords <- attempt_result

        # Validate geocoding result structure immediately (Bug #11 fix)
        if (!is.data.frame(coords)) {
          stop("Geocoding API returned unexpected data type (expected data frame).", call. = FALSE)
        }
        if (!"lat" %in% names(coords) || !"lon" %in% names(coords)) {
          stop(sprintf(
            "Geocoding API returned unexpected structure. Expected 'lat' and 'lon' columns, got: %s",
            paste(names(coords), collapse = ", ")
          ), call. = FALSE)
        }
        checkmate::assert_true(length(coords$lat) == nrow(coords), .var.name = "lat length")
        checkmate::assert_true(length(coords$lon) == nrow(coords), .var.name = "lon length")

        break
      }
    }
  }

  if (nrow(coords) != nrow(unique_add)) {
    message(sprintf(
      "Geocoding returned %d row(s) but %d were expected; setting all coordinates to NA to prevent misassignment.",
      nrow(coords), nrow(unique_add)
    ))
    coords <- tibble::tibble(lat = rep(NA_real_, nrow(unique_add)), lon = rep(NA_real_, nrow(unique_add)))
  }
  unique_add <- dplyr::mutate(unique_add,
                              latitude = coords$lat,
                              longitude = coords$lon)

  failed_rows <- unique_add[!stats::complete.cases(unique_add[, c("latitude", "longitude")]), , drop = FALSE]
  success_rate <- if (total_unique) 1 - nrow(failed_rows) / total_unique else 1
  success_count <- total_unique - nrow(failed_rows)
  checkmate::assert_number(success_rate, lower = 0, upper = 1)
  checkmate::assert_int(success_count, lower = 0)
  checkmate::assert_true(success_count <= total_unique, .var.name = "success_count bound")

  # Report geocoding results
  if (!isTRUE(quiet)) {
    if (success_rate >= 0.95) {
      message("  \u2713 ", sprintf("Geocoding complete: %d/%d succeeded (%.1f%%)",
                                   success_count, total_unique, success_rate * 100))
    } else if (success_rate >= 0.80) {
      message("  \u26a0 WARNING: ", sprintf("Geocoding finished with warnings: %d/%d succeeded (%.1f%%)",
                                            success_count, total_unique, success_rate * 100))
    } else {
      message("  \u2717 ERROR: ", sprintf("Geocoding had low success rate: %d/%d succeeded (%.1f%%)",
                                          success_count, total_unique, success_rate * 100))
    }
  }

  if (nrow(failed_rows) && !is.null(failed_output_path)) {
    readr::write_csv(failed_rows, failed_output_path)
    if (!isTRUE(quiet)) message("  \u2139 ", sprintf("Exported %d failed address(es) to %s", nrow(failed_rows), failed_output_path))
  }

  # tracker_finish is a no-op (tracker is a mysterycall internal)
  invisible(NULL)

  data <- dplyr::left_join(data, unique_add, by = "address")

  if (!is.null(output_file_path)) {
    readr::write_csv(data, output_file_path)
    if (!quiet) {
      message("  Saved to ", output_file_path, " (", nrow(data), " rows)")
    }
  }

  if (isTRUE(interactive()) && isTRUE(notify) && requireNamespace("beepr", quietly = TRUE)) {
    beepr::beep(2)
  }
  data
}

#' Geocode a vector of addresses with the Census Bureau batch geocoder
#'
#' Internal helper for [mysterymaps_geocode()]. Splits `addresses` into
#' batches of at most `mysterymaps_census_batch_limit()` addresses, submits
#' each batch to the Census Bureau's address batch geocoder, and returns
#' coordinates in the same order as `addresses`.
#'
#' @param addresses Character vector of addresses.
#' @param benchmark Character. The Census Bureau benchmark to geocode against.
#'
#' @return A tibble with `lat` and `lon` numeric columns, one row per element
#'   of `addresses`, in the same order. Unmatched addresses get `NA`.
#' @keywords internal
#' @noRd
mysterymaps_census_geocode <- function(addresses, benchmark) {
  if (!requireNamespace("httr2", quietly = TRUE)) {
    stop("Package 'httr2' is required to geocode with provider = \"census\".", call. = FALSE)
  }
  if (!requireNamespace("curl", quietly = TRUE)) {
    stop("Package 'curl' is required to geocode with provider = \"census\".", call. = FALSE)
  }

  n <- length(addresses)
  lat <- rep(NA_real_, n)
  lon <- rep(NA_real_, n)

  batch_limit <- mysterymaps_census_batch_limit()
  chunk_starts <- seq.int(1L, n, by = batch_limit)
  for (start in chunk_starts) {
    end <- min(start + batch_limit - 1L, n)
    idx <- seq.int(start, end)
    chunk <- mysterymaps_census_geocode_chunk(addresses[idx], benchmark = benchmark)
    lat[idx] <- chunk$lat
    lon[idx] <- chunk$lon
  }

  tibble::tibble(lat = lat, lon = lon)
}

#' Maximum number of addresses the Census batch geocoder accepts per request
#' @keywords internal
#' @noRd
mysterymaps_census_batch_limit <- function() 10000L

#' Submit one batch of addresses to the Census Bureau geocoder
#'
#' @param addresses Character vector of at most
#'   `mysterymaps_census_batch_limit()` addresses.
#' @param benchmark Character. The Census Bureau benchmark to geocode against.
#'
#' @return A tibble with `lat` and `lon` numeric columns, one row per element
#'   of `addresses`, in the same order.
#' @keywords internal
#' @noRd
mysterymaps_census_geocode_chunk <- function(addresses, benchmark) {
  csv_path <- tempfile(fileext = ".csv")
  on.exit(unlink(csv_path), add = TRUE)

  batch_df <- data.frame(
    id = seq_along(addresses),
    street = addresses,
    city = NA_character_,
    state = NA_character_,
    zip = NA_character_,
    stringsAsFactors = FALSE
  )
  utils::write.table(batch_df, csv_path, sep = ",", col.names = FALSE,
                      row.names = FALSE, na = "", qmethod = "double")

  resp <- mysterymaps_census_batch_request(csv_path, benchmark = benchmark)
  if (resp$status != 200) {
    stop(sprintf("Census geocoding request failed with HTTP %d.", resp$status), call. = FALSE)
  }

  result_cols <- c("id", "input_address", "match_status", "match_type",
                    "matched_address", "coordinates", "tigerline_id", "side")
  parsed <- utils::read.csv(text = resp$body, header = FALSE, col.names = result_cols,
                             fill = TRUE, stringsAsFactors = FALSE)
  parsed <- parsed[order(as.integer(parsed$id)), , drop = FALSE]

  lonlat <- strsplit(parsed$coordinates, ",")
  lon <- vapply(lonlat, function(x) if (length(x) == 2) as.numeric(x[[1]]) else NA_real_, numeric(1))
  lat <- vapply(lonlat, function(x) if (length(x) == 2) as.numeric(x[[2]]) else NA_real_, numeric(1))

  tibble::tibble(lat = lat, lon = lon)
}

#' Perform the HTTP POST to the Census Bureau address batch endpoint
#'
#' Isolated in its own function so tests can mock the network call.
#'
#' @param csv_path Path to the batch CSV file (no header; columns id, street,
#'   city, state, zip).
#' @param benchmark Character. The Census Bureau benchmark to geocode against.
#' @param timeout_sec Request timeout in seconds.
#'
#' @return A list with `status` (integer HTTP status) and `body` (character,
#'   the raw CSV response text).
#' @keywords internal
#' @noRd
mysterymaps_census_batch_request <- function(csv_path, benchmark, timeout_sec = 120) {
  resp <- httr2::request("https://geocoding.geo.census.gov/geocoder/locations/addressbatch") |>
    httr2::req_body_multipart(
      addressFile = curl::form_file(csv_path),
      benchmark = benchmark
    ) |>
    httr2::req_timeout(timeout_sec) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()

  list(status = httr2::resp_status(resp), body = httr2::resp_body_string(resp))
}
