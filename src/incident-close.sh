#!/bin/sh
# Takes four arguments:
#   - price area:
#       Must be a singular area.
#       Examples:
#           - DK1
#           - DE
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

AREA=$1
NOW=$2
TYPE=$3
FOLDER=$4

which jq > /dev/null

AREA=$(echo "$AREA" | tr '[:lower:]' '[:upper:]')
[ -z "$AREA" ] && { echo "Invalid/Missing area."; exit 1; }
[ -z "$NOW" ] && { echo "Invalid/Missing NOW."; exit 2; }
[ -z "$TYPE" ] && { echo "Invalid/Missing TYPE."; exit 3; }
[ -d "$FOLDER" ] || { echo "Not a directory: $FOLDER"; exit 4; }

OUTPUT="$FOLDER/$AREA.json"

# shellcheck disable=SC2016
TRANSFORMATION='. |= map(.to = if .type == $type and .to == null then ($now|tonumber) else .to end)'

jq -r --arg type "$TYPE" --arg now "$NOW" "$TRANSFORMATION" < "$OUTPUT" > /tmp/$$.data

mv /tmp/$$.data "$OUTPUT"
