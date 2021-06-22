.client = test.client
.data = test.airSensors.data
.data.pivoted = test.airSensors.data.pivoted

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
                              batch.size = 3, # input has 5 lines -> 2 batches (3 and 2 liners)
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
                              batch.size = FALSE,
                              precision = 'ns',
                              measurementCol = 'name',
                              tagCols = c("region", "sensor_id"),
                              fieldCols = c("altitude", "grounded", "temperature"),
                              timeCol = 'time')
    expect_null(response)
  })


  test_that("write / NULL bucket", {
    data <- data.frame()
    f = function() {
      .client$write(data, bucket = NULL, precision = 'ns',
                    tagCols = c("region", "sensor_id"))
    }
    expect_error(f(), "'bucket' cannot be NULL", fixed = TRUE)
  })

    test_that("write / non-existent bucket", {
    data <- data.frame()
    f = function() {
      .client$write(data, bucket = "no-bucket", precision = 'ns')
    }
    expect_error(f(), 'API client error (404): bucket "no-bucket" not found', fixed = TRUE)
  })
})
