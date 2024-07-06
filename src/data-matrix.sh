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
#   - from timestamp:
#       Optional: timestamp to override the latest value, note this requires the end timestamp to be set
#       Examples:
#           - 1654041600
#           - 1701302400
#   - end timestamp:
#       Optional: timestamp to override the end value, note this requires the from timestamp to be set
#       Examples:
#           - 1654041600
#           - 1701302400

# Output example:
# [
#   {
#     "zone": "DK2",
#     "latest": 1654041600,
#     "end": 1654041600
#   },
#   ...
# ]

CONFIG=$1
CATEGORY=$2
FOLDER=$3
FROM=$([ -n "$4" ] && printf "%d" "$4" 2>/dev/null)
END=$([ -n "$5" ] && printf "%d" "$5" 2>/dev/null)

set -e
which dirname jq sed > /dev/null

SCRIPTS=$(dirname "$0")

[ -f "$CONFIG" ] || { echo "Not a file: $CONFIG"; exit 1; }
[ -z "$CATEGORY" ] && { echo "Missing capability"; exit 2; }
[ -d "$FOLDER" ] || { echo "Not a directory: $FOLDER"; exit 3; }
if [ "$FROM" = "0" ] && [ -n "$4" ]; then
  echo "Not a number: $4"
  exit 4
fi
if [ "$END" = "0" ] && [ -n "$5" ]; then
  echo "Not a number: $5"
  exit 5
fi
END=${END:-$(($(date +"%s")+1209600))}

# shellcheck disable=SC2166
if [ -z "$4" -a -n "$5" ] || [ -n "$4" -a -z "$5" ]; then
  exit 6
fi

jq -rc --arg category "$CATEGORY" '.[] | select(.capabilities | index($category) | .) | .zone' "$CONFIG" | while read -r AREA; do
  if [ -z "$FROM" ]; then
    FROM=$(sh "${SCRIPTS}/data-freshness.sh" "$FOLDER" "$AREA" 0)
  fi
  printf "{\"zone\":\"%s\",\"latest\":%s,\"end\":%s}\n" "$AREA" "$FROM" "$END"
done | jq -src '.'
