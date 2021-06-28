test_that("client / without retryOptions", {
  c1 <- InfluxDBClient$new(url = "http://host:1234", token = "#1234==", org = "org1234")
  c2 <- client(url = "http://host:1234", token = "#1234==", org = "org1234")
  expect_equal(c1, c2)
})

test_that("client / with retryOptions", {
  c1 <- InfluxDBClient$new(url = "http://host:1234", token = "#1234==", org = "org1234",
                           retryOptions = RetryOptions$new(maxAttempts = 10, retryJitter = 250))
  c2 <- client(url = "http://host:1234", token = "#1234==", org = "org1234",
               retryOptions = retry_options(maxAttempts = 10, retryJitter = 250))
  expect_equal(c1, c2)
})
