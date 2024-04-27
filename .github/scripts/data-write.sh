#!/bin/sh

# Takes three arguments:
#   - file:
#       This file should contain data that `data-freshness-file` can parse.
#       Example: ./new-data.json
#   - directory:
#       The directory in which to write output files.
#       Examples:
#           - ./
#           - data/
#   - price area:
#       Data will be written as this price area to directory.
#       Must be a singular area.
#       Examples:
#           - DK1
#           - DE

# There is no output, but data will be written to files in directory/year/month/day/area.json

set -e

FILE=$1
FOLDER=$2
AREA=$3

which mkdir jq tr cut dirname > /dev/null

[ -f "$FILE" ] || { echo "Not a file: $FILE"; exit 1; }
[ -d "$FOLDER" ] || { echo "Not a directory: $FOLDER"; exit 2; }
AREA=$(echo "$AREA" | tr '[:lower:]' '[:upper:]')
[ -z "$AREA" ] && { echo "Invalid/Missing area."; exit 3; }

jq -rc '.[] | .data = . | .date = (.timestamp | todate) | .date, .data' "$FILE" | while read -r DATE; do
    read -r ITEM
    TIME=$(echo "$DATE" | cut -dT -f2 | cut -d ':' -f1-2 | sed s/://g)
    DATE=$(echo "$DATE" | cut -dT -f1)
    YEAR=$(echo "$DATE" | cut -d- -f1)
    MONTH=$(echo "$DATE" | cut -d- -f2)
    DAY=$(echo "$DATE" | cut -d- -f3)
    DESTINATION="${FOLDER}/${YEAR}/${MONTH}/${DAY}/${AREA}-${TIME}.json"

    if [ ! -d "${FOLDER}/${YEAR}/${MONTH}/${DAY}" ]; then
        mkdir -p "$(dirname "$DESTINATION")"
    fi
    echo "$ITEM" > "$DESTINATION"
done

for DESTINATION in "$FOLDER"/????/??/??; do
  [ -d "$DESTINATION" ] || continue
  ls "${DESTINATION}/${AREA}"-*.json >/dev/null 2>&1 || continue

  echo "doing: ${DESTINATION}/${AREA}.json"
  if [ -f "${DESTINATION}/${AREA}.json" ]; then
    find "${DESTINATION}" -type f -name "${AREA}-*.json" -print0 | xargs -0 jq -s '. | unique_by(.timestamp) | sort_by(.timestamp)' > /tmp/$$.data
    jq -s '.[1] + .[0] | unique_by(.timestamp) | sort_by(.timestamp)' /tmp/$$.data "${DESTINATION}/${AREA}.json" > /tmp/$$.json
  else
    find "${DESTINATION}" -type f -name "${AREA}-*.json" -print0 | xargs -0 jq -s '. | unique_by(.timestamp) | sort_by(.timestamp)' > /tmp/$$.json
  fi
  ls -lsh /tmp/$$.json
  mv /tmp/$$.json "${DESTINATION}/${AREA}.json"
  rm -v "${DESTINATION}/${AREA}"-*.json
done
