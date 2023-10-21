#!/bin/sh

# Takes three arguments:
#   - data file:
#       Must contain pricing data for network companies.
#       Examples:
#           - data.json
#           - data-for-zone.json
#   - config file:
#       Will be used to generate filters for network companies.
#       Examples:
#           - .config.json
#           - test.json
#   - price area:
#       Data will be restricted to this price area.
#       Must be a singular valid area.
#       Examples:
#           - DK1
#           - DE

# Output example:
# [
#   {
#     "name": "N1 A/S",
#     tariffs: [
#       {
#         "from": 1293836400,
#         "to": 1325372400,
#         [0.1101, ...] // 24 entries with hourly tariffs
#       }
#     ]
#   },
#   ...
# ]

set -e

DIR=/tmp/$$
INPUT=$1
CONFIG=$2
AREA=$3

[ -f "$INPUT" ] || { echo "Not a file: $INPUT"; exit 1; }
[ -f "$CONFIG" ] || { echo "Not a file: $CONFIG"; exit 2; }
AREA=$(echo "$AREA" | tr '[:lower:]' '[:upper:]')
[ -z "$AREA" ] && { echo "Invalid/Missing area."; exit 3; }

which mkdir jq > /dev/null

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

echo '[' > $DIR/output.json
jq -rc --arg zone "$AREA" '.[] | select(.zone == $zone) | .networkCompanies[]' < "$CONFIG" | while read -r ITEM; do
    [ -z "$ITEM" ] && continue

    id=$(echo "$ITEM" | jq -r '.gln')
    type=$(echo "$ITEM" | jq -r '.type')
    code=$(echo "$ITEM" | jq -r '.code')
    name=$(echo "$ITEM" | jq -r '.name')

    [ -z "$id" ] && continue
    [ -z "$type" ] && continue
    [ -z "$code" ] && continue
    [ -z "$name" ] && continue

    # jq -r ''

done
echo ']' >> $DIR/output.json
