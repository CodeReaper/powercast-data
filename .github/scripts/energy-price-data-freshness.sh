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
which dirname find sort tail jq > /dev/null

SCRIPTS=$(dirname $0)

[ -d "$FOLDER" ] || { echo "Not a directory: $FOLDER"; exit 1; }
AREA=$(echo "$AREA" | tr [:lower:] [:upper:])
[ -z $AREA ] && { echo "Invalid/Missing area."; exit 2; }
[ -z $ENDDATE ] && { echo "Invalid/Missing ENDDATE."; exit 3; }

LATEST=$(find "$FOLDER" -name "${AREA}.json" | sort | tail -n1)

echo $(sh "${SCRIPTS}/energy-price-data-freshness-file.sh" "$LATEST" "$ENDDATE")