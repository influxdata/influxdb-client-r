# helper for testing private methods of InfluxDBClient
InfluxDBClientTest <- R6::R6Class(
  inherit = InfluxDBClient,
  public = list(
    fromAnnotatedCsv = function(x) {
      private$.fromAnnotatedCsv(x)
    },
    toLineProtocol = function(x, precision,
                              measurementCol, tagCols, fieldCols, timeCol) {
      private$.toLineProtocol(x, precision,
                              measurementCol, tagCols, fieldCols, timeCol)
    }
  )
)

# helper for testing private methods of InfluxDBApiClient
InfluxDBApiClientTest <- R6::R6Class(
  inherit = InfluxDBApiClient,
  public = list(
    delay = function(retryOptions, attempt, retryAfter, deadline) {
      private$.delay(retryOptions, attempt, retryAfter, deadline)
    }
  )
)

.client = InfluxDBClientTest$new(test.url, test.token, test.org)
.data = test.airSensors.data
.data.pivoted = test.airSensors.data.pivoted
.lp = list(
  c(
  "w-airSensors,region=south,sensor_id=TLM0101 altitude=549i 1623232361000000000",
  "w-airSensors,region=south,sensor_id=TLM0101 altitude=547i 1623232371000000000",
  "w-airSensors,region=south,sensor_id=TLM0101 altitude=563i 1623232381000000000",
  "w-airSensors,region=south,sensor_id=TLM0101 altitude=560i 1623232391000000000",
  "w-airSensors,region=south,sensor_id=TLM0101 altitude=544i 1623232401000000000"
  ),
  c(
  "w-airSensors,region=south,sensor_id=TLM0101 grounded=false 1623232361000000000",
  "w-airSensors,region=south,sensor_id=TLM0101 grounded=false 1623232371000000000",
  "w-airSensors,region=south,sensor_id=TLM0101 grounded=true 1623232381000000000",
  "w-airSensors,region=south,sensor_id=TLM0101 grounded=true 1623232391000000000",
  "w-airSensors,region=south,sensor_id=TLM0101 grounded=false 1623232401000000000"
  ),
  c(
  "w-airSensors,region=south,sensor_id=TLM0101 temperature=71.78441 1623232361000000000",
  "w-airSensors,region=south,sensor_id=TLM0101 temperature=71.7684399 1623232371000000000",
  "w-airSensors,region=south,sensor_id=TLM0101 temperature=71.7819928 1623232381000000000",
  "w-airSensors,region=south,sensor_id=TLM0101 temperature=71.7487767 1623232391000000000",
  "w-airSensors,region=south,sensor_id=TLM0101 temperature=71.7335579 1623232401000000000"
  )
)
.lp.pivoted = list(
  c(
    "w-airSensors,region=south,sensor_id=TLM0101 altitude=549i,grounded=false,temperature=71.78441 1623232361000000000",
    "w-airSensors,region=south,sensor_id=TLM0101 altitude=547i,grounded=false,temperature=71.7684399 1623232371000000000",
    "w-airSensors,region=south,sensor_id=TLM0101 altitude=563i,grounded=true,temperature=71.7819928 1623232381000000000",
    "w-airSensors,region=south,sensor_id=TLM0101 altitude=560i,grounded=true,temperature=71.7487767 1623232391000000000",
    "w-airSensors,region=south,sensor_id=TLM0101 altitude=544i,grounded=false,temperature=71.7335579 1623232401000000000"
  )
)
.lp.pivoted.notags = list(
  c(
    "w-airSensors altitude=549i,grounded=false,temperature=71.78441 1623232361000000000",
    "w-airSensors altitude=547i,grounded=false,temperature=71.7684399 1623232371000000000",
    "w-airSensors altitude=563i,grounded=true,temperature=71.7819928 1623232381000000000",
    "w-airSensors altitude=560i,grounded=true,temperature=71.7487767 1623232391000000000",
    "w-airSensors altitude=544i,grounded=false,temperature=71.7335579 1623232401000000000"
  )
)
.lp.specialcharacters = list(
  c(
    'w-air\\ Sensors,region\\,us=south\\ east,sensor\\ id=TLM0101 altitude=549i,grounded="x \\"false\\"",temperature=71.78441 1623232361000000000',
    'w-air\\ Sensors,region\\,us=south\\ east,sensor\\ id=TLM0101 altitude=547i,grounded="x \\"false\\"",temperature=71.7684399 1623232371000000000',
    'w-air\\ Sensors,region\\,us=south\\ east,sensor\\ id=TLM0101 altitude=563i,grounded="x \\"true\\"",temperature=71.7819928 1623232381000000000',
    'w-air\\ Sensors,region\\,us=south\\ east,sensor\\ id=TLM0101 altitude=560i,grounded="x \\"true\\"",temperature=71.7487767 1623232391000000000',
    'w-air\\ Sensors,region\\,us=south\\ east,sensor\\ id=TLM0101 altitude=544i,grounded="x \\"false\\"",temperature=71.7335579 1623232401000000000'
  )
)

