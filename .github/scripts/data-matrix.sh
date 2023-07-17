#!/bin/sh

# Takes up to three arguments:
#   - config file:
#       Will be used to create matrix for generating data.
#       Examples:
#           - .config.json
#           - test.json
#   - directory:
#       Data will be used to evaluate how old the current data is.
#       Must be a valid path to a directory with files that `data-freshness-file` can parse.
#       Examples:
#           - ./
#           - data/

# Output example:
# [
#   {
#     "zone": "DK2",
#     "latest": 1654041600
#   },
#   ...
# ]

CONFIG=$1
FOLDER=$2
DIR=/tmp/$$

set -e
which mkdir dirname cat jq tr sed > /dev/null

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

SCRIPTS=$(dirname "$0")

[ -f "$CONFIG" ] || { echo "Not a file: $CONFIG"; exit 1; }
[ -d "$FOLDER" ] || { echo "Not a directory: $FOLDER"; exit 2; }

printf '[' > $DIR/matrix.json
jq -rc '.[] | del(.display)' "$CONFIG" | while read -r ITEM; do
    AREA=$(echo "$ITEM" | jq -r '.zone')
    ENDDATE=$(echo "$ITEM" | jq -r '.endDate')
    LATEST=$(sh "${SCRIPTS}/data-freshness.sh" "$FOLDER" "$AREA" "$ENDDATE")
    printf "{\"zone\":\"%s\",\"latest\":%s}," "$AREA" "$LATEST" >> "$DIR/matrix.json"
done

printf ']' >> $DIR/matrix.json

cat $DIR/matrix.json | sed 's|,]|]|g' | jq -r '.'
