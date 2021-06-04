context("Testing health context")

test_that("testing health", {
  print('TEST!!!')
  client <- InfluxDBClient$new(url="http://localhost:8086",
                               token = "NoY1Uie5rIoWEkJ263N8nf-A4Oc-A3ApPWMqcNO1xiQDmu4jChLJIwvVG826bWWsNGpbfCgPaj6MO2LPynUAbw==",
                               org="bonitoo")
  response <- client$health()
  print(response)
})
