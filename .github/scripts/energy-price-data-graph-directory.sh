#!/bin/sh

# Takes six arguments:
#   - config file:
#       Will be used to limit the data generated.
#       Examples:
#           - .config.json
#           - test.json
#   - data directory:
#       The directory with data.
#       Must be a valid path to a directory with data from `energy-price-data-write`.
#       Examples:
#           - ./
#           - data/
#   - cut off date:
#       Will limit the output to this date per configured zone.
#       Must be a unix timestamp.
#       Example: 1654012800
#   - output directory:
#       The output files will be written to this directory.
#       Examples:
#           - ./
#           - data/
#   - base url:
#       Optional, will default to ''.
#       Must be a valid url, protocol is omissable.
#       Examples:
#           - //example.com/path/
#           - http://example.com/path/
#   - display groups:
#       Optional, will default to '[]'.
#       Must be valid Javascript
#       Example: [{key: 1}]

# Output example:
# None

CONFIG=$1
DATA_FOLDER=$2
DATE=$3
OUTPUT_FOLDER=$4
BASE_URL=${5:-'/'}
GROUPS=${6:-'[]'}
DIR=/tmp/$$

set -e
which mkdir dirname cat jq tr sed > /dev/null

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

SCRIPTS=$(dirname "$0")
RESOURCES=$(dirname "$SCRIPTS")/resources

[ -f "$CONFIG" ] || { echo "Not a file: $CONFIG"; exit 1; }
[ -d "$DATA_FOLDER" ] || { echo "Not a directory: $DATA_FOLDER"; exit 2; }
[ -z $DATE ] && { echo "Invalid/Missing date."; exit 3; }
[ -z "$OUTPUT_FOLDER" ] || { echo "Invalid/Missing output directory"; exit 4; }
[ -z "$BASE_URL" ] && { echo "Invalid/Missing base url."; exit 5; }
[ -z "$GROUPS" ] && { echo "Invalid/Missing display groups."; exit 6; }

mkdir -p "$OUTPUT_FOLDER" > /dev/null

cat "${RESOURCES}/energy-price-graph/graph.html" | sed "s|BASE_URL|${BASE_URL}|g" > "${OUTPUT_FOLDER}/index.html"

DATA_JS_FILE="${OUTPUT_FOLDER}/data.js"

echo -n 'const data = { datasets: ' > "$DATA_JS_FILE"
sh "${SCRIPTS}/energy-price-data-graph-data.sh" "${CONFIG}" "$DATA_FOLDER" $DATE | jq -rcj '.' >> "$DATA_JS_FILE"
echo ' };' >> "$DATA_JS_FILE"

echo -n 'const displayGroups = ' >> "$DATA_JS_FILE"
echo -n "$GROUPS" >> "$DATA_JS_FILE"
echo ';' >> "$DATA_JS_FILE"
