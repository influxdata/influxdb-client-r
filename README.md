# influxdb-client-r

**DISCLAIMER: THIS IS A WORK IN PROGRESS**

This repository contains R client package for InfluxDB 2.0.

* [Features](#features)
* [Installation](#installation)
  * [Installing R dependencies](#installing-r-dependencies)
  * [Installing `influxdbclient` package](#installing-influxdbclient-package)
* [Usage](#usage)
  * [Client instantiation](#client-instantiation)
  * [Querying data](#querying-data)
  * [Health checking](#health-checking)
* [License](#license)

## Features

InfluxDB 2.0 Client supports:

- Querying data
- Writing data
- Health check

### Known Issues

- [write / line protocol] string value fields are not supported yet
- [write / line protocol] special character escaping is not implemented yet (https://docs.influxdata.com/influxdb/cloud/reference/syntax/line-protocol/#special-characters)
- [query] double quotes in Flux query text must be escaped manually

## Installation

### Installing R dependencies  

Install required dependencies with

```r
install.packages(c("httr", "jsonlite", "base64enc", "bit64", "nanotime", "plyr"))
```

### Installing `influxdbclient` package  

Install the latest version of `influxdbclient` package with

```r
remotes::install_github("bonitoo-io/influxdb-client-r")
```

## Usage

### Client instantiation

```r
client <- InfluxDBClient$new(url = 'http://localhost:8086',
                             token = 'my-token',
                             org = 'my-org')
```

#### Parameters

| Parameter | Description | Type | Default |
|---|---|---|---|
| `url` | InfluxDB instance URL | `character` | none |
| `token` | Authentication token | `character` | none |
| `org` | Organization name | `character` | none |

### Querying data

```r
client <- InfluxDBClient$new(url = 'http://localhost:8086',
                             token = 'my-token',
                             org = 'my-org')
                            
data <- client$query(text='from(bucket: \\"my-bucket\\") |> range(start: -1h) |> drop(columns: [\\"_start\\", \\"_stop\\"])')
```

Response is a `list` of `data.frame`s.

#### Parameters

| Parameter | Description | Type | Default |
|---|---|---|---|
| `text` | Flux query | `character` | none |

#### Use retrieved data as time series

Flux timestamps are parsed into `nanotime` (`integer64` underneath) type, because
R datetime types do not support nanosecond precision. `nanotime` is not
a time-based object appropriate for creating a time series, though.
To add such column to the data, just coerce the time column (usually `_time`), like
```r
data$tstime <- as.POSIXct(data$`_time`)
```
Then, time series can be created from the data, eg. using `tsbox` package:
```r
ts_ts(xts(data, order.by = data$tstime))
```

### Writing data

```r
client <- InfluxDBClient$new(url = 'http://localhost:8086',
                             token = 'my-token',
                             org = 'my-org')

response <- client$write(data, bucket = 'my-bucket', precision = 'us',
                         tagCols = c("location", "node"))
```

#### Parameters

| Parameter | Description | Type | Default |
|---|---|---|---|
| `data` | Data  | `data.frame` | none |
| `bucket` | Target bucket name | `character` | none |
| `precision` | Timestamp precision | `character` (one of `s`, `ms`, `us`, `ns`) | none |
| `measurementCol` | Measurement column name | `character` | `'_measurement'` |
| `tagCols` | Tag column name(s) | `character` | `NULL` |
| `fieldCols` | Field column name(s) | `character` | `c("_field"="_value")` |
| `timeCol` | Time column name | `character` | `'_time'` |

Note: default `fieldCols` are suitable for writing unpivoted data retrieved from 
InfluxDB before. For usual tables ("pivoted"), `fieldCols` should be unnamed list, eg.
`c("humidity", "temperature", ...)`.

Response is an instance of `ApiResponse` in case of error, otherwise `NULL`.

### Health checking

```r
client <- InfluxDBClient$new(url = 'http://localhost:8086',
                             token = 'my-token',
                             org = 'my-org')
                            
check <- client$health()
```

Response is either instance of `HealthCheck` or error.

## License

The client is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
