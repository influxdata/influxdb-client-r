.onLoad <- function(libname, pkgname) {
  # set max fractional digits possible for POSIXct
  options(digits.secs = 6)
  # nanotime (< 0.3) hack
  library(nanotime)
  if (!exists("as.nanotime")) {
    #  as.nanotime <<- nanotime::nanotime
    s.nanotime <- function(from, ...) {
      new("nanotime", as.integer64(from, keep.names=TRUE))
    }
    setGeneric("as.nanotime")
  }
}
