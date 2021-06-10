#' @docType class
#' @title InfluxDBClient
#' @description InfluxDBClient Class
#' @format An \code{R6Class} generator object
#' @field url Database url
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

    health = function() {
      # call API
      resp <- self$healthApi$GetHealth()

      # handle errors
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

      resp
    },

    query = function(text) {
      # create query instance
      q <- Query$new(query = text,
                     dialect = self$dialect,
                     type = "flux")

      # call API
      resp <- self$queryApi$PostQuery(query = q, org = self$org)

      # handle errors
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

      # process response
      if (resp == "\r\n") {
        message('empty response')
        NULL # TODO return empty list?
      } else {
        self$fromAnnotatedCsv(resp)
      }
    },

    write = function(x, bucket, precision = 'ns', ...) {
      # detect input type
      clazz <- NULL
      if (is.vector(x)) {
        if (length(x) == 0) {
          stop('Empty input vector')
        } else {
          clazz <- class(x[[1]])
        }
      } else {
        clazz <- class(x)
      }

      # serialize x into line protocol
      body <- switch(
        clazz,
        "character"= { x },
        "data.frame"= { self$toLineProtocol(x, precision, ...) },
        stop(paste('Unsupported type for write:', clazz))
      )
      body <- unlist(body)

      # call API
      resp <- self$writeApi$PostWrite(org = self$org,
                                      bucket = bucket,
                                      body = body,
                                      precision = precision)

      # handle errors
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

    fromAnnotatedCsv = function(x) {
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

    toLineProtocol = function(x,
                              precision,
                              measurementCol = '_measurement',
                              tagCols = NULL,
                              fieldCols = c("_field"="_value"),
                              timeCol = '_time') {
      if (is.null(measurementCol)) {
        stop('`measurementCol` parameter cannot be NULL')
      } else if (is.vector(measurementCol) & length(measurementCol) != 1) {
        stop('`measurementCol` parameter must select single column')
      }
      if (is.null(fieldCols)) {
        stop('`fieldCols` parameter cannot be NULL')
      } else if (is.vector(fieldCols) & length(fieldCols) == 0) {
        stop('`fieldCols` parameter cannot be empty vector')
      }
      if (is.null(timeCol)) {
        stop('`timeCol` parameter cannot be NULL')
      } else if (is.vector(timeCol) & length(timeCol) != 1) {
        stop('`timeCol` parameter must select single column')
      }

      # temporary sanity check
      named <- FALSE
      if (any(names(fieldCols) != "")) {
        if (any(names(fieldCols) == "")) {
          stop('mixed named `fieldCols` list not supported')
        }
        named <- TRUE
      }

      # vectorize x if necessary
      if (!is.vector(x)) {
        x <- list(x)
      }

      # for all data frames
      buffers <- lapply(x, FUN = function(df) {
        colNames <- colnames(df)
        if (!(measurementCol %in% colNames)) {
          stop(sprintf("measurement column '%s' not found in data frame",
                       measurementCol))
        }
        if (!all(tagCols %in% colNames)) {
          notFound <- tagCols[!(tagCols %in% colNames)]
          stop(sprintf('tag columns not found in data frame: %s',
                       paste(notFound, sep = "", collapse = ",")))
        }
        if (!all(fieldCols %in% colNames)) {
          notFound <- fieldCols[!(fieldCols %in% colNames)]
          stop(sprintf('field columns not found in data frame: %s',
                       paste(notFound, sep = "", collapse = ",")))
        }
        if (!(timeCol %in% colNames)) {
          stop(sprintf("time column '%s' not found in data frame",
                       timeCol))
        }
        con <- textConnection("buffer", open = "w", local = TRUE)
        for (i in 1:nrow(df)) {
          row <- df[i,]
          measurement <- row[measurementCol]
          tags <- row[tagCols]
          fields <- row[fieldCols]
          fieldNames <- NULL
          if (named) {
            fieldNames <- row[names(fieldCols)]
          } else {
            fieldNames <- fieldCols
          }
          time <- row[timeCol]
          line <- sprintf("%s,%s %s %s",
                          measurement[[1]],
                          paste(tagCols, lapply(lapply(tags, private$as.flux.booleanIf), as.character),
                                sep = "=", collapse = ","),
                          paste(fieldNames, lapply(lapply(fields, private$as.flux.booleanIf), as.character),
                                sep = "=", collapse = ","),
                          private$as.flux.timestamp(time[[1]], precision))
          writeLines(line, con = con)
        }
        close(con)
        buffer
      })

      buffers
    }
  ),
  private = list(
    .apiClient = NULL,
    .healthApi = NULL,
    .queryApi = NULL,
    .writeApi = NULL,

    as.flux.booleanIf = function(x) {
      if (class(x) == "logical") {
        tolower(as.character(x))
      } else {
        x
      }
    },

    as.flux.timestamp = function(x, precision) {
      switch(
        class(x),
        "nanotime"= { private$as.rfc3339nano.timestamp(x, precision = precision) },
        "POSIXct"= { private$as.POSIXct.timestamp(x, precision = precision) },
        stop(paste('unsupported time column type:', class(x)))
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
    }
  ),
  active = list(
    apiClient = function(value) {
      if (missing(value)) {
        if (is.null(private$.apiClient)) {
          defaultHeaders <- c()
          defaultHeaders['Authorization'] <- paste0('Token ', self$token)
          private$.apiClient <-
            FluxApiClient$new(basePath = paste0(self$url, '/api/v2'),
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
