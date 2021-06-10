.client = test.client
.data = test.airSensors.data
.data.pivoted = test.airSensors.data.pivoted
.data.multi = test.airSensors.data.multi

with_mock_api({
  test_that("query", {
    response <- .client$query(text='from(bucket: \\"r-testing\\") |> range(start: -10y) |> filter(fn: (r) => r._measurement == \\"airSensors\\" and r.sensor_id == \\"TLM0101\\") |> limit(n: 5) |> drop(columns: [\\"_start\\", \\"_stop\\"])')
    expected <- .data
    expect_equal(response, expected)
  })

  test_that("query pivoted", {
    response <- .client$query(text='import \\"influxdata/influxdb/schema\\" from(bucket: \\"r-testing\\") |> range(start: -10y) |> filter(fn: (r) => r._measurement == \\"airSensors\\" and r.sensor_id == \\"TLM0101\\") |> schema.fieldsAsCols() |> limit(n: 5) |> drop(columns: [\\"_start\\", \\"_stop\\"])')
    expected <- .data.pivoted
    expect_equal(response, expected)
  })

  test_that("query empty result", {
    response <- .client$query(text='from(bucket: \\"r-testing\\") |> range(start: -10y) |> filter(fn: (r) => r._measurement == \\"doesnotexist\\")')
    expect_null(response)
  })

  test_that("query multiple tables in one csv table", {
    response <- .client$query(text='from(bucket: \\"r-testing\\") |> range(start: -10y) |> filter(fn: (r) => r._measurement == \\"airSensors\\" and (r.sensor_id == \\"TLM0101\\" or r.sensor_id == \\"TLM0102\\") and r._field != \\"grounded\\") |> limit(n: 3) |> drop(columns: [\\"_start\\", \\"_stop\\"])')
    expected <- .data.multi
    expect_equal(response, expected)
  })
})
