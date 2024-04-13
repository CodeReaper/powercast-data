#!/bin/sh
# Takes four arguments:
#   - current date:
#       Must be a unix timestamp.
#       Example: 1654012800
#   - type:
#       Must be a string.
#       Example: delay
#   - directory:
#       The directory in which to write updated file.
#       Examples:
#           - ./
#           - data/

# There is no output, but data will be written to files in directory/index.json

set -e

NOW=$1
TYPE=$2
FOLDER=$3

which jq > /dev/null

[ -z "$NOW" ] && { echo "Missing NOW."; exit 1; }
[ -z "$TYPE" ] && { echo "Missing TYPE."; exit 2; }
[ -z "$FOLDER" ] && { echo "Missing FOLDER"; exit 3; }

mkdir -p "$FOLDER" || true

OUTPUT="$FOLDER/index.json"

[ -f "$OUTPUT" ] || echo '[]' > "$OUTPUT"

# shellcheck disable=SC2016
TRANSFORMATION='[.[] | select(.to == null and .type == $type)] | length'

COUNT=$(jq -r --arg type "$TYPE" "$TRANSFORMATION" < "$OUTPUT")

[ $COUNT -gt 0 ] && exit 0

TRANSFORMATION='. += [{"from":($now|tonumber),"to":null,"type":$type}]'

jq -r --arg type "$TYPE" --arg now "$NOW" "$TRANSFORMATION" < "$OUTPUT" > /tmp/$$.data

mv /tmp/$$.data "$OUTPUT"
