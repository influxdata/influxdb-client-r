#' InfluxDBApiClient Class
#'
#' Customized \code{ApiClient} to handle non-JSON replies from InfluxDB,
#' such as query results. Used in \code{InfluxDBClient} instead of generated
#' \code{ApiClient}.
#'
#' @docType class
#' @title InfluxDBApiClient
#' @description InfluxDBApiClient Class
#' @format An \code{R6Class} object
#' @export
InfluxDBApiClient <- R6::R6Class(
  inherit = ApiClient,
  'InfluxDBApiClient',
  public = list(
    #' @description Overriden \code{deserialize} method from base class.
    deserialize = function(resp, returnType, pkgEnv) {
      if (httr::http_type(resp) == "text/csv") {
        httr::content(resp, "text", encoding = "UTF-8")
      } else if (httr::http_type(resp) == "application/json") {
        super$deserialize(resp, returnType, pkgEnv)
      } else {
        stop(paste('Unsupported content type:', httr::http_type(resp)))
      }
    }
  )
)
