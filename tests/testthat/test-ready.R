.client = test.client

with_mock_api({
  test_that("ready", {
    response <- .client$ready()
    expected <- list("status"="ready",
                     "started"="2021-04-26T16:25:24.94815056+02:00",
                     "up"="381h21m23.125806563s")
    expect_equal(response, expected)
  })
})
