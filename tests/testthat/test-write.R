.client = test.client
.data = test.airSensors.data
.data.pivoted = test.airSensors.data.pivoted
.lp.pivoted = list(
  c(
    "w-airSensors,region=south,sensor_id=TLM0101 altitude=549i,grounded=false,temperature=71.78441,q=42i 1623232361000000000",
    "w-airSensors,region=south,sensor_id=TLM0101 altitude=547i,grounded=false,temperature=71.7684399,q=42i 1623232371000000000",
    "w-airSensors,region=south,sensor_id=TLM0101 altitude=563i,grounded=true,temperature=71.7819928,q=42i 1623232381000000000",
    "w-airSensors,region=south,sensor_id=TLM0101 altitude=560i,grounded=true,temperature=71.7487767,q=42i 1623232391000000000",
    "w-airSensors,region=south,sensor_id=TLM0101 altitude=544i,grounded=false,temperature=71.7335579,q=42i 1623232401000000000"
  )
)

with_mock_api({
  test_that("write", {
    # change measurement value to avoid overwriting source
    data <- lapply(.data,
                   function(t) {
                     t['_measurement'] <- replicate(5, 'w-airSensors')
                     return(t)
                   })
    response <- .client$write(data, bucket = 'r-testing', precision = 'ns',
                              tagCols = c("region", "sensor_id"))
                              # measurementCol = '_measurement', # default
                              # fieldCols = c("_field"="_value"), # default
                              # timeCol = '_time' # default
    expect_null(response)
  })

  test_that("write / pivoted", {
    # rename some columns in order to test non-default parameters
    # change measurement value to avoid overwriting source
    data <- lapply(.data.pivoted,
                   function(t) {
                     colnames(t)[which(names(t) == '_time')] <- 'time'
                     colnames(t)[which(names(t) == '_measurement')] <- 'name'
                     t['name'] <- replicate(5, 'w-airSensors')
                     return(t)
                   })
    response <- .client$write(data, bucket='r-testing', precision = 'ns',
                              measurementCol = 'name',
                              tagCols = c("region", "sensor_id"),
                              fieldCols = c("altitude", "grounded", "temperature"),
                              timeCol = 'time')
    expect_null(response)
  })

  test_that("write / non-default batching", {
    # rename some columns in order to test non-default parameters
    # change measurement value to avoid overwriting source
    data <- lapply(.data.pivoted,
                   function(t) {
                     colnames(t)[which(names(t) == '_time')] <- 'time'
                     colnames(t)[which(names(t) == '_measurement')] <- 'name'
                     t['name'] <- replicate(5, 'w-airSensors')
                     return(t)
                   })
    response <- .client$write(data, bucket='r-testing',
                              batchSize = 3, # input has 5 lines -> 2 batches (3 and 2 liners)
                              precision = 'ns',
                              measurementCol = 'name',
                              tagCols = c("region", "sensor_id"),
                              fieldCols = c("altitude", "grounded", "temperature"),
                              timeCol = 'time')
    expect_null(response)
  })

  test_that("write / disabled batching", {
    # rename some columns in order to test non-default parameters
    # change measurement value to avoid overwriting source
    data <- lapply(.data.pivoted,
                   function(t) {
                     colnames(t)[which(names(t) == '_time')] <- 'time'
                     colnames(t)[which(names(t) == '_measurement')] <- 'name'
                     t['name'] <- replicate(5, 'w-airSensors')
                     return(t)
                   })
    response <- .client$write(data, bucket='r-testing',
                              batchSize = FALSE,
                              precision = 'ns',
                              measurementCol = 'name',
                              tagCols = c("region", "sensor_id"),
                              fieldCols = c("altitude", "grounded", "temperature"),
                              timeCol = 'time')
    expect_null(response)
  })

  test_that("write / NULL bucket", {
    # change measurement value to avoid overwriting source
    data <- lapply(.data,
                   function(t) {
                     t['_measurement'] <- replicate(5, 'w-airSensors')
                     return(t)
                   })
    f = function() {
      .client$write(data, bucket = NULL, precision = 'ns',
                    tagCols = c("region", "sensor_id"))
    }
    expect_error(f(), "'bucket' cannot be NULL", fixed = TRUE)
  })

  test_that("write / non-existent bucket", {
    # change measurement value to avoid overwriting source
    data <- lapply(.data,
                   function(t) {
                     t['_measurement'] <- replicate(5, 'w-airSensors')
                     return(t)
                   })
    # mock response: write-00506d-dfdd53-POST.R
    f = function() {
      .client$write(data, bucket = "no-bucket", precision = 'ns')
    }
    expect_error(f(), 'API client error (404): bucket "no-bucket" not found', fixed = TRUE)
  })

  test_that("write / retry", { # just tests successful write via reply code path
    # change measurement value to avoid overwriting source
    data <- lapply(.data,
                   function(t) {
                     t['_measurement'] <- replicate(5, 'w-airSensors')
                     return(t)
                   })
    retry.client <- InfluxDBClient$new(url = test.url, token = test.token, org = test.org,
                                       retryOptions = TRUE)
    response <- retry.client$write(data, bucket = 'r-testing', precision = 'ns',
                                   tagCols = c("region", "sensor_id"))
    expect_null(response)
  })

  test_that("write / retry / non-existent bucket", { # tests non-retryable error
    # change measurement value to avoid overwriting source
    data <- lapply(.data,
                   function(t) {
                     t['_measurement'] <- replicate(5, 'w-airSensors')
                     return(t)
                   })
    # mock response: write-00506d-dfdd53-POST.R
    retry.client <- InfluxDBClient$new(url = test.url, token = test.token, org = test.org,
                                       retryOptions = TRUE)
    f = function() {
      retry.client$write(data, bucket = "no-bucket", precision = 'ns')
    }
    expect_error(f(), 'API client error (404): bucket "no-bucket" not found', fixed = TRUE)
  })

  test_that("write / retry-after / maximum retry attempts reached", {
    # change measurement value to avoid overwriting source
    # add column to have different request than "retry" for different mock response
    data <- lapply(.data,
                   function(t) {
                     t['_measurement'] <- replicate(5, 'w-airSensors')
                     t['retry'] <- replicate(5, 'after')
                     return(t)
                   })
    # use client with retries enabled
    # mock response has retry-after: 3 (write-2a8272-23f3c6-POST.R)
    retry.retries <- 0
    retry.delays <- NULL
    retry.options <- RetryOptions$new(maxAttempts = 3,
                                      onRetry = function(resp, delay) {
                                        retry.retries <<- retry.retries + 1
                                        retry.delays <<- c(retry.delays, delay)
                                        FALSE
                                      })
    retry.client <- InfluxDBClient$new(url = test.url, token = test.token, org = test.org,
                                       retryOptions = retry.options)

    f = function() {
      retry.client$write(data, bucket = 'r-testing', precision = 'ns',
                         tagCols = c("region", "sensor_id", "retry"))
    }
    tr <- expect_anything(f())
    expect_equal(retry.retries, 2) # maxAttempts - 1
    expect_equal(retry.delays, replicate(2, 3))
    #expect_true(tr$elapsed > 6 && tr$elapsed < 7)
    expect_equal(tr$warnings, "maximum retry attempts reached", fixed = TRUE)
    expect_equal(tr$errors, "API client error (429): over quota", fixed = TRUE)
  })

  test_that("write / retry-after / maximum retry time exceeded", {
    # change measurement value to avoid overwriting source
    # add column to have different request than "retry" for different mock response
    data <- lapply(.data,
                   function(t) {
                     t['_measurement'] <- replicate(5, 'w-airSensors')
                     t['retry'] <- replicate(5, 'after')
                     return(t)
                   })
    # use client with retries enabled
    # mock response has retry-after: 3 (write-2a8272-23f3c6-POST.R)
    retry.retries <- 0
    retry.delays <- NULL
    retry.options <- RetryOptions$new(maxAttempts = 5,
                                      maxRetryTime = 5,
                                      onRetry = function(x, delay) {
                                        retry.retries <<- retry.retries + 1
                                        retry.delays <<- c(retry.delays, delay)
                                        TRUE
                                      })
    retry.client <- InfluxDBClient$new(url = test.url, token = test.token, org = test.org,
                                       retryOptions = retry.options)

    f = function() {
      retry.client$write(data, bucket = 'r-testing', precision = 'ns',
                         tagCols = c("region", "sensor_id", "retry"))
    }
    tr <- expect_anything(f())
    expect_equal(retry.retries, 2) # maxAttempts - 1
    expect_equal(retry.delays[1], 3)
    expect_true(retry.delays[2] < 3) # max time is 5 so should be less than 3
    #expect_true(tr$elapsed > 5 && tr$elapsed < 6)
    expect_equal(tr$warnings, "maximum retry time exceeded", fixed = TRUE)
    expect_equal(tr$errors, "API client error (429): over quota", fixed = TRUE)
  })

  test_that("write / retry exponential / maximum retry attempts reached", {
    # change measurement value to avoid overwriting source
    # add column to have different request than "retry" for different mock response
    data <- lapply(.data,
                   function(t) {
                     t['_measurement'] <- replicate(5, 'w-airSensors')
                     t['retry'] <- replicate(5, 'exponential')
                     return(t)
                   })
    # use client with retries enabled
    # mock response has no retry-after (write-2a8272-7d97b3-POST.R)
    retry.retries <- 0
    retry.delays <- NULL
    retry.options <- RetryOptions$new(maxAttempts = 5,
                                      onRetry = function(x, delay) {
                                        retry.retries <<- retry.retries + 1
                                        retry.delays <<- c(retry.delays, delay)
                                        FALSE
                                      })
    retry.client <- InfluxDBClient$new(url = test.url, token = test.token, org = test.org,
                                       retryOptions = retry.options)

    f = function() {
      retry.client$write(data, bucket = 'r-testing', precision = 'ns',
                         tagCols = c("region", "sensor_id", "retry"))
    }
    tr <- expect_anything(f())
    expect_equal(retry.retries, 4) # maxAttempts - 1
    expect_true(all(diff(retry.delays) >= 0))
    expect_equal(tr$warnings, "maximum retry attempts reached", fixed = TRUE)
    expect_equal(tr$errors, "API server error (503): temporarily unavailable to accept writes",
                 fixed = TRUE)
    print(retry.delays) # printed for visual inspection :(
  })
})

