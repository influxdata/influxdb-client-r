library(testthat)
library(httptest)

# helper for testing private methods of InfluxDBClient
InfluxDBClientTest <- R6::R6Class(
  inherit = InfluxDBClient,
  public = list(
    fromAnnotatedCsv = function(x) {
      self$.fromAnnotatedCsv(x)
    },
    toLineProtocol = function(x,
                              precision,
                              measurementCol,
                              tagCols,
                              fieldCols,
                              timeCol) {
      private$.toLineProtocol(x,
                              precision,
                              measurementCol,
                              tagCols,
                              fieldCols,
                              timeCol)
    }
  )
)

test.url <- 'http://localhost:8086'
test.token <- 'DcvGNmM_fyYW0sqcSlVyllcR90MITaTKge19P3iDJvnPmCdF2vnwiL888bocS4bmIDb8Tc2fBZQfdiegB5UFDw=='
test.org <- 'bonitoo'
test.client <- InfluxDBClientTest$new(url = test.url, token = test.token, org = test.org)

.airSensors.time5 = c(
  as.nanotime(1623232361000000000),
  as.nanotime(1623232371000000000),
  as.nanotime(1623232381000000000),
  as.nanotime(1623232391000000000),
  as.nanotime(1623232401000000000)
)

test.airSensors.data = list(
  data.frame(
    `_time` = .airSensors.time5,
    `_value` = c(
      as.integer64(549),
      as.integer64(547),
      as.integer64(563),
      as.integer64(560),
      as.integer64(544)
    ),
    `_field` = replicate(5, 'altitude'),
    `_measurement` = replicate(5, 'airSensors'),
    region = replicate(5, 'south'),
    sensor_id = replicate(5, 'TLM0101'),
    check.names = FALSE
  ),
  data.frame(
    `_time` = .airSensors.time5,
    `_value` = c(FALSE, FALSE, TRUE, TRUE, FALSE),
    `_field` = replicate(5, 'grounded'),
    `_measurement` = replicate(5, 'airSensors'),
    region = replicate(5, 'south'),
    sensor_id = replicate(5, 'TLM0101'),
    check.names = FALSE
  ),
  data.frame(
    `_time` = .airSensors.time5,
    `_value` = c(71.7844100, 71.7684399, 71.7819928, 71.7487767, 71.7335579),
    `_field` = replicate(5, 'temperature'),
    `_measurement` = replicate(5, 'airSensors'),
    region = replicate(5, 'south'),
    sensor_id = replicate(5, 'TLM0101'),
    check.names = FALSE
  )
)

test.airSensors.data.pivoted = list(
  data.frame(
    `_time` = .airSensors.time5,
    `_measurement` = replicate(5, 'airSensors'),
    region = replicate(5, 'south'),
    sensor_id = replicate(5, 'TLM0101'),
    altitude = c(
      as.integer64(549),
      as.integer64(547),
      as.integer64(563),
      as.integer64(560),
      as.integer64(544)
    ),
    grounded = c(FALSE, FALSE, TRUE, TRUE, FALSE),
    temperature = c(71.7844100, 71.7684399, 71.7819928, 71.7487767, 71.7335579),
    check.names = FALSE
  )
)

.airSensors.time3 = head(.airSensors.time5, 3)

test.airSensors.data.multi = list(
  data.frame(
    `_time` = .airSensors.time3,
    `_value` = c(
      as.integer64(549),
      as.integer64(547),
      as.integer64(563)
    ),
    `_field` = replicate(3, 'altitude'),
    `_measurement` = replicate(3, 'airSensors'),
    region = replicate(3, 'south'),
    sensor_id = replicate(3, 'TLM0101'),
    check.names = FALSE
  ),
  data.frame(
    `_time` = .airSensors.time3,
    `_value` = c(
      as.integer64(549),
      as.integer64(538),
      as.integer64(554)
    ),
    `_field` = replicate(3, 'altitude'),
    `_measurement` = replicate(3, 'airSensors'),
    region = replicate(3, 'south'),
    sensor_id = replicate(3, 'TLM0102'),
    check.names = FALSE
  ),
  data.frame(
    `_time` = .airSensors.time3,
    `_value` = c(71.7844100, 71.7684399, 71.7819928),
    `_field` = replicate(3, 'temperature'),
    `_measurement` = replicate(3, 'airSensors'),
    region = replicate(3, 'south'),
    sensor_id = replicate(3, 'TLM0101'),
    check.names = FALSE
  ),
  data.frame(
    `_time` = .airSensors.time3,
    `_value` = c(71.9616430, 71.9217034, 71.9037406),
    `_field` = replicate(3, 'temperature'),
    `_measurement` = replicate(3, 'airSensors'),
    region = replicate(3, 'south'),
    sensor_id = replicate(3, 'TLM0102'),
    check.names = FALSE
  )
)
