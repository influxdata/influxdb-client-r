#!/bin/bash

rm influxdbclient_*.tar.gz

mv LICENSE /tmp/LICENSE-influxdbclient-github
mv LICENSE.cran LICENSE

R CMD build .

mv LICENSE LICENSE.cran
mv /tmp/LICENSE-influxdbclient-github LICENSE
