.onLoad <- function(libname, pkgname) {
  # set max fractional digits possible for POSIXct
  options(digits.secs = 6)
  # nanotime (< 0.3.0) hack
  if (!exists("as.nanotime")) {
    as.nanotime <<- nanotime::nanotime
  }
}
