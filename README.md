# influxdb-client-r
[![CircleCI](https://circleci.com/gh/influxdata/influxdb-client-r.svg?style=svg)](https://app.circleci.com/pipelines/github/influxdata/influxdb-client-r)
[![codecov](https://codecov.io/gh/influxdata/influxdb-client-r/branch/master/graph/badge.svg)](https://app.codecov.io/gh/influxdata/influxdb-client-r)

This repository contains R package for InfluxDB 2.0 client.

* [Features](#features)
* [Installing](#installing)
  * [Installing dependencies](#installing-dependencies)
  * [Installing `influxdbclient` package](#installing-influxdbclient-package)
* [Usage](#usage)
  * [Client instantiation](#client-instantiation)
  * [Querying data](#querying-data)
    * [Type mapping](#incoming-type-mapping)
    * [Time series](#using-retrieved-data-as-time-series)
  * [Writing data](#writing-data)
    * [Type mapping](#outgoing-type-mapping)
    * [Output preview](#output-preview)
    * [Write retrying](#write-retrying)
  * [Getting status](#getting-status)
    * [Health](#health-status)
    * [Readiness](#readiness-status)
  * [Advanced](#advanced)
* [Known Issues](#known-issues)
* [Contributing](#contributing)
* [License](#license)

## Features

The InfluxDB 2.0 client supports:

- Querying data
- Writing data
- Getting status

## Documentation

This section contains links to the client library documentation.

* [Product documentation](https://docs.influxdata.com/influxdb/v2.0/api-guide/client-libraries/)
* [Getting Started](#usage)
* [Examples](#usage)
* [API Reference](https://cran.r-project.org/package=influxdbclient/influxdbclient.pdf)
* [Changelog](https://github.com/influxdata/influxdb-client-r/blob/master/CHANGELOG.md)

## Installing

The package requires R >= 3.4.

### Installing dependencies

```r
install.packages(c("httr", "bit64", "nanotime", "plyr"))
```

### Installing `influxdbclient` package  

The package is published on CRAN and can be installed with

```r
install.packages("influxdbclient")
```

The latest development version can be installed with

```r
# install.packages("remotes")
remotes::install_github("influxdata/influxdb-client-r")
```

## Usage

### Client instantiation

```r
library(influxdbclient)
client <- InfluxDBClient$new(url = "http://localhost:8086",
                             token = "my-token",
                             org = "my-org")
```

**Parameters**

| Parameter | Description | Type | Default |
|---|---|---|---|
| `url` | InfluxDB instance URL | `character` | none |
| `token` | authentication token | `character` | none |
| `org` | organization name | `character` | none |

Hint: to avoid SSL certificate validation errors when accessing InfluxDB instance
over https such as `SSL certificate problem: unable to get local issuer certificate`,
you can try to disable the validation using the following call before using any
`InfluxDBClient` method. _Warning: it will disable peer certificate validation for the current R session._
```r
library(httr)
httr::set_config(config(ssl_verifypeer = FALSE))
```

### Querying data

Use `query` method.

```r
client <- InfluxDBClient$new(url = "http://localhost:8086",
                             token = "my-token",
                             org = "my-org")
                            
data <- client$query('from(bucket: "my-bucket") |> range(start: -1h) |> drop(columns: ["_start", "_stop"])')
data
```

Flux query can [yield](https://docs.influxdata.com/influxdb/v2.0/reference/flux/stdlib/built-in/outputs/yield/) multiple _results_ in one response, where each result may contain multiple tables.  
Return value is therefore a named list, where each element is a list of data frames that represent a _result_. Data frame represents Flux table. You can list the results using `names` method.

Quite often, though, there is just a single result and therefore the `query` by default flattens the return value to simple unnamed list of data frames. This behaviour controlled by `flatSingleResult` parameter. With `flatSingleResult = FALSE`, you can check that the return value contains one element with name `"_result"` (default result name when there is no explicit `yield` in the query) and use the name to retrieve it, like

```
> names(data)
[1] "_result"

> data[["_result"]]
[[1]]
                       time       name region sensor_id altitude grounded temperature
1 2021-06-09T09:52:41+00:00 airSensors  south   TLM0101      549    FALSE  71.7844100
2 2021-06-09T09:52:51+00:00 airSensors  south   TLM0101      547    FALSE  71.7684399
3 2021-06-09T09:53:01+00:00 airSensors  south   TLM0101      563     TRUE  71.7819928
4 2021-06-09T09:53:11+00:00 airSensors  south   TLM0101      560     TRUE  71.7487767
5 2021-06-09T09:53:21+00:00 airSensors  south   TLM0101      544    FALSE  71.7335579
```

**Parameters**

| Parameter | Description | Type | Default |
|---|---|---|---|
| `text` | Flux query | `character` | none |
| `POSIXctCol` | Flux time to `POSIXct` column mapping | named `list` | `c("_time"="time")` |
| `flatSingleResult` | Whether to return simple list when response contains only one result | logical | `TRUE` |

#### Incoming type mapping

| Flux type | R type |
|---|---|
| `string` | `character` |
| `int` | `integer64` |
| `float` | `numeric` |
| `bool` | `logical` |
| `time` | `nanotime` |

#### Using retrieved data as time series

Flux timestamps are parsed into `nanotime` (`integer64` underneath) type, because
R datetime types do not support nanosecond precision. `nanotime` is not
a time-based object appropriate for creating a time series, though. By default,
`query` coerces the `_time` column to `time` column of `POSIXct` type (see `POSIXctCol`
parameter), with possible loss precision (which is unimportant in the context of R time series).

Select data of interest from the result like
```r
# from the first data frame, pick subset containing `time` and `_value` columns only
df1 <- data[[1]][c("time", "_value")]
```

Then, a time series object can be created from the data frame, eg. using `tsbox` package:
```r
ts1 <- ts_ts(ts_df(df1))
```

A data frame, or a time series object created from it, can be used for decomposition,
anomaly detection etc, like
```r
df1$`_value` %>% ts(freq=168) %>% stl(s.window=13) %>% autoplot()
```
or
```r
ts1 %>% ts(freq=168) %>% stl(s.window=13) %>% autoplot()
```

#### Querying metadata

For queries returning records without time info (listing buckets, tag values etc.), set `POSIXctCol` to `NULL`.

```r
buckets <- client$query('buckets()', POSIXctCol = NULL)
```

### Writing data

Use `write` method.

```r
client <- InfluxDBClient$new(url = "http://localhost:8086",
                             token = "my-token",
                             org = "my-org")
data <- ...
response <- client$write(data, bucket = "my-bucket", precision = "us",
                         measurementCol = "name",
                         tagCols = c("region", "sensor_id"),
                         fieldCols = c("altitude", "temperature"),
                         timeCol = "time")
```

The example is valid for `data.frame` `data` like the following:
```
> print(data)
                       time       name region sensor_id altitude grounded temperature
1 2021-06-09T09:52:41+00:00 airSensors  south   TLM0101      549    FALSE  71.7844100
2 2021-06-09T09:52:51+00:00 airSensors  south   TLM0101      547    FALSE  71.7684399
3 2021-06-09T09:53:01+00:00 airSensors  south   TLM0101      563     TRUE  71.7819928
4 2021-06-09T09:53:11+00:00 airSensors  south   TLM0101      560     TRUE  71.7487767
5 2021-06-09T09:53:21+00:00 airSensors  south   TLM0101      544    FALSE  71.7335579

> str(data)
'data.frame':	5 obs. of  7 variables:
 $ time       :integer64 1623232361000000000 1623232371000000000 1623232381000000000 1623232391000000000 1623232401000000000
 $ name       : chr  "airSensors" "airSensors" "airSensors" "airSensors" ...
 $ region     : chr  "south" "south" "south" "south" ...
 $ sensor_id  : chr  "TLM0101" "TLM0101" "TLM0101" "TLM0101" ...
 $ altitude   :integer64 549 547 563 560 544
 $ grounded   : logi  FALSE FALSE TRUE TRUE FALSE
 $ temperature: num  71.8 71.8 71.8 71.7 71.7
```

**Parameters**

| Parameter | Description | Type | Default |
|---|---|---|---|
| `x` | data  | `data.frame` (or list of) | none |
| `bucket` | target bucket name | `character` | none |
| `batchSize` | batch size | `numeric` | `5000` |
| `precision` | timestamp precision | `character` (one of `s`, `ms`, `us`, `ns`) | none |
| `measurementCol` | measurement column name | `character` | `"_measurement"` |
| `tagCols` | tags column names | `character` | `NULL` |
| `fieldCols` | fields column names | `character` | `c("_field"="_value")` |
| `timeCol` | time column name | `character` | `"_time"` |
| `object` | output object | `character` | `NULL` |

Supported time column value types: `nanotime`, `POSIXct`.

Response is either `NULL` on success, or errorr otherwise.

Note: default `fieldCols` value is suitable for writing back unpivoted data retrieved
from  InfluxDB before. For usual tables ("pivoted" in Flux world), `fieldCols` should be
unnamed list, eg. `c("humidity", "temperature", ...)`.

#### Outgoing type mapping

| R type | InfluxDB type |
|---|---|
| `character` | `string` |
| `integer`, `integer64` | `int` |
| `numeric` | `float` |
| `logical` | `bool` |
| `nanotime`, `POSIXct` | `time` |

#### Output preview

To preview how input data are serialized to InfluxDB [line protocol](https://docs.influxdata.com/influxdb/cloud/reference/syntax/line-protocol/),
pass the name of object to receive the output as `object` parameter value.  
It changes `write` to dry-run operation (nothing is sent to the database).
The object will be assigned to the calling environment.  
_This option is intended for debugging purposes._

```r
data <- ...
response <- client$write(data, bucket = "my-bucket", precision = "us",
                         measurementCol = "name",
                         tagCols = c("region", "sensor_id"),
                         fieldCols = c("altitude", "temperature"),
                         timeCol = "time",
                         object = "lp")
lp
```
Sample output:
```r
> print(lp)
[[1]]
[1] "airSensors,region=south,sensor_id=TLM0101 altitude=549i,temperature=71.7844100 1623232361000000"
[2] "airSensors,region=south,sensor_id=TLM0101 altitude=547i,temperature=71.7684399 1623232371000000"
[3] "airSensors,region=south,sensor_id=TLM0101 altitude=563i,temperature=71.7819928 1623232381000000"
[4] "airSensors,region=south,sensor_id=TLM0101 altitude=560i,temperature=71.7487767 1623232391000000"
[5] "airSensors,region=south,sensor_id=TLM0101 altitude=544i,temperature=71.7335579 1623232401000000"
```

#### Write retrying

By default, client will *not* retry failed writes. To instantiate a client with retry
support, pass an instance of `RetryOptions`, eg:
```r
client <- InfluxDBClient$new(url = "http://localhost:8086",
                             token = "my-token",
                             org = "my-org",
                             retryOptions = RetryOptions$new(maxAttempts = 3))
```
For retry strategy with default options just pass `TRUE` as `retryOptions` parameter
value:
```r
client <- InfluxDBClient$new(url = "http://localhost:8086",
                             token = "my-token",
                             org = "my-org",
                             retryOptions = TRUE)
```

Retryable InfluxDB write errors are `429` and `503` status codes.
The retry strategy implements exponential backoff algorithm, customizable with
`RetryOptions`.

### Getting status

#### Health status

Use `health` method to get the health status.

```r
client <- InfluxDBClient$new(url = "http://localhost:8086",
                             token = "my-token",
                             org = "my-org")

check <- client$health()
```

Response is list with health information elements (`name`, `status`, `version`,
`commit`) or error.

#### Readiness status

Use `ready` method to get the readiness status.

```r
client <- InfluxDBClient$new(url = "http://localhost:8086",
                             token = "my-token",
                             org = "my-org")

check <- client$ready()
```

Response is a list with status elements (`status`, `started`, `up`) or error.

#### Advanced

The client automatically follows HTTP redirects.

To use the client with proxy, use `set_config` to configure the proxy:

```r
library(httr)
httr::set_config(
  use_proxy(url = "my-proxy", port = 8080, username = "user",password = "password")
)
```

## Known Issues

## Contributing

Contributions are most welcome. The fastest way to get something fixed is to open a PR.

## License

The client is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
