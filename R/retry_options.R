#' @docType class
#' @title RetryOptions
#' @description Retry options may be specified as optional argument to \code{write}.
#' @format An \code{R6Class} object
#' @field retryJitter Maximum number of random milliseconds included in delay. Default is \code{0}.
#' @field retryInterval First retry delay in seconds. Default is \code{5}.
#' @field maxDelay Maximum delay between retries in seconds. Default is \code{125}.
#' @field maxRetryTime Maximum time to spend retrying in seconds. Default is \code{180}.
#' @field maxAttempts Number of retry attempts. Default is \code{5}.
#' @field exponentialBase Base for exponential backoff strategy. Default is \code{2}.
#' @export
RetryOptions  <- R6::R6Class(
  'RetryOptions',
  public = list(
    retryJitter = NULL,
    retryInterval = NULL,
    maxDelay = NULL,
    maxRetryTime = NULL,
    maxAttempts = NULL,
    exponentialBase = NULL,
    onRetry = NULL, # intentionally undocumented

    #' @description Creates instance of \code{RetryOptions}.
    initialize = function(retryJitter = 0, retryInterval = 5,
                          maxDelay = 125, maxRetryTime = 180, maxAttempts = 5,
                          exponentialBase = 2, ...) {
      self$retryJitter <- retryJitter
      self$retryInterval <- retryInterval
      self$maxDelay <- maxDelay
      self$maxRetryTime <- maxRetryTime
      self$maxAttempts <- maxAttempts
      self$exponentialBase <- exponentialBase
      args <- list(...)
      if ("onRetry" %in% names(args)) {
        self$onRetry <- args[["onRetry"]]
      }
    }
  )
)
