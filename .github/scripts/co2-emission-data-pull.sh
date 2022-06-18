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
#     "timestamp": 1654012800,
#     "co2": 42 // in g/kWh
#   },
#   ...
# ]

set -e

AREA=$1
ENDDATE=$2
DIR=/tmp/$$
ENDPOINT=https://api.energidataservice.dk/
QUERY="datastore_search?resource_id=co2emisprog&limit=50&sort=Minutes5UTC%20desc&fields=Minutes5UTC,PriceArea,CO2Emission&include_total=false&records_format=objects"

which mkdir wget jq cat date > /dev/null

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

CURSORDATE=$(date -d +14days +"%s")
REQUEST=$(echo "{\"filters\":{\"PriceArea\":\"${AREA}\"}}" | jq -r "@uri \"${ENDPOINT}${QUERY}&filters=\(.filters)\"")

echo '[]' > $DIR/data.json
while [ $CURSORDATE -gt $ENDDATE ]; do
    wget -nv -O $DIR/request.json "${REQUEST}"

    TRANSFORMATION='.result.records |= map(.co2 = .CO2Emission | .timestamp = .Minutes5UTC | del(.Minutes5UTC, .CO2Emission, .PriceArea)) | .result.records[].timestamp |= (split("+")[0] + "Z"|fromdateiso8601) | .result.records'
    cat $DIR/request.json | jq -r "$TRANSFORMATION" > $DIR/data.new.json
    jq -s '.[0] + .[1]' $DIR/data.json $DIR/data.new.json > $DIR/data.combined.json
    mv -f $DIR/data.combined.json $DIR/data.json

    CURSORDATE=$(cat $DIR/data.json | jq -r 'map(.timestamp | values) | min')
    REQUEST=${ENDPOINT}$(cat $DIR/request.json | jq -r '.result._links.next')

    if [ "$CURSORDATE" = "null" ]; then
        CURSORDATE=0
    fi
done

cat $DIR/data.json
