#!/bin/sh

# Takes two arguments:
#   - config file:
#       Will be used to generating graphs for all data.
#       Examples:
#           - .config.json
#           - test.json
#   - directory:
#       Must be a valid path to a directory with data from `energy-price-data-write`.
#       Examples:
#           - ./
#           - data/
#   - data points:
#       Will limit the output to this amount of data points per configured zone.
#       Optional, will default to 500
#       Must a positive number.
#       Examples:
#           - 10
#           - 105

# Output example:
# "HTML" that can display graphs

CONFIG=$1
FOLDER=$2
MAX_LENGTH=${3:-500}
DIR=/tmp/$$

set -e
which jq tr > /dev/null

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

[ -f "$CONFIG" ] || { echo "Not a file: $CONFIG"; exit 1; }
[ -d "$FOLDER" ] || { echo "Not a directory: $FOLDER"; exit 2; }
[ 0 -lt "$MAX_LENGTH" ] || { echo "Not a valid number: $MAX_LENGTH"; exit 3; }

echo "const data = { datasets: [" > $DIR/result.json

cat "$CONFIG" | jq -rc '.[]' | while read ITEM; do
    AREA=$(echo $ITEM | jq -r '.zone')
    COLOR=$(echo $ITEM | jq -r '.color')

    cd $FOLDER
    echo '[]' > $DIR/data.json
    find * -type f -name "${AREA}.json" | sort | while read FILE; do

        jq -s '.[0] + .[1]' $DIR/data.json $FILE > $DIR/data.combined.json
        mv -f $DIR/data.combined.json $DIR/data.json

        LENGTH=$(cat $DIR/data.json | jq -r 'length')
        if [ $LENGTH -gt $MAX_LENGTH ]; then
            break
        fi

    done
    cd - > /dev/null

    LENGTH=$(cat $DIR/data.json | jq -r 'length')
    if [ $LENGTH -eq 0 ]; then
        continue
    fi

    echo "  {" >> $DIR/result.json
    echo "    label: \"${AREA}\"," >> $DIR/result.json
    echo -n "    data: " >> $DIR/result.json
    cat $DIR/data.json | jq -rc ".[0:${MAX_LENGTH}] |= map(.x = .timestamp | .y = .euro | del(.timestamp, .euro))" | tr -d \\n >> $DIR/result.json
    echo ".map((e) => ({x:e.x *= 1000, y:e.y}))," >> $DIR/result.json
    echo "    pointBackgroundColor: \"${COLOR}\", backgroundColor: \"${COLOR}\"," >> $DIR/result.json
    echo '  },' >> $DIR/result.json

done

echo '] };' >> $DIR/result.json

cat $DIR/result.json
