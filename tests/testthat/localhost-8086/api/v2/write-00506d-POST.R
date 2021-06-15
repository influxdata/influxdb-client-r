structure(list(url = "http://localhost:8086/api/v2/write?org=bonitoo&bucket=no-bucket&precision=ns", 
    status_code = 404L, headers = structure(list(`content-type` = "application/json; charset=utf-8", 
        `x-platform-error-code` = "not found", date = "Tue, 15 Jun 2021 09:06:38 GMT", 
        `content-length` = "63"), class = c("insensitive", "list"
    )), all_headers = list(list(status = 404L, version = "HTTP/1.1", 
        headers = structure(list(`content-type` = "application/json; charset=utf-8", 
            `x-platform-error-code` = "not found", date = "Tue, 15 Jun 2021 09:06:38 GMT", 
            `content-length` = "63"), class = c("insensitive", 
        "list")))), cookies = structure(list(domain = logical(0), 
        flag = logical(0), path = logical(0), secure = logical(0), 
        expiration = structure(numeric(0), class = c("POSIXct", 
        "POSIXt")), name = logical(0), value = logical(0)), row.names = integer(0), class = "data.frame"), 
    content = charToRaw("{\"code\":\"not found\",\"message\":\"bucket \\\"no-bucket\\\" not found\"}"), 
    date = structure(1623747998, class = c("POSIXct", "POSIXt"
    ), tzone = "GMT"), times = c(redirect = 0, namelookup = 2.7e-05, 
    connect = 0.000114, pretransfer = 0.000213, starttransfer = 0.00139, 
    total = 0.001407)), class = "response")
