#' @docType class
#' @title InfluxDBApiClient
#' @description Subclass of \code{ApiClient}.
#' \itemize{
#'   \item handles non-JSON replies from InfluxDB, such as query results
#'   \item implements exponential backoff retry strategy
#'   \item classifies retryable errors
#' }
#' Used by \code{InfluxDBClient} instead of generated \code{ApiClient}.
#' @format An \code{R6Class} object
InfluxDBApiClient <- R6::R6Class(
  inherit = ApiClient,
  'InfluxDBApiClient',
  public = list(
    #' @description Overrides \code{deserialize} method from base class.
    deserialize = function(resp, returnType, pkgEnv) {
      if (httr::http_type(resp) == "text/csv") {
        httr::content(resp, "text", encoding = "UTF-8")
      } else if (httr::http_type(resp) == "application/json") {
        super$deserialize(resp, returnType, pkgEnv)
      } else {
        stop(paste('Unsupported content type:', httr::http_type(resp)))
      }
    },

    #' @description Retries \code{fun} call.
    retry = function(x, fun, funIf = NULL, retryOptions) {
      resp <- NULL
      attempt <- 0
      deadline <- Sys.time() + retryOptions$maxRetryTime

      # for up to `maxAttempts` do
      repeat {
        # attempt number
        attempt <- attempt + 1

        # do call
        resp <- fun(x)

        # break on success
        if (!identical(class(resp), c("ApiResponse", "R6"))) {
          break
        }

        # break on non-retryable errors or if cannot tell
        if (is.null(funIf) || !funIf(resp$response)) {
          break
        }

        # break when max number of attempts was reached
        if (attempt >= retryOptions$maxAttempts) {
          warning("maximum retry attempts reached")
          break
        }

        # when max retry time is exceeded
        if (Sys.time() > deadline) {
          warning("maximum retry time exceeded")
          break
        }

        # try to get retry-after
        statusCode <- httr::status_code(resp$response)
        retryAfter <- unlist(unname(httr::headers(resp$response)["Retry-After"]))

        # calculate delay before next attempt
        delay <- private$.delay(retryOptions, attempt, retryAfter, deadline)
        message(sprintf("retryable error occured: %d next attempt in: %fs",
                        statusCode, delay))

        # call on-retry handler
        if (is.function(retryOptions$onRetry)) {
          if (!retryOptions$onRetry(resp$response, delay = delay)) {
            delay <- 0
          }
        }

        # sleep
        if (delay > 0) {
          Sys.sleep(delay)
        }
      }

      resp
    },

    #' @description Checks if HTTP error response represents retryable error.
    is_retryable = function(resp) {
      httr::status_code(resp) %in% c(429, 503)
    }
  ),
  private = list(
    .delay = function(retryOptions, attempt, retryAfter, deadline) {
      stopifnot(attempt > 0 && attempt <= retryOptions$maxAttempts)

      # get random multiplier (0.0 - 1.0)
      rand <- runif(1)

      # result
      delay <- 0

      # use retry-after if avail
      if (!is.null(retryAfter) && retryAfter > 0) {
        delay <- retryAfter + (trunc(retryOptions$retryJitter * rand) / 1000)
      } else { # calculate delay using exponential backoff
        rangeStart <- retryOptions$retryInterval * (retryOptions$exponentialBase ^ (attempt - 1))
        rangeStop <- retryOptions$retryInterval * (retryOptions$exponentialBase ^ attempt)
#        if (rangeStop > retryOptions$maxDelay) {
#          rangeStop <- retryOptions$maxDelay;
#        }
        delay <- rangeStart + (rangeStop - rangeStart) * rand
        if (delay > retryOptions$maxDelay) {
          delay <- retryOptions$maxDelay
        }
      }

      # respect deadline
      if (!is.null(deadline)) {
        tillDeadline <- as.double(deadline - Sys.time(), units = "secs")
        if (delay > tillDeadline) {
          delay <- if (tillDeadline < 0) 0 else tillDeadline
        }
      }

      delay
    }
  )
)
