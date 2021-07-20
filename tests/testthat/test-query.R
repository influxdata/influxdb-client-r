.client = test.client
.data = test.airSensors.data
.data.pivoted = test.airSensors.data.pivoted
.data.multi = test.airSensors.data.multi

with_mock_api({
  test_that("query", {
    response <- .client$query(text='from(bucket: "r-testing") |> range(start: -10y) |> filter(fn: (r) => r._measurement == "airSensors" and r.sensor_id == "TLM0101") |> limit(n: 5) |> drop(columns: ["_start", "_stop"])',
                              POSIXctCol = NULL)
    expected <- .data
    expect_equal(response, expected)
  })

  test_that("query / default time mapping", {
    response <- .client$query(text='from(bucket: "r-testing") |> range(start: -10y) |> filter(fn: (r) => r._measurement == "airSensors" and r.sensor_id == "TLM0101") |> limit(n: 5) |> drop(columns: ["_start", "_stop"])')
    expected <- lapply(.data, function(df) {
      df$time <- as.POSIXct(df$`_time`, tz = "GMT")
      df
    })
    expect_equal(response, expected)
  })

  test_that("query / explicit time mapping", {
    response <- .client$query(text='from(bucket: "r-testing") |> range(start: -10y) |> filter(fn: (r) => r._measurement == "airSensors" and r.sensor_id == "TLM0101") |> limit(n: 5) |> drop(columns: ["_start", "_stop"])',
                              POSIXctCol = c("_time"="posixct"))
    expected <- lapply(.data, function(df) {
      df$posixct <- as.POSIXct(df$`_time`, tz = "GMT")
      df
    })
    expect_equal(response, expected)
  })

  test_that("query / pivoted", {
    response <- .client$query(text='import "influxdata/influxdb/schema" from(bucket: "r-testing") |> range(start: -10y) |> filter(fn: (r) => r._measurement == "airSensors" and r.sensor_id == "TLM0101") |> schema.fieldsAsCols() |> limit(n: 5) |> drop(columns: ["_start", "_stop"])',
                              POSIXctCol = NULL)
    expected <- .data.pivoted
    expect_equal(response, expected)
  })

  test_that("query / empty result", {
    response <- .client$query(text='from(bucket: "r-testing") |> range(start: -10y) |> filter(fn: (r) => r._measurement == "doesnotexist")',
                              POSIXctCol = NULL)
    expect_null(response)
  })

  test_that("query / multiple tables in one csv table", {
    response <- .client$query(text='from(bucket: "r-testing") |> range(start: -10y) |> filter(fn: (r) => r._measurement == "airSensors" and (r.sensor_id == "TLM0101" or r.sensor_id == "TLM0102") and r._field != "grounded") |> limit(n: 3) |> drop(columns: ["_start", "_stop"])',
                              POSIXctCol = NULL)
    expected <- .data.multi
    expect_equal(response, expected)
  })

  test_that("query / single result not flattened", {
    response <- .client$query(text='from(bucket: "r-testing") |> range(start: -10y) |> filter(fn: (r) => r._measurement == "airSensors" and r.sensor_id == "TLM0101") |> limit(n: 5) |> drop(columns: ["_start", "_stop"])',
                              flatSingleResult = FALSE)
    result = lapply(.data, function(df) {
      df$time <- as.POSIXct(df$`_time`, tz = "GMT")
      df
    })
    expected <- list("_result" = result)
    expect_equal(response, expected)
  })

  test_that("query / multiple results", {
    response <- .client$query(text='data = from(bucket: "r-testing") |> range(start: -10y) |> filter(fn: (r) => r._measurement == "airSensors" and r.sensor_id == "TLM0101") |> limit(n: 5) |> drop(columns: ["_start", "_stop"]) data |> yield(name: "abc") data |> yield(name: "xyz")')
    result = lapply(.data, function(df) {
      df$time <- as.POSIXct(df$`_time`, tz = "GMT")
      df
    })
    expected <- list("abc" = result, "xyz" = result)
    expect_equal(response, expected)
  })

  test_that("query / non-existent bucket", {
    f <- function() {
      .client$query(text='from(bucket: "no-bucket") |> range(start: -10y) |> filter(fn: (r) => r._measurement == "airSensors" and r.sensor_id == "TLM0101") |> drop(columns: ["_start", "_stop"])')
    }
    expect_error(f(), 'API client error (404): failed to initialize execute state: could not find bucket "no-bucket"',
                 fixed = TRUE)

  })

  test_that("query / invalid time mapping (src)", {
    f <- function() {
      .client$query(text='from(bucket: "r-testing") |> range(start: -10y) |> filter(fn: (r) => r._measurement == "airSensors" and r.sensor_id == "TLM0101") |> limit(n: 5) |> drop(columns: ["_start", "_stop"])',
                    POSIXctCol = c("_notime"="posixct"))
    }
    expect_error(f(), "cannot coerce '_notime' to 'posixct': column does not exist", fixed = TRUE)
  })

  test_that("query / invalid time mapping (tgrget)", {
    f <- function() {
      .client$query(text='from(bucket: "r-testing") |> range(start: -10y) |> filter(fn: (r) => r._measurement == "airSensors" and r.sensor_id == "TLM0101") |> limit(n: 5) |> drop(columns: ["_start", "_stop"])',
                    POSIXctCol = c("_time"="_time"))
    }
    expect_error(f(), "cannot coerce '_time' to '_time': column already exist", fixed = TRUE)
  })
})

test_that("query / NULL text query", {
  f <- function() {
    .client$query(NULL)
  }
  expect_error(f(), "'text' cannot be NULL", fixed = TRUE)
})

test_that("query / invalid time mapping", {
  f <- function() {
    .client$query('whatever', POSIXctCol = c("_time", "time"))
  }
  expect_error(f(), "'POSIXctCol' must be named list with 1 element", fixed = TRUE)
})
