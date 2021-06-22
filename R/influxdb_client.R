#' InfluxDBClient Class
#'
#' Client for querying from and writing data to InfluxDB 2.0.
#' Uses classes generates from OpenAPI contract.
#'
#' @docType class
#' @title InfluxDBClient
#' @description InfluxDBClient Class
#' @format An \code{R6Class} object
#' @field url Database URL
#' @field token Authentication token
#' @field org Organization name
#' @export
InfluxDBClient <- R6::R6Class(
  'InfluxDBClient',
  public = list(
    # InfluxDB URL
    url = NULL,
    # authentication token
    token = NULL,
    # organization name
    org = NULL,
    # query dialect
    dialect = NULL,
    # constructor
    #' @description Creates instance of \code{InfluxDBClient}.
    #' @param url InfluxDB instance URL
    #' @param token Authetication token
    #' @param org Organization name
    #' @examples
    #'
    #' \dontrun{
    #' client <- InfluxDBClient$new(url = "http://localhost:8086",
    #'                              token = "my-token",
    #'                              org = "my-org")
    #' }
    initialize = function(url = NULL, token = NULL, org = NULL) {
      if (!is.null(url)) {
        self$url <- url
      }

      if (!is.null(token)) {
        self$token <- token
      }

      if (!is.null(org)) {
        self$org <- org
      }

      # dialect
      self$dialect <-
        Dialect$new(header = TRUE,
                    annotations = c("group", "datatype", "default"))
    },

    #' @description Gets the health of the instance.
    #' @return Instance of \code{HealtCheck} or error
    #' @examples
    #'
    #' \dontrun{
    #' client <- InfluxDBClient$new(...)
    #' status <- client$health()
    #' }
    health = function() {
      # call API
      resp <- self$healthApi$GetHealth()

      # handle errors
      private$.throwIfNot2xx(resp)

      resp
    },

    #' @description Queries data in InfluxDB.
    #' @param text Flux query
    #' @param time.mapping Flux time to (new) POSIXct column mapping (named list).
    #' Use `NULL` to skip it.
    #' @return Data as (list of) \code{data.frame}
    #' @examples
    #'
    #' \dontrun{
    #' client <- InfluxDBClient$new(...)
    #' data <- client$query('from(bucket: "my-bucket") |> range(start: -1h) |> drop(columns: ["_start", "_stop"])')
    #' }
    query = function(text, time.mapping = c("_time"="time")) {
      # validate parameters
      if (is.null(text)) {
        stop("'text' cannot be NULL")
      }
      if (!is.null(time.mapping) ) {
        if (length(time.mapping) != 1 || is.null(names(time.mapping)) || any(names(time.mapping) == "")) {
          stop("'time.mapping' must be named list with 1 element")
        }
      }

      # escape double quotes in the query
      text <- gsub("\"", "\\\"", text, fixed = TRUE)

      # create query instance
      q <- Query$new(query = text,
                     dialect = self$dialect,
                     type = "flux")

      # call API
      resp <- self$queryApi$PostQuery(query = q, org = self$org)

      # handle errors
      private$.throwIfNot2xx(resp)

      # process response
      if (resp == "\r\n") {
        message("empty response")
        NULL # TODO return empty list?
      } else {
        result <- private$.fromAnnotatedCsv(resp)
        if (is.null(time.mapping)) {
          result
        } else {
          srcCol <- names(time.mapping)[[1]]
          targetCol <- time.mapping[[1]]
          result <- lapply(result, function(df) {
            if (!srcCol %in% colnames(df)) {
              stop(sprintf("cannot coerce '%s' to '%s': column does not exist",
                           srcCol, targetCol))
            }
            if (targetCol %in% colnames(df)) {
              stop(sprintf("cannot coerce '%s' to '%s': column already exist",
                           srcCol, targetCol))
            }
            df[targetCol] <- as.POSIXct(df[,srcCol])
            df
          })
        }
      }
    },

    #' @description Gets the readiness of the instance.
    #' @return Instance of \code{Ready} or error
    #' @examples
    #'
    #' \dontrun{
    #' client <- InfluxDBClient$new(...)
    #' status <- client$ready()
    #' }
    ready = function() {
      # call API
      resp <- self$readyApi$GetReady()

      # handle errors
      private$.throwIfNot2xx(resp)

      resp
    },

    #' @description Writes data to InfluxDB.
    #' @param x Data as (list of) \code{data.frame}
    #' @param bucket Target bucket name
    #' @param batch.size Batch size
    #' @param precision Time precision
    #' @param measurementCol Name of measurement column
    #' @param tagCols Names of tag (index) columns
    #' @param fieldCols Names of field columns. In case of unpivoted data
    #' previously retrieved from InfluxDB, use default value ie. named list
    #' \code{c("_field"="_value")}.
    #' For all other cases, just use simple vector of column names (see Examples).
    #' @param timestampCol Name of time column. The column values should be either
    #' of \code{nanotime} or \code{POSIXct} type.
    #' @examples
    #'
    #' \dontrun{
    #' data <- data.frame(...)
    #' client <- InfluxDBClient$new(...)
    #' client$write(data,
    #'              bucket = "my-bucket",
    #'              precision = "ms",
    #'              measurementCol = "name",
    #'              tagCols = c("location", "id"),
    #'              fieldCols = c("altitude", "temperature"),
    #'              timeCol = "time")
    #' }
    write = function(x, bucket,
                     batch.size = 5000,
                     precision = c("ns", "us", "ms", "s"),
                     measurementCol = '_measurement',
                     tagCols = NULL,
                     fieldCols = c("_field"="_value"),
                     timeCol = "_time",
                     ...) {
      # validate parameters
      xIsCharacter <- all(lapply(x, class) == "character")
      xIsDataFrame <- all(lapply(x, class) == "data.frame")
      if (!(xIsCharacter | xIsDataFrame)) {
        stop("'x' must be data.frame or character")
      }
      if (is.null(bucket)) {
        stop("'bucket' cannot be NULL")
      }

      # serialize input into line protocol
      clazz <- if (xIsCharacter) "character" else if (xIsDataFrame) "data.frame"
      lp <- switch(
        clazz,
        "character"= { x },
        "data.frame"= {
          private$.toLineProtocol(x, precision,
                                  measurementCol, tagCols, fieldCols, timeCol)
        },
        stop(paste("Unsupported type for write:", clazz))
      )

      # reusable send
      send <- function(body) {
        # call API
        resp <- self$writeApi$PostWrite(org = self$org,
                                        bucket = bucket,
                                        body = body,
                                        content.type = "text/plain; charset=utf-8",
                                        precision = precision)

        # handle errors
        private$.throwIfNot2xx(resp)
      }

      # re-chunk line protocol data (https://stackoverflow.com/questions/3318333/split-a-vector-into-chunks)
      lp <- unlist(lp)
      n <- ceiling(length(lp) / batch.size)
      if (n > 1) { # >= 2
        batches <- split(lp, cut(seq_along(lp), n, labels = FALSE))
      } else {
        batches <- list(lp)
      }

      # send line protocol data in batches
      for (batch in batches) {
        send(batch)
      }
    }
  ),
  private = list(
    .apiClient = NULL,
    .healthApi = NULL,
    .queryApi = NULL,
    .readyApi = NULL,
    .writeApi = NULL,

    # as.lp.* methods are candidates for public functions

    as.lp.tag = function(x) {
      switch (
        class(x),
        "character"= {
          x <- gsub(",", "\\,", x, fixed = TRUE)
          x <- gsub("=", "\\=", x, fixed = TRUE)
          x <- gsub(" ", "\\ ", x, fixed = TRUE)
        },
        as.character(x)
      )
    },

    as.lp.value = function(x) {
      switch (
        class(x),
        "logical"= tolower(as.character(x)),
        "character" = {
          x <- gsub("\"", "\\\"", x, fixed = TRUE)
          if (grepl(" ", x))
            sprintf("\"%s\"", x)
          else
            x
        },
        "integer" = sprintf("%di", x),
        "integer64" = sprintf("%si", as.character(x)),
        as.character(x)
      )
    },

    as.lp.timestamp = function(x, precision) {
      switch(
        class(x),
        "nanotime"= { private$as.rfc3339nano.timestamp(x, precision = precision) },
        "POSIXct"= { private$as.POSIXct.timestamp(x, precision = precision) },
        stop(paste("unsupported time column type:", class(x)))
      )
    },

    as.rfc3339nano.timestamp = function(nano, precision) {
      n <- as.integer64(nano)
      v <- switch(
        precision,
        "s"=  { n / 1e9 },
        "ms"= { n / 1e6 },
        "us"= { n / 1e3 },
        "ns"= { n },
      )
      as.character(as.integer64(v))
    },

    as.POSIXct.timestamp = function(datetime, precision) {
      n <- as.numeric(datetime)
      v <- switch(
        precision,
        "s"=  { n },
        "ms"= { n * 1e3 },
        "us"= { n * 1e6 },
        "ns"= { n * 1e9 },
      )
      sprintf("%.0f", trunc(v))
    },

    .throwIfNot2xx = function(resp) {
      if (identical(class(resp), c("ApiResponse", "R6"))) {
        errMsg <-
          sprintf(
            "%s (%d): %s",
            resp$content,
            httr::status_code(resp$response),
            httr::content(resp$response)$message
          )
        stop(errMsg)
      }
    },

    .fromAnnotatedCsv = function(x) {
      # split stream by empty line
      csvTables <-
        strsplit(x, split = "\r\n\r\n", useBytes = TRUE)[[1]]

      # result
      tables <- list()

      # parse all CSV tables
      for (csvTable in csvTables) {
        # read datatype annotation line
        datatypes <-
          as.character(read.csv(
            text = csvTable,
            header = FALSE,
            nrows = 3,
            comment.char = ""
          )[2, ])
        message(sprintf("%s ", datatypes))

        # map Flux types to R types
        colClasses <-
          plyr::revalue(
            datatypes,
            c(
              "#datatype" = "NULL",
              "string" = "character",
              "long" = "integer64",
              "boolean" = "logical",
              "dateTime:RFC3339" = "nanotime"
            ),
            warn_missing = FALSE
          )

        # read CSV table into data frame
        df <-
          read.csv(
            text = csvTable,
            header = TRUE,
            skip = 3,
            check.names = FALSE,
            colClasses = colClasses
          )
        df <- df[-1] # skip first column (result name)

        # split data frame by table index column
        dfTables <- split(df, df$table)

        # append tables to result
        mtables <- lapply(dfTables, function (dfTable) {
          rownames(dfTable) <- NULL # reset row names to seq starting at 1
          dfTable[-1] # first column is table index, no longer needed
        })
        tables <- append(tables, mtables)
      }

      unname(tables)
    },

    .toLineProtocol = function(x,
                              precision,
                              measurementCol,
                              tagCols,
                              fieldCols,
                              timeCol) {
      if (!all(lapply(x, class) == "data.frame")) {
        stop("'x' must be data.frame")
      }
      if (is.null(precision)) {
        stop("'precision' cannot be NULL")
      }
      precision <- match.arg(precision, c("ns", "us", "ms", "s"))
      if (length(measurementCol) != 1) {
        stop("'measurementCol' must select single column")
      }
      if (length(tagCols) == 0) {
        message("'tagCols' is empty")
      }
      if (length(fieldCols) == 0) {
        stop("'fieldCols' cannot be empty")
      }
      if (length(timeCol) != 1) {
        stop("'timeCol' must select single column")
      }

      # temporary sanity check
      named <- FALSE
      if (any(names(fieldCols) != "")) {
        if (any(names(fieldCols) == "")) {
          stop("mixed named 'fieldCols' list not supported")
        }
        named <- TRUE
      }

      # vectorize x if necessary
      if (!is.vector(x)) {
        x <- list(x)
      }

      # for all data frames
      buffers <- lapply(x, function(df) {
        # check fo columns presence in data frame
        colNames <- colnames(df)
        if (!(measurementCol %in% colNames)) {
          stop(sprintf("measurement column '%s' not found in data frame",
                       measurementCol))
        }
        if (!all(tagCols %in% colNames)) {
          notFound <- tagCols[!(tagCols %in% colNames)]
          stop(sprintf("tag columns not found in data frame: %s",
                       paste(notFound, sep = "", collapse = ",")))
        }
        if (!all(fieldCols %in% colNames)) {
          notFound <- fieldCols[!(fieldCols %in% colNames)]
          stop(sprintf("field columns not found in data frame: %s",
                       paste(notFound, sep = "", collapse = ",")))
        }
        if (!(timeCol %in% colNames)) {
          stop(sprintf("time column '%s' not found in data frame",
                       timeCol))
        }

        # output buffer
        con <- textConnection("buffer", open = "w", local = TRUE)

        # for all rows in data frame
        for (i in 1:nrow(df)) {
          # get row
          row <- df[i,]

          # retrieve column(s)
          measurement <- row[,measurementCol]
          tags <- row[tagCols]
          fields <- row[fieldCols]
          fieldNames <- if (named) row[names(fieldCols)] else fieldCols
          time <- row[,timeCol]

          # format values for line protocol
          lpMeasurement <- private$as.lp.tag(measurement)
          lpTagSet <- paste(lapply(tagCols, private$as.lp.tag),
                            lapply(tags, private$as.lp.tag),
                            sep = "=", collapse = ",")
          lpFieldSet <- paste(lapply(fieldNames, private$as.lp.tag),
                              lapply(fields, private$as.lp.value),
                              sep = "=", collapse = ",")
          lpTimestamp <- private$as.lp.timestamp(time, precision)

          # construct line
          line <-
            if (length(tagCols) > 0) {
              sprintf("%s,%s %s %s", lpMeasurement, lpTagSet, lpFieldSet, lpTimestamp)
            } else {
              sprintf("%s %s %s", lpMeasurement, lpFieldSet, lpTimestamp)
            }

          # write to buffer
          writeLines(line, con = con)
        }

        # close buffer
        close(con)

        buffer
      })

      buffers
    }

  ),
  active = list(
    apiClient = function(value) {
      if (missing(value)) {
        if (is.null(private$.apiClient)) {
          defaultHeaders <- c()
          defaultHeaders['Authorization'] <- paste0("Token ", self$token)
          private$.apiClient <-
            InfluxDBApiClient$new(basePath = paste0(self$url, "/api/v2"),
                                  defaultHeaders = defaultHeaders)
        }
      } else {
        private$.apiClient <- value
      }
      private$.apiClient
    },

    healthApi = function(value) {
      if (missing(value)) {
        if (is.null(private$.healthApi)) {
          private$.healthApi <- HealthApi$new(self$apiClient)
        }
      } else {
        private$.healthApi <- value
      }
      private$.healthApi
    },

    queryApi = function(value) {
      if (missing(value)) {
        if (is.null(private$.queryApi)) {
          private$.queryApi <- QueryApi$new(self$apiClient)
        }
      } else {
        private$.queryApi <- value
      }
      private$.queryApi
    },

    readyApi = function(value) {
      if (missing(value)) {
        if (is.null(private$.readyApi)) {
          private$.readyApi <- ReadyApi$new(self$apiClient)
        }
      } else {
        private$.readyApi <- value
      }
      private$.readyApi
    },

    writeApi = function(value) {
      if (missing(value)) {
        if (is.null(private$.writeApi)) {
          private$.writeApi <- WriteApi$new(self$apiClient)
        }
      } else {
        private$.writeApi <- value
      }
      private$.writeApi
    }
  )
)
