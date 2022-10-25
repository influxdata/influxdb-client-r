#!/usr/bin/env bash

SCRIPT_PATH="$( cd "$(dirname "$0")" || exit ; pwd -P )"

pushd "${SCRIPT_PATH}"/../

rm influxdbclient_*.tar.gz

mv LICENSE /tmp/LICENSE-influxdbclient-github
mv LICENSE.cran LICENSE

R CMD build .

mv LICENSE LICENSE.cran
mv /tmp/LICENSE-influxdbclient-github LICENSE

popd