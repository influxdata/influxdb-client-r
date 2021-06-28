#' Creates instance of \code{InfluxDBClient}. Equivalent to \code{InfluxDbClient$new} call().
#'
#' @examples
#'
#' \dontrun{
#' client <- client(url = "http://localhost:8086",
#'                  token = "my-token",
#'                  org = "my-org")
#' }
#' @param url InfluxDB instance URL
#' @param token Authentication token
#' @param org Organization name
#' @param retryOptions Retry options. Use \code{retry_options} function to create it.
#' Default is \code{NULL} for no retries. `Use `TRUE` for default retry strategy.
#' @return Instance of \code{InfluxDBClient}
#' @export
client = function(url, token, org, retryOptions = NULL) {
  InfluxDBClient$new(url = url, token = token, org = org, retryOptions = retryOptions)
}

#' Creates instance of \code{RetryOptions}. Equivalent to \code{RetryOptions$new} call().
#'
#' @examples
#'
#' \dontrun{
#' client <- client(url = "http://localhost:8086",
#'                  token = "my-token",
#'                  org = "my-org",
#'                  retry_options(maxAttempts = 3))
#' }
#' @param retryJitter Maximum number of random milliseconds included in delay. Default is \code{0}.
#' @param retryInterval First retry delay in seconds. Default is \code{5}.
#' @param maxDelay Maximum delay between retries in seconds. Default is \code{125}.
#' @param maxRetryTime Maximum time to spend retrying in seconds. Default is \code{180}.
#' @param maxAttempts Number of retry attempts. Default is \code{5}.
#' @param exponentialBase Base for exponential backoff strategy. Default is \code{2}.
#' @param ... Optional arguments
#' @return Instance of \code{RetryOptions}
#' @export
retry_options = function(retryJitter = 0, retryInterval = 5,
                         maxDelay = 125, maxRetryTime = 180, maxAttempts = 5,
                         exponentialBase = 2, ...) {
  RetryOptions$new(retryJitter = retryJitter, retryInterval = retryInterval,
                   maxDelay = maxDelay, maxRetryTime = maxRetryTime, maxAttempts = maxAttempts,
                   exponentialBase = exponentialBase, ...)
}
