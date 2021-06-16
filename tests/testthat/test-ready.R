.client = test.client

with_mock_api({
  test_that("ready", {
    response <- .client$ready()
    expect_equal(class(response), c('Ready', 'R6'))
  })
})
