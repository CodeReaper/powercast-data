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

[ -z "$NOW" ] && { echo "Invalid/Missing NOW."; exit 1; }
[ -z "$TYPE" ] && { echo "Invalid/Missing TYPE."; exit 2; }
[ -d "$FOLDER" ] || { echo "Not a directory: $FOLDER"; exit 3; }

OUTPUT="$FOLDER/index.json"

# shellcheck disable=SC2016
TRANSFORMATION='. |= map(.to = if .type == $type and .to == null then ($now|tonumber) else .to end)'

jq -r --arg type "$TYPE" --arg now "$NOW" "$TRANSFORMATION" < "$OUTPUT" > /tmp/$$.data

mv /tmp/$$.data "$OUTPUT"
