#!/bin/bash
# Setup script that generates CA and entity certificates.
# Based on https://github.com/elastic/elasticsearch/blob/main/docs/reference/setup/install/docker/docker-compose.yml

set -euo pipefail
IFS=$'\n\t'

ES_HOME_DIR="/usr/share/elasticsearch"


if ! [ "$PWD" = "$ES_HOME_DIR" ]; then
  echo "Incorrect PWD: expected: $ES_HOME_DIR, actual: $PWD"
  exit 1;
fi

if [ ! -f config/certs/ca.zip ]; then
  echo "Creating CA"
  bin/elasticsearch-certutil ca --silent --pem -out config/certs/ca.zip
  unzip -n config/certs/ca.zip -d config/certs
fi;

if [ ! -f config/certs/certs.zip ]; then
  echo "Creating certs"
  bin/elasticsearch-certutil cert --silent --pem -out config/certs/certs.zip --in config/certs/instances.yml --ca-cert config/certs/ca/ca.crt --ca-key config/certs/ca/ca.key
  unzip -n config/certs/certs.zip -d config/certs
fi

echo "Setting file permissions"
find config/certs -type d -exec chmod 750 \{\} \;
find config/certs -type f -exec chmod 640 \{\} \;

echo "Copying CA cert file"
cp config/certs/ca/ca.crt config/ca_certs/ca.crt
chmod 644 config/ca_certs/ca.crt
chmod 755 config/ca_certs

echo "All done!"
