.onLoad <- function(libname, pkgname) {
  # set max fractional digits possible for POSIXct
  options(digits.secs = 6)
}
