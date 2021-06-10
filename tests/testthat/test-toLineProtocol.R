.client = test.client
.data = test.airSensors.data
.data.pivoted = test.airSensors.data.pivoted
.lp = list(
  c(
  "w-airSensors,region=south,sensor_id=TLM0101 altitude=549 1623232361000000000",
  "w-airSensors,region=south,sensor_id=TLM0101 altitude=547 1623232371000000000",
  "w-airSensors,region=south,sensor_id=TLM0101 altitude=563 1623232381000000000",
  "w-airSensors,region=south,sensor_id=TLM0101 altitude=560 1623232391000000000",
  "w-airSensors,region=south,sensor_id=TLM0101 altitude=544 1623232401000000000"
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
    "w-airSensors,region=south,sensor_id=TLM0101 altitude=549,grounded=false,temperature=71.78441 1623232361000000000",
    "w-airSensors,region=south,sensor_id=TLM0101 altitude=547,grounded=false,temperature=71.7684399 1623232371000000000",
    "w-airSensors,region=south,sensor_id=TLM0101 altitude=563,grounded=true,temperature=71.7819928 1623232381000000000",
    "w-airSensors,region=south,sensor_id=TLM0101 altitude=560,grounded=true,temperature=71.7487767 1623232391000000000",
    "w-airSensors,region=south,sensor_id=TLM0101 altitude=544,grounded=false,temperature=71.7335579 1623232401000000000"
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

test_that("toLineProtocol pivoted", {
  # rename some columns in order to test non-default parameters
  # change measurement value to avoid overwriting source
  data <- lapply(.data.pivoted,
                 function(t) {
                   colnames(t)[which(names(t) == '_time')] <- 'time'
                   colnames(t)[which(names(t) == '_measurement')] <- 'name'
                   t['name'] <- replicate(5, 'w-airSensors')
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
