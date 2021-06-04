context("Testing query context")

test_that("testing query", {
  print('TEST!!!')
  client <- InfluxDBClient$new(url="http://localhost:8086",
                               token = "NoY1Uie5rIoWEkJ263N8nf-A4Oc-A3ApPWMqcNO1xiQDmu4jChLJIwvVG826bWWsNGpbfCgPaj6MO2LPynUAbw==",
                               org="bonitoo")
  response <- client$query(text = 'from(bucket: \\"my-bucket\\") |> range(start: -100y) |> limit(n: 10) |> drop(columns: [\\"_start\\", \\"_stop\\"])')
  print(response)
})
