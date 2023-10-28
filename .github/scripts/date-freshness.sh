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
#   - evaluation date:
#       Must be a unix timestamp.
#       Example: 1654012800
#   - current date:
#       Must be a unix timestamp.
#       Example: 1654012800

# Output example:
# 20

CONFIG=$1
AREA=$2
DATE=$3
NOWDATE=$4

set -e
which jq > /dev/null

[ -f "$CONFIG" ] || { echo "Not a file: $CONFIG"; exit 1; }
AREA=$(echo "$AREA" | tr '[:lower:]' '[:upper:]')
[ -z "$AREA" ] && { echo "Invalid/Missing area."; exit 2; }
expr "$DATE" : "^[0-9]*$" > /dev/null || { echo "Not a number: $DATE"; exit 3; }
expr "$NOWDATE" : "^[0-9]*$" > /dev/null || { echo "Not a number: $NOWDATE"; exit 4; }
[ "$NOWDATE" -ge "$DATE" ] || { echo "Cannot handle dates in the future"; exit 5; }

if [ "$(jq --arg zone "$AREA" '.[] | select(.zone == $zone) | if (.canBeStale == null or .canBeStale == true) then true else false end' "$CONFIG")" = "false" ]; then
  echo "0"
  exit 0
fi

echo $(((NOWDATE-DATE)/3600))
