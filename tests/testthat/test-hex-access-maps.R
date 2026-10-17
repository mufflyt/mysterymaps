testthat::test_that("hex maps preserve weighted exposure and change", {
  skip_if_not_installed("sf")
  locations <- sf::st_as_sf(
    base::data.frame(
      origin_id = c("a", "b", "a", "b"),
      year = c(2013L, 2013L, 2023L, 2023L),
      population = c(100, 300, 100, 300),
      travel_minutes = c(20, 80, 40, 100),
      x = c(-78, -78.01, -78, -78.01),
      y = c(37, 37.01, 37, 37.01)
    ),
    coords = c("x", "y"),
    crs = 4326
  )
  region <- sf::st_as_sfc(
    sf::st_bbox(
      c(xmin = -79, ymin = 36, xmax = -77, ymax = 38),
      crs = sf::st_crs(4326)
    )
  )
  region <- sf::st_sf(geometry = region)
  mapped <- mysterymaps_hex_access_maps(
    locations, region, hex_km = 300
  )
  testthat::expect_s3_class(mapped$travel_map, "ggplot")
  testthat::expect_s3_class(mapped$exposure_map, "ggplot")
  testthat::expect_s3_class(mapped$change_map, "ggplot")
  testthat::expect_equal(
    base::sum(
      mapped$summaries$exposed_population[
        mapped$summaries$year == 2023
      ]
    ),
    300
  )
  change <- mapped$change_map$data$change_minutes
  testthat::expect_equal(change[!base::is.na(change)], 20)
})

testthat::test_that("invalid population fails closed", {
  locations <- sf::st_as_sf(
    base::data.frame(
      origin_id = c("a", "a"),
      year = c(2013L, 2023L),
      population = c(-1, 1),
      travel_minutes = c(30, 40),
      x = c(-78, -78),
      y = c(37, 37)
    ),
    coords = c("x", "y"),
    crs = 4326
  )
  region <- sf::st_sf(
    geometry = sf::st_as_sfc(
      sf::st_bbox(
        c(xmin = -79, ymin = 36, xmax = -77, ymax = 38),
        crs = sf::st_crs(4326)
      )
    )
  )
  testthat::expect_error(
    mysterymaps_hex_access_maps(locations, region),
    "Invalid population"
  )
})
