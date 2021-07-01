.client = test.client

with_mock_api({
  test_that("health", {
    response <- .client$health()
    expected <- list("name"="influxdb",
                     "message"="ready for queries and writes",
                     "status"="pass",
                     "version"="dev",
                     "commit"="7bde3413b3")
    expect_equal(response, expected)
  })
})
