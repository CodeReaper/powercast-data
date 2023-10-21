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

which mkdir jq cat > /dev/null

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

exit 1 # FIXME below

echo '[]' > $DIR/data.json
while [ "$CURSORDATE" -gt "$ENDDATE" ]; do
    REQUEST="${TEMPLATE}&offset=${OFFSET}"

    wget -nv -O $DIR/request.json "${REQUEST}"

    TRANSFORMATION='.records |= map(.type = (.ForecastType | ascii_downcase) | .energy = if (.ForecastDayAhead == null) then 0 else (.ForecastDayAhead * 100 | round) / 100 end | .timestamp = .HourUTC | del(.ForecastType, .ForecastDayAhead, .HourUTC, .PriceArea)) | .records[].timestamp |= (split("+")[0] + "Z"|fromdateiso8601) | .records | group_by(.timestamp) | map({ timestamp: (.[0].timestamp), sources: [.[] | del(.timestamp)] })'
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
