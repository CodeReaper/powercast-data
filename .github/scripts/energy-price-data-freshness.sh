#!/bin/sh

# Takes three arguments:
#   - directory:
#       The directory in which to find an end date.
#       Must be a valid path to a directory with data from `energy-price-data-write`.
#       Examples:
#           - ./
#           - data/
#   - price area:
#       Only data related to this price area will be evaluated.
#       Must be a singular area.
#       Examples:
#           - DK1
#           - DE
#   - fallback end date:
#       This end date will be outputted, if no data files were found.
#       Must be a unix timestamp.
#       Example: 1654012800

# Output example:
# 1654012800

FOLDER=$1
AREA=$2
ENDDATE=$3

set -e
which find sort tail jq cat > /dev/null

[ -d "$FOLDER" ] || { echo "Not a directory: $FOLDER"; exit 1; }

LATEST=$(find "$FOLDER" -name "${AREA}.json" | sort | tail -n1)

if [ -z $LATEST ]; then
    echo $ENDDATE
    exit 0
fi

cat "$LATEST" | jq -r 'map(.timestamp | values) | max'
