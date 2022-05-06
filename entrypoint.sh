#!/bin/bash
set -e
git --version
git config --global --add safe.directory /opt/esp/idf
. $IDF_PATH/export.sh

exec "$@"
