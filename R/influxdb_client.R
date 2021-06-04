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

      # type mapping
      private$.typeMap = c(
        "#datatype" = "NULL",
        "string" = "character",
        "long" = "integer64",
        "boolean" = "logical",
        "dateTime:RFC3339" = "rfc3339"
      )
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
        # split stream by empty line
        csvTables <-
          strsplit(resp, split = "\r\n\r\n", useBytes = TRUE)[[1]]

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
                "dateTime:RFC3339" = "rfc3339"
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
          for (dfTable in dfTables) {
            table <- dfTable[-1] # first column is table index, no longer needed
            tables <- rlist::list.append(tables, table)
          }
        }
        tables
      }
    }
  ),
  private = list(
    .apiClient = NULL,
    .healthApi = NULL,
    .queryApi = NULL,
    .typeMap = NULL
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
    }
  )
)
