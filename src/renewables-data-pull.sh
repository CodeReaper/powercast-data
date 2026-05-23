#!/bin/sh

# Takes two arguments:
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
#     "zone": "DK1",
#     "timestamp": 1654012800,
#     "sources": [
#       {
#         "type":"solar",
#         "energy":3456.0 // MWh
#       },
#       ...
#     ]
#   },
#   ...
# ]

set -e

OFFSET=0
LIMIT=100000
FROMDATE=$1
ENDDATE=$2
DIR=/tmp/$$
ENDPOINT=https://api.energidataservice.dk/
TEMPLATE="${ENDPOINT}dataset/forecasts_hour?limit=${LIMIT}&sort=HourUTC%20desc&columns=HourUTC,PriceArea,ForecastType,ForecastDayAhead&start=$(date -d "@$FROMDATE" +"%Y-%m-%dT%H:%M")&end=$(date -d "@$ENDDATE" +"%Y-%m-%dT%H:%M")&timezone=UTC"

which mkdir wget jq cat date > /dev/null

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

echo '[]' > $DIR/data.json
while true; do
    REQUEST="${TEMPLATE}&offset=${OFFSET}"

    wget -nv -O $DIR/request.json "${REQUEST}"

    # shellcheck disable=SC2016
    TRANSFORMATION='.records |= map(. as $item | {zone: $item.PriceArea, type: ($item.ForecastType | ascii_downcase), energy: (if ($item.ForecastDayAhead == null) then 0 else ($item.ForecastDayAhead * 100 | round) / 100 end), timestamp: $item.HourUTC}) | .records[].timestamp |= (split("+")[0] + "Z"|fromdateiso8601) | .records | group_by(.zone, .timestamp) | map({zone: .[0].zone, timestamp: .[0].timestamp, sources: [.[] | del(.zone, .timestamp)] })'
    cat $DIR/request.json | jq -r "$TRANSFORMATION" > $DIR/data.new.json

    jq -e 'if . == [] then false else true end' < $DIR/data.new.json > /dev/null || break

    jq -s '.[0] + .[1]' $DIR/data.json $DIR/data.new.json > $DIR/data.combined.json
    mv -f $DIR/data.combined.json $DIR/data.json

    OFFSET=$((OFFSET+LIMIT))
done

cat $DIR/data.json
