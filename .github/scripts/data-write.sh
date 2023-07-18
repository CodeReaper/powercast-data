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
DIR=/tmp/$$

which mkdir jq tr cut dirname > /dev/null

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

[ -f "$FILE" ] || { echo "Not a file: $FILE"; exit 1; }
[ -d "$FOLDER" ] || { echo "Not a directory: $FOLDER"; exit 2; }
AREA=$(echo "$AREA" | tr '[:lower:]' '[:upper:]')
[ -z "$AREA" ] && { echo "Invalid/Missing area."; exit 3; }

jq -rc '.[]' "$FILE" | while read -r ITEM; do
    echo "[" > $DIR/item.json
    echo "$ITEM" >> $DIR/item.json
    echo "]" >> $DIR/item.json

    DATE=$(echo "$ITEM" | jq -r '.timestamp | todate' | cut -dT -f1)
    YEAR=$(echo "$DATE" | cut -d- -f1)
    MONTH=$(echo "$DATE" | cut -d- -f2)
    DAY=$(echo "$DATE" | cut -d- -f3)
    DESTINATION="${FOLDER}/${YEAR}/${MONTH}/${DAY}/${AREA}.json"

    mkdir -p "$(dirname "$DESTINATION")"
    if [ ! -f "$DESTINATION" ]; then
        echo '[]' > "$DESTINATION"
    fi
    jq -s '.[1] + .[0] | unique_by(.timestamp) | sort_by(.timestamp)' "$DIR/item.json" "$DESTINATION" > "$DIR/combined.json"
    mv -f "$DIR/combined.json" "$DESTINATION"
done
