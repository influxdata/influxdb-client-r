#' @docType class
#' @title FluxApiClient
#' @description FluxApiClient Class
#' @format An \code{R6Class} generator object
#' @export
FluxApiClient <- R6::R6Class(
  inherit = ApiClient,
  'FluxApiClient',
  public = list(
    # deserialize overriden
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
