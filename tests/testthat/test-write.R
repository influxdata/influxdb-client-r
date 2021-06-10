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

  test_that("write pivoted", {
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
})
