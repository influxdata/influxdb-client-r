.client = test.client

with_mock_api({
  test_that("health", {
    response <- .client$health()
    expect_equal(class(response), c('HealthCheck', 'R6'))
  })
})
