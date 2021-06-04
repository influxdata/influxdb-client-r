# influxdb-client-r

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

- Querying data using Flux
    - Streaming result to list of `data.frame` 
- Management API 
    - Health check

## Installation

### Installing R dependencies  

Install required packages in **R** using

```r
install.packages(c('devtools', 'httr', 'bit64', 'plyr', 'jsonlite', 'rlist'))
```

### Installing `influxdbclient` package  

Install the latest version of the `influxdbclient` package in **R** using

```r
devtools::install_github("bonitoo-io/influxdbclient")
```

## Usage

### Client instantiation
Specify **url**, **token** and **org** via parameters:

```r
client = InfluxDBClient$new(url = 'http://localhost:8086',
                            token = 'my-token',
                            org = 'my-org')
```

#### Parameters

| Parameter | Description | Type | Default |
|---|---|---|---|
| url | InfluxDB instance URL | String | none |
| token | Authentication token | String | none |
| org | Organization name | String | none |

### Querying data

```r
client = InfluxDBClient$new(url = 'http://localhost:8086',
                            token = 'my-token',
                            org = 'my-org')
                            
data <- client$query(text='from(bucket: \\"my-bucket\\") |> range(start: -1h) |> drop(columns: [\\"_start\\", \\"_stop\\"])')
```

Response is a list of `data.frame`.

#### Parameters

| Parameter | Description | Type | Default |
|---|---|---|---|
| text | Flux query | String | none |

### Health checking

```r
client = InfluxDBClient$new(url = 'http://localhost:8086',
                            token = 'my-token',
                            org = 'my-org')
                            
check <- client$health()
```

Response is either instance of `HealthCheck` or error.

## License

The client is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
