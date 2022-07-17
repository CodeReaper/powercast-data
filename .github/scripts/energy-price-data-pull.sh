#!/bin/sh

# Takes two arguments:
#   - price area:
#       Data will be restricted to this price area.
#       Must be a singular valid area.
#       Examples:
#           - DK1
#           - DE
#   - end date:
#       Data will be fetched until the end date is reached.
#       Must be a unix timestamp.
#       Example: 1654012800

# Output example:
# [
#   {
#     "euro": 133.7, // cost per MWh
#     "timestamp": 1654012800
#   },
#   ...
# ]

set -e

OFFSET=0
LIMIT=50
AREA=$1
ENDDATE=$2
DIR=/tmp/$$
ENDPOINT=https://api.energidataservice.dk/
QUERY="dataset/elspotprices?limit=${LIMIT}&sort=HourUTC%20desc&columns=HourUTC,PriceArea,SpotPriceEUR"

which mkdir wget jq cat date > /dev/null

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

CURSORDATE=$(date -d +14days +"%s")
TEMPLATE=$(echo "{\"PriceArea\":\"${AREA}\"}" | jq -r "@uri \"${ENDPOINT}${QUERY}&filter=\(.)\"")

echo '[]' > $DIR/data.json
while [ $CURSORDATE -gt $ENDDATE ]; do
    REQUEST="${TEMPLATE}&offset=${OFFSET}"

    wget -nv -O $DIR/request.json "${REQUEST}"

    TRANSFORMATION='.records |= map(.euro = .SpotPriceEUR | .timestamp = .HourUTC | del(.SpotPriceEUR, .HourUTC, .PriceArea)) | .records[].timestamp |= (split("+")[0] + "Z"|fromdateiso8601) | .records'
    cat $DIR/request.json | jq -r "$TRANSFORMATION" > $DIR/data.new.json
    jq -s '.[0] + .[1]' $DIR/data.json $DIR/data.new.json > $DIR/data.combined.json
    mv -f $DIR/data.combined.json $DIR/data.json

    CURSORDATE=$(cat $DIR/data.json | jq -r 'map(.timestamp | values) | min')
    OFFSET=$((OFFSET+LIMIT))

    if [ "$CURSORDATE" = "null" ]; then
        CURSORDATE=0
    fi
done

cat $DIR/data.json
