#!/bin/sh

# Takes three arguments:
#   - price area:
#       Data will be restricted to this price area.
#       Must be a singular valid area.
#       Examples:
#           - DK1
#           - DE
#   - from date:
#       Data will be fetched between the from and end date.
#       Must be a unix timestamp.
#       Example: 1654012800
#   - end date:
#       Data will be fetched between the from and end date.
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
LIMIT=100
AREA=$1
FROMDATE=$2
ENDDATE=$3
DIR=/tmp/$$
ENDPOINT=https://api.energidataservice.dk/
QUERY="dataset/DayAheadPrices?limit=${LIMIT}&sort=TimeUTC%20desc&columns=TimeUTC,PriceArea,DayAheadPriceEUR&start=$(date -d "@$FROMDATE" +"%Y-%m-%dT%H:%M")&end=$(date -d "@$ENDDATE" +"%Y-%m-%dT%H:%M")&timezone=UTC"

which mkdir wget jq cat date > /dev/null

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

TEMPLATE=$(echo "{\"PriceArea\":\"${AREA}\"}" | jq -r "@uri \"${ENDPOINT}${QUERY}&filter=\(.)\"")

echo '[]' > $DIR/data.json
while true; do
    REQUEST="${TEMPLATE}&offset=${OFFSET}"

    wget -nv -O $DIR/request.json "${REQUEST}"

    # shellcheck disable=SC2016
    TRANSFORMATION='.records |= map(. as $item | {euro: $item.DayAheadPriceEUR, timestamp: $item.TimeUTC}) | .records[].timestamp |= (split("+")[0] + "Z"|fromdateiso8601) | .records'
    cat $DIR/request.json | jq -r "$TRANSFORMATION" > $DIR/data.new.json

    jq -e 'if . == [] then false else true end' < $DIR/data.new.json > /dev/null || break

    jq -s '.[0] + .[1]' $DIR/data.json $DIR/data.new.json > $DIR/data.combined.json
    mv -f $DIR/data.combined.json $DIR/data.json

    OFFSET=$((OFFSET+LIMIT))
done

cat $DIR/data.json
