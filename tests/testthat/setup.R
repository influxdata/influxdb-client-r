library(testthat)
library(httptest)

test.url <- 'http://localhost:8086'
test.token <- 'DcvGNmM_fyYW0sqcSlVyllcR90MITaTKge19P3iDJvnPmCdF2vnwiL888bocS4bmIDb8Tc2fBZQfdiegB5UFDw=='
test.org <- 'bonitoo'
test.client <- InfluxDBClient$new(url = test.url, token = test.token, org = test.org)

.airSensors.time = c(
  as.nanotime(1623232361000000000),
  as.nanotime(1623232371000000000),
  as.nanotime(1623232381000000000),
  as.nanotime(1623232391000000000),
  as.nanotime(1623232401000000000)
)

test.airSensors.data = list(
  data.frame(
    `_time` = .airSensors.time,
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
    `_time` = .airSensors.time,
    `_value` = c(FALSE, FALSE, TRUE, TRUE, FALSE),
    `_field` = replicate(5, 'grounded'),
    `_measurement` = replicate(5, 'airSensors'),
    region = replicate(5, 'south'),
    sensor_id = replicate(5, 'TLM0101'),
    check.names = FALSE
  ),
  data.frame(
    `_time` = .airSensors.time,
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
    `_time` = .airSensors.time,
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
