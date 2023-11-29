#!/bin/sh

# Takes up to four arguments:
#   - config file:
#       Will be used to create matrix for generating data.
#       Examples:
#           - .config.json
#           - test.json
#   - category:
#       Filtering configuration based on category.
#       Examples:
#           - energy-price
#           - co2-emission
#   - directory:
#       Data will be used to evaluate how old the current data is.
#       Must be a valid path to a directory with files that `data-freshness-file` can parse.
#       Examples:
#           - ./
#           - data/
#   - timestamp:
#       Optional: timestamp to override the latest value
#       Examples:
#           - 1654041600
#           - 1701302400

# Output example:
# [
#   {
#     "zone": "DK2",
#     "latest": 1654041600
#   },
#   ...
# ]

CONFIG=$1
CATEGORY=$2
FOLDER=$3
OVERRIDEN=$([ -n "$4" ] && printf "%d" "$4" 2>/dev/null)

set -e
which dirname jq sed > /dev/null

SCRIPTS=$(dirname "$0")

[ -f "$CONFIG" ] || { echo "Not a file: $CONFIG"; exit 1; }
[ -z "$CATEGORY" ] && { echo "Missing capability"; exit 2; }
[ -d "$FOLDER" ] || { echo "Not a directory: $FOLDER"; exit 3; }
if [ "$OVERRIDEN" = "0" ] && [ -n "$4" ]; then
  echo "Not a number: $4"
  exit 4
fi

{
  printf '['
  jq -rc --arg category "$CATEGORY" '.[] | select(.capabilities | index($category) | .)' "$CONFIG" | while read -r ITEM; do
      AREA=$(echo "$ITEM" | jq -r '.zone')
      LATEST=$(sh "${SCRIPTS}/data-freshness.sh" "$FOLDER" "$AREA" 0)
      if [ -n "$OVERRIDEN" ]; then
        LATEST="$OVERRIDEN"
      fi
      printf "{\"zone\":\"%s\",\"latest\":%s}," "$AREA" "$LATEST"
  done
  printf ']'
} | sed 's|,]|]|g' | jq -r '.'