test_that("write / dry-run", {
  # rename some columns in order to test non-default parameters
  # change measurement value to avoid overwriting source
  # add (R native) integer type column 'q'
  data <- lapply(.data.pivoted,
                 function(t) {
                   colnames(t)[which(names(t) == '_time')] <- 'time'
                   colnames(t)[which(names(t) == '_measurement')] <- 'name'
                   t['name'] <- replicate(5, 'w-airSensors')
                   t['q'] <- replicate(5, 42L)
                   return(t)
                 })
  response <- .client$write(data, bucket='r-testing',
                            batchSize = 3, # input has 5 lines -> 2 batches (3 and 2 liners)
                            precision = 'ns',
                            measurementCol = 'name',
                            tagCols = c("region", "sensor_id"),
                            fieldCols = c("altitude", "grounded", "temperature", "q"),
                            timeCol = 'time',
                            object = "x-output")
  expected <- .lp.pivoted
  # re-chunk by batch size
  expected <- list(expected[[1]][c(1:3)], expected[[1]][c(4:5)])
  expect_equal(`x-output`, expected)
})

test_that("write / invalid dry-run option", {
  data <- data.frame()
  f = function() {
    .client$write(data, bucket='r-testing',
                  precision = 'ns',
                  object = FALSE)
  }
  expect_error(f(), "'object' must be NULL or character", fixed = TRUE)
})

test_that("write / invalid input type", {
  f = function() {
    .client$write(c(1,2,3,4,5), bucket = "my-bucket", batchSize = 0, precision = 'ns')
  }
  expect_error(f(), "'x' must be data.frame or character", fixed = TRUE)
})

test_that("write / invalid batch size", {
  # change measurement value to avoid overwriting source
  data <- lapply(.data,
                 function(t) {
                   t['_measurement'] <- replicate(5, 'w-airSensors')
                   return(t)
                 })
  f = function() {
    .client$write(data, bucket = "my-bucket", batchSize = 0, precision = 'ns')
  }
  expect_error(f(), "'batchSize' must be >= 1 or FALSE", fixed = TRUE)
})
