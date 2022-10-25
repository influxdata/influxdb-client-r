#!/usr/bin/env bash

#
# How to run script from ROOT path:
#   docker run --rm -it -v "${PWD}":/code -v ~/.m2:/root/.m2 -w /code maven:3-openjdk-8 /code/bin/generate-sources.sh
#

SCRIPT_PATH="$( cd "$(dirname "$0")" || exit ; pwd -P )"

rm -rf "${SCRIPT_PATH}"/generated

# Download and merge OSS and Cloud definition
rm -rf "${SCRIPT_PATH}"/oss.yml || true
rm -rf "${SCRIPT_PATH}"/cloud.yml || true
rm -rf "${SCRIPT_PATH}"/influxdb-clients-apigen || true
wget https://raw.githubusercontent.com/influxdata/openapi/master/contracts/oss.yml -O "${SCRIPT_PATH}/oss.yml"
wget https://raw.githubusercontent.com/influxdata/openapi/master/contracts/cloud.yml -O "${SCRIPT_PATH}/cloud.yml"
wget https://raw.githubusercontent.com/influxdata/openapi/master/contracts/invocable-scripts.yml -O "${SCRIPT_PATH}/invocable-scripts.yml"
git clone --single-branch --branch master https://github.com/bonitoo-io/influxdb-clients-apigen "${SCRIPT_PATH}/influxdb-clients-apigen"
mvn -f "$SCRIPT_PATH"/influxdb-clients-apigen/openapi-generator/pom.xml compile exec:java -Dexec.mainClass="com.influxdb.MergeContracts" -Dexec.args="$SCRIPT_PATH/oss.yml $SCRIPT_PATH/invocable-scripts.yml"
mvn -f "$SCRIPT_PATH"/influxdb-clients-apigen/openapi-generator/pom.xml compile exec:java -Dexec.mainClass="com.influxdb.AppendCloudDefinitions" -Dexec.args="$SCRIPT_PATH/oss.yml $SCRIPT_PATH/cloud.yml"

# Generate client
cd "${SCRIPT_PATH}"/ || exit
mvn org.openapitools:openapi-generator-maven-plugin:generate

# Copy client
cp -r "${SCRIPT_PATH}"/generated/R/api_client.R "${SCRIPT_PATH}"/../R/
cp -r "${SCRIPT_PATH}"/generated/R/api_response.R "${SCRIPT_PATH}"/../R/

# Copy models
cp -r "${SCRIPT_PATH}"/generated/R/dialect.R "${SCRIPT_PATH}"/../R/
cp -r "${SCRIPT_PATH}"/generated/R/health_check.R "${SCRIPT_PATH}"/../R/
cp -r "${SCRIPT_PATH}"/generated/R/query.R "${SCRIPT_PATH}"/../R/

# Copy supported APIs
cp -r "${SCRIPT_PATH}"/generated/R/health_api.R "${SCRIPT_PATH}"/../R/
cp -r "${SCRIPT_PATH}"/generated/R/query_api.R "${SCRIPT_PATH}"/../R/
cp -r "${SCRIPT_PATH}"/generated/R/write_api.R "${SCRIPT_PATH}"/../R/

rm -rf "${SCRIPT_PATH}"/generated
rm -rf "${SCRIPT_PATH}/influxdb-clients-apigen"
