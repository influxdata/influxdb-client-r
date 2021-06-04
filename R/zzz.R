.onLoad <- function(libname, pkgname) {
  # set handlers for Flux datatypes deserialization
  methods::setAs("character", "rfc3339",
                 function(from) as.POSIXct(from, tz="UTC", format="%Y-%m-%dT%H:%M:%OSZ"))
  methods::setAs("character", "integer64",
                 function(from) bit64::as.integer64(from))
}
