#!/bin/sh

# Takes four arguments:
#   - zone configuration file:
#       Examples:
#           - data.json
#           - data/output.json
#   - price area:
#       Must be a singular valid area.
#       Examples:
#           - DK1
#           - DE
#   - evaluation date a:
#       Must be a unix timestamp.
#       Example: 1654012800
#   - evaluation date b:
#       Must be a unix timestamp.
#       Example: 1654012800

# Output example:
# 20

CONFIG=$1
AREA=$2
ADATE=$3
BDATE=$4

set -e
which jq > /dev/null

[ -f "$CONFIG" ] || { echo "Not a file: $CONFIG"; exit 1; }
AREA=$(echo "$AREA" | tr '[:lower:]' '[:upper:]')
[ -z "$AREA" ] && { echo "Invalid/Missing area."; exit 2; }
expr "$ADATE" : "^[0-9]*$" > /dev/null || { echo "Not a number: $ADATE"; exit 3; }
expr "$BDATE" : "^[0-9]*$" > /dev/null || { echo "Not a number: $BDATE"; exit 4; }

if [ "$(jq --arg zone "$AREA" '.[] | select(.zone == $zone) | if (.canBeStale == null or .canBeStale == true) then true else false end' "$CONFIG")" = "false" ]; then
  echo "0"
  exit 0
fi

echo $(((BDATE-ADATE)/3600))