test_that("toLineProtocol", {
  # change measurement value to avoid overwriting source
  data <- lapply(.data,
                 function(t) {
                   t['_measurement'] <- replicate(5, 'w-airSensors')
                   return(t)
                 })
  lp <- .client$toLineProtocol(data, precision = 'ns',
                               measurementCol = '_measurement',
                               tagCols = c("region", "sensor_id"),
                               fieldCols = c("_field"="_value"),
                               timeCol = '_time')
  expected <- .lp
  expect_equal(lp, expected)
})

test_that("toLineProtocol / pivoted", {
  # rename some columns in order to test non-default parameters
  # also change measurement value to avoid overwriting source
  data <- lapply(.data.pivoted,
                 function(t) {
                   t['_measurement'] <- replicate(5, 'w-airSensors')
                   colnames(t)[which(names(t) == '_time')] <- 'time'
                   colnames(t)[which(names(t) == '_measurement')] <- 'name'
                   return(t)
                 })
  lp <- .client$toLineProtocol(data, precision = 'ns',
                               measurementCol = 'name',
                               tagCols = c("region", "sensor_id"),
                               fieldCols = c("altitude", "grounded", "temperature"),
                               timeCol = 'time')
  expected <- .lp.pivoted
  expect_equal(lp, expected)
})

test_that("toLineProtocol / no tags", {
  data <- lapply(.data.pivoted,
                 function(t) {
                   t['_measurement'] <- replicate(5, 'w-airSensors')
                   return(t)
                 })
  lp <- .client$toLineProtocol(data, precision = 'ns',
                               measurementCol = '_measurement',
                               tagCols = NULL,
                               fieldCols = c("altitude", "grounded", "temperature"),
                               timeCol = '_time')
  expected <- .lp.pivoted.notags
  expect_equal(lp, expected)
})

test_that("toLineProtocol / special characters", {
  data <- lapply(.data.pivoted,
                 function(t) {
                   t['_measurement'] <- replicate(5, 'w-air Sensors')
                   t['region'] <- replicate(5, 'south east')
                   t['grounded'] <- lapply(t['grounded'], function(x) {
                     sprintf("x \"%s\"", tolower(as.character(x)))
                   })
                   colnames(t)[which(names(t) == 'region')] <- 'region,us'
                   colnames(t)[which(names(t) == 'sensor_id')] <- 'sensor id'
                   return(t)
                 })
  lp <- .client$toLineProtocol(data, precision = 'ns',
                               measurementCol = '_measurement',
                               tagCols = c("region,us", "sensor id"),
                               fieldCols = c("altitude", "grounded", "temperature"),
                               timeCol = '_time')
  expected <- .lp.specialcharacters
  expect_equal(lp, expected)

# actual HTTP payload:
# w-air\ Sensors,region\,us=south\ east,sensor\ id=TLM0101 altitude=549i,grounded="x \"false\"",temperature=71.78441 1623232361000000000
# ...

})

test_that("toLineProtocol / x is not data.frame", {
  data <- "not a data.frame"
  f <- function () {
    .client$toLineProtocol(data, precision = 'ns',
                           measurementCol = 'no-measurement',
                           tagCols = c("region", "sensor_id"),
                           fieldCols = c("altitude", "grounded", "temperature"),
                           timeCol = '_time')
  }
  expect_error(f(), "'x' must be data.frame", fixed = TRUE)
})

test_that("toLineProtocol / x is not list of data.frame", {
  data <- list(data.frame(), "not a data.frame")
  f <- function () {
    .client$toLineProtocol(data, precision = 'ns',
                           measurementCol = 'no-measurement',
                           tagCols = c("region", "sensor_id"),
                           fieldCols = c("altitude", "grounded", "temperature"),
                           timeCol = '_time')
  }
  expect_error(f(), "'x' must be data.frame", fixed = TRUE)
})

test_that("toLineProtocol / NULL precision", {
  data <- .data.pivoted
  f <- function () {
    .client$toLineProtocol(data, precision = NULL,
                           measurementCol = 'no-measurement',
                           tagCols = c("region", "sensor_id"),
                           fieldCols = c("altitude", "grounded", "temperature"),
                           timeCol = '_time')
  }
  expect_error(f(), "'precision' cannot be NULL", fixed = TRUE)
})

test_that("toLineProtocol / invalid precision", {
  data <- .data.pivoted
  f <- function () {
    .client$toLineProtocol(data, precision = 'xs',
                           measurementCol = 'no-measurement',
                           tagCols = c("region", "sensor_id"),
                           fieldCols = c("altitude", "grounded", "temperature"),
                           timeCol = '_time')
  }
  expect_error(f(), "'arg' should be one of .*") # regexp due to some issue with R CMD check
})

test_that("toLineProtocol / not existing measurement column", {
  data <- .data.pivoted
  f <- function () {
    .client$toLineProtocol(data, precision = 'ns',
                           measurementCol = 'no-measurement',
                           tagCols = c("region", "sensor_id"),
                           fieldCols = c("altitude", "grounded", "temperature"),
                           timeCol = '_time')
  }
  expect_error(f(), "measurement column 'no-measurement' not found in data frame",
               fixed = TRUE)
})

test_that("toLineProtocol / not existing tag columns", {
  data <- .data.pivoted
  f <- function () {
    .client$toLineProtocol(data, precision = 'ns',
                           measurementCol = '_measurement',
                           tagCols = c("region", "sensor_id", "no-1", "no-2"),
                           fieldCols = c("altitude", "grounded", "temperature"),
                           timeCol = '_time')
  }
  expect_error(f(), "tag columns not found in data frame: no-1,no-2",
               fixed = TRUE)
})

test_that("toLineProtocol / not existing field columns", {
  data <- .data.pivoted
  f <- function () {
    .client$toLineProtocol(data, precision = 'ns',
                           measurementCol = '_measurement',
                           tagCols = c("region", "sensor_id"),
                           fieldCols = c("altitude", "no-1", "no-2"),
                           timeCol = '_time')
  }
  expect_error(f(), "field columns not found in data frame: no-1,no-2",
               fixed = TRUE)
})

test_that("toLineProtocol / measurementCol is not single column", {
  data <- .data.pivoted
  f <- function () {
    .client$toLineProtocol(data, precision = 'ns',
                           measurementCol = c("a", "b"),
                           tagCols = c("region", "sensor_id"),
                           fieldCols = c("altitude", "grounded", "temperature"),
                           timeCol = '_time')
  }
  expect_error(f(), "'measurementCol' must select single column",
               fixed = TRUE)
})

test_that("toLineProtocol / fieldCols is not single column", {
  data <- .data.pivoted
  f <- function () {
    .client$toLineProtocol(data, precision = 'ns',
                           measurementCol = '_measureement',
                           tagCols = c("region", "sensor_id"),
                           fieldCols = NULL,
                           timeCol = '_time')
  }
  expect_error(f(), "'fieldCols' cannot be empty", fixed = TRUE)
})

test_that("toLineProtocol / time column is not single column", {
  data <- .data.pivoted
  f <- function () {
    .client$toLineProtocol(data, precision = 'ns',
                           measurementCol = '_measurement',
                           tagCols = c("region", "sensor_id"),
                           fieldCols = c("altitude", "grounded", "temperature"),
                           timeCol = NULL)
  }
  expect_error(f(), "'timeCol' must select single column", fixed = TRUE)
})

test_that("toLineProtocol / not existing time column", {
  data <- .data.pivoted
  f <- function () {
    .client$toLineProtocol(data, precision = 'ns',
                           measurementCol = '_measurement',
                           tagCols = c("region", "sensor_id"),
                           fieldCols = c("altitude", "grounded", "temperature"),
                           timeCol = 'no-time')
  }
  expect_error(f(), "time column 'no-time' not found in data frame",
               fixed = TRUE)
})

test_that("delay / max time capped", {
  .api.client <- InfluxDBApiClientTest$new()
  opts <- RetryOptions$new(maxDelay = 100, maxAttempts = 10)
  delays <- c()
  for (i in 1:10) {
    delays <- c(delays, .api.client$delay(retryOptions = opts, attempt = i,
                                          retryAfter = NULL, deadline = NULL))
  }
  expect_true(all(diff(delays) >= 0))
  expect_true(all(delays <= 100))
})

test_that("delay / retry-after jitter", {
  .api.client <- InfluxDBApiClientTest$new()
  opts <- RetryOptions$new(retryJitter = 250, maxAttempts = 10)
  delays <- c()
  for (i in 1:10) {
    delays <- c(delays, .api.client$delay(retryOptions = opts, attempt = i,
                                          retryAfter = 3, deadline = NULL))
  }
  expect_true(all(delays >= 3 & delays <= 3.250))
})
