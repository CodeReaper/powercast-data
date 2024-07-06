#!/bin/sh

# Takes two arguments:
#   - file:
#       The file in which to find an end date.
#       Must use format where the contents is an array of object with a timestamp property.
#       Examples:
#           - data.json
#           - data/output.json
#   - fallback end date:
#       This end date will be outputted, if no end dates were found.
#       Must be a unix timestamp.
#       Example: 1654012800

# Output example:
# 1654012800

FILE=$1
ENDDATE=$2

set -e
which jq > /dev/null

[ -f "$FILE" ] || { echo "Not a FILE: $FILE"; exit 1; }
[ -z "$ENDDATE" ] && { echo "Invalid/Missing ENDDATE."; exit 2; }

LATEST=$(jq -r 'map(.timestamp | values) | max' "$FILE")

if [ -z "$LATEST" ] || [ "null" = "$LATEST" ]; then
    echo "$ENDDATE"
    exit 0
fi

echo "$LATEST"
