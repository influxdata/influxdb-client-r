#' @docType class
#' @title InfluxDBClient
#' @description Client for querying from and writing to InfluxDB 2.x.
#' @format An \code{R6Class} object
#' @examples
#' \dontrun{
#' # Instantiation
#' client <- InfluxDBClient$new(url = "http://localhost:8086",
#'                              token = "my-token",
#'                              org = "my-org")
#'
#' # Query
#' data <- client$query('from(bucket: "my-bucket") |> range(start: -1h)')
#'
#' # Write
#' data <- data.frame(...)
#' client$write(data, bucket = "my-bucket", precision = "us",
#'              measurementCol = "name",
#'              tagCols = c("location", "id"),
#'              fieldCols = c("altitude", "temperature"),
#'              timeCol = "time")
#'
#' # Ready status
#' ready <- client$ready()
#'
#' # Healt info
#' ready <- client$health()
#' }
#' @field url Database URL
#' @field token Authentication token
#' @field org Organization name
#' @field dialect Flux dialect
#' @field retryOptions Retry options
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
    # retry options
    retryOptions = NULL,

    #' @description Creates instance of \code{InfluxDBClient}.
    #' @param url InfluxDB instance URL
    #' @param token Authentication token
    #' @param org Organization name
    #' @param org Retry options. See \code{RetryOptions} for details. Set to \code{TRUE}
    #' for default retry options. Default is \code{NULL} which disables retries.
    initialize = function(url, token, org, retryOptions = NULL) {
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

      # retry options
      if (identical(retryOptions, TRUE)) {
        self$retryOptions <- RetryOptions$new()
      } else if (!is.null(retryOptions)) {
        self$retryOptions <- retryOptions
      }
    },

    #' @description Gets health info of the InfluxDB instance.
    #' @return Named list with \code{name}, \code{message}, \code{status},
    #' \code{version}, \code{commit} elements or error
    health = function() {
      # call API
      resp <- self$healthApi$GetHealth()

      # handle errors
      private$.throwIfNot2xx(resp)

      resp$toJSON()
    },

    #' @description Queries data in the InfluxDB instance.
    #' @param text Flux query
    #' @param POSIXctCol Flux time to (new) \code{POSIXct} column mapping (named list).
    #' Default is \code{c("_time"="time")}. Use \code{NULL} to skip it.
    #' @param flatSingleResult Whether to return simple list when response contains
    #' only one result. Default is \code{TRUE}.
    #' @return List of data frames. Data frame represents Flux table.
    #' It can be a named list of nested lists of data frames when query response contains
    #' multiple results (see Flux \href{https://docs.influxdata.com/influxdb/v2.0/reference/flux/stdlib/built-in/outputs/yield/}{yield}),
    #' or a simple list of data frames for single result response.
    query = function(text, POSIXctCol = c("_time"="time"), flatSingleResult = TRUE) {
      # validate parameters
      if (is.null(text)) {
        stop("'text' cannot be NULL")
      }
      if (!is.null(POSIXctCol) ) {
        if (length(POSIXctCol) != 1 || is.null(names(POSIXctCol)) || any(names(POSIXctCol) == "")) {
          stop("'POSIXctCol' must be named list with 1 element")
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
        if (!is.null(POSIXctCol)) {
          srcCol <- names(POSIXctCol)[[1]]
          targetCol <- POSIXctCol[[1]]
          result <- lapply(result, function(sub) {
            lapply(sub, function(df) {
              if (!srcCol %in% colnames(df)) {
                stop(sprintf("cannot coerce '%s' to '%s': column does not exist",
                             srcCol, targetCol))
              }
              if (targetCol %in% colnames(df)) {
                stop(sprintf("cannot coerce '%s' to '%s': column already exist",
                             srcCol, targetCol))
              }
              df[targetCol] <- as.POSIXct(df[,srcCol], tz = "GMT")
              df
            })
          })
        }

        if (flatSingleResult && length(result) == 1) {
          result[[1]]
        } else {
          result
        }
      }
    },

    #' @description Gets readiness status of the InfluxDB instance.
    #' @return Named list with \code{status}, \code{started} and \code{up} elements or error
    ready = function() {
      # call API
      resp <- self$readyApi$GetReady()

      # handle errors
      private$.throwIfNot2xx(resp)

      resp$toJSON()
    },

    #' @description Writes data to the InfluxDB instance.
    #' @param x Data as (list of) \code{data.frame}
    #' @param bucket Target bucket name
    #' @param batchSize Batch size. Positive number or \code{FALSE} to disable.
    #' Default is \code{5000}.
    #' @param precision Time precision
    #' @param measurementCol Name of measurement column. Default is \code{"_measurement"}.
    #' @param tagCols Names of tag (index) columns
    #' @param fieldCols Names of field columns. In case of unpivoted data
    #' previously retrieved from InfluxDB, use default value ie. named list
    #' \code{c("_field"="_value")}.
    #' For all other cases, just use simple vector of column names (see Examples).
    #' @param timeCol Name of time column. The column values should be either
    #' of \code{nanotime} or \code{POSIXct} type. Default is \code{"_time"}.
    #' @param object \emph{Output object name. For dry-run operation, specify the name
    #' of the object to receive the output. Default is \code{NULL}. For debugging purposes.}
    write = function(x, bucket,
                     batchSize = 5000,
                     precision = c("ns", "us", "ms", "s"),
                     measurementCol = "_measurement",
                     tagCols = NULL,
                     fieldCols = c("_field"="_value"),
                     timeCol = "_time",
                     object = NULL,
                     ...) {
      # vectorize x if necessary
      if (!is.vector(x)) {
        x <- list(x)
      }
      # validate parameters
      xIsCharacter <- all(lapply(x, class) == "character")
      xIsDataFrame <- all(lapply(x, class) == "data.frame")
      if (!(xIsCharacter | xIsDataFrame)) {
        stop("'x' must be data.frame or character")
      }
      if (is.null(bucket)) {
        stop("'bucket' cannot be NULL")
      }
      if (is.numeric(batchSize) && batchSize < 1) {
        stop("'batchSize' must be >= 1 or FALSE")
      }
      if (!is.null(object) && !is.character(object)) {
        stop("'object' must be NULL or character")
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

      # re-chunk line protocol data (https://stackoverflow.com/questions/3318333/split-a-vector-into-chunks)
      lp <- unlist(lp)
      n <- if (identical(batchSize, FALSE)) 1 else ceiling(length(lp) / batchSize)
      if (n > 1) { # >= 2
        batches <- split(lp, cut(seq_along(lp), n, labels = FALSE))
      } else {
        batches <- list(lp)
      }

      # dry run exits now
      if (!is.null(object)) {
        assign(object, value = unname(batches), envir = parent.frame())
        return(NULL)
      }

      # API call closure
      call = function(body) {
        self$writeApi$PostWrite(org = self$org,
                                bucket = bucket,
                                body = body,
                                content.type = "text/plain; charset=utf-8",
                                precision = precision)
      }

      # API call may be wrapper (in case retry options are set)
      send <-
        if (is.null(self$retryOptions)) {
          call
        } else {
          function(body) {
            self$apiClient$retry(body,
                                 fun = call,
                                 funIf = self$apiClient$is_retryable,
                                 retryOptions = self$retryOptions)
          }
        }

      # send the data
      for (batch in batches) {

        # send batch
        resp <- send(batch)

        # handle errors
        private$.throwIfNot2xx(resp)
      }
    }
  ),
  private = list(
    .apiV2Client = NULL,
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
          sprintf("\"%s\"", x)
        },
        "integer" = sprintf("%di", x),
        "integer64" = sprintf("%si", as.character(x)),
        as.character(x)
      )
    },

    as.lp.timestamp = function(x, precision) {
      switch(
        class(x)[1],
        "nanotime"= { private$as.rfc3339nano.timestamp(x, precision = precision) },
        "POSIXct"= { private$as.POSIXct.timestamp(x, precision = precision) },
        stop(paste("unsupported time column type:", class(x)[1]))
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
            skip = 1, # skip group key line
            nrows = 1,
            comment.char = "",
            colClasses = "character",
            stringsAsFactors = FALSE
          )[1, ])

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

        # read default annotation line
        defaults <-
          read.csv(
            text = csvTable,
            header = FALSE,
            skip = 2, # skip group key and datatype lines
            nrows = 1,
            comment.char = "",
            # workaround for parsing empty cell time cell fails (nanotime issue?)
            colClasses = plyr::revalue(colClasses, c("nanotime" = "character"), warn_missing = FALSE),
            stringsAsFactors = FALSE
          )[1, ]
        defaultResultName <- as.character(defaults[1])

        # read CSV table into data frame
        df <-
          read.csv(
            text = csvTable,
            header = TRUE,
            skip = 3,
            check.names = FALSE,
            colClasses = colClasses,
            stringsAsFactors = FALSE
          )

        # temporary unsupported feature check
        if (!all(df$result == "")) {
          stop("inline result name not supported")
        }

        # result name column not needed (yet)
        df$result <- NULL

        # split data frame by table index column
        dfTables <- split(df, df$table)

        # prepare tables
        mtables <- lapply(dfTables, function (dfTable) {
          rownames(dfTable) <- NULL # reset row names to seq starting at 1
          dfTable$table <- NULL # table index column no longer needed
          dfTable
        })

        # append tables to result
        sub <- tables[[defaultResultName]]
        if (is.null(sub)) {
          sub <- list()
        }
        sub <- append(sub, mtables)
        tables[[defaultResultName]] <- unname(sub)
      }

      tables
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
    apiV2Client = function(value) {
      if (missing(value)) {
        if (is.null(private$.apiV2Client)) {
          defaultHeaders <- c()
          defaultHeaders['Authorization'] <- paste0("Token ", self$token)
          private$.apiV2Client <-
            InfluxDBApiClient$new(basePath = paste0(self$url, "/api/v2"),
                                  defaultHeaders = defaultHeaders)
        }
      }
      private$.apiV2Client
    },

    apiClient = function(value) {
      if (missing(value)) {
        if (is.null(private$.apiClient)) {
          defaultHeaders <- c()
          defaultHeaders['Authorization'] <- paste0("Token ", self$token)
          private$.apiClient <-
            InfluxDBApiClient$new(basePath = self$url,
                                  defaultHeaders = defaultHeaders)
        }
      }
      private$.apiClient
    },

    healthApi = function(value) {
      if (missing(value)) {
        if (is.null(private$.healthApi)) {
          private$.healthApi <- HealthApi$new(self$apiClient)
        }
      }
      private$.healthApi
    },

    queryApi = function(value) {
      if (missing(value)) {
        if (is.null(private$.queryApi)) {
          private$.queryApi <- QueryApi$new(self$apiV2Client)
        }
      }
      private$.queryApi
    },

    readyApi = function(value) {
      if (missing(value)) {
        if (is.null(private$.readyApi)) {
          private$.readyApi <- ReadyApi$new(self$apiClient)
        }
      }
      private$.readyApi
    },

    writeApi = function(value) {
      if (missing(value)) {
        if (is.null(private$.writeApi)) {
          private$.writeApi <- WriteApi$new(self$apiV2Client)
        }
      }
      private$.writeApi
    }
  )
)
