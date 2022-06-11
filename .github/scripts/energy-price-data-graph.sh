#!/bin/sh

# Takes three arguments:
#   - config file:
#       Will be used to determine what to generate graphs for.
#       Examples:
#           - .config.json
#           - test.json
#   - directory:
#       Must be a valid path to a directory with data from `energy-price-data-write`.
#       Examples:
#           - ./
#           - data/
#   - cut off date:
#       Will limit the output to this date per configured zone.
#       Must be a unix timestamp.
#       Example: 1654012800

# Output example:
# "HTML" that can display graphs

CONFIG=$1
FOLDER=$2
ENDDATE=$3
DIR=/tmp/$$

set -e
which jq tr > /dev/null

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

[ -f "$CONFIG" ] || { echo "Not a file: $CONFIG"; exit 1; }
[ -d "$FOLDER" ] || { echo "Not a directory: $FOLDER"; exit 2; }
[ -z "$ENDDATE" ] && { echo "Not a valid number: $ENDDATE"; exit 3; }

echo "const data = { datasets: [" > $DIR/result.json

cat "$CONFIG" | jq -rc '.[]' | while read ITEM; do
    AREA=$(echo $ITEM | jq -r '.zone')
    COLOR=$(echo $ITEM | jq -r '.color')

    cd $FOLDER
    echo '[]' > $DIR/data.json
    mkdir find-helper
    find * -type f -name "${AREA}.json" | sort -r | while read FILE; do
        [ -f "$FILE" ] || continue

        jq -s ".[0] + .[1] | map(select(.timestamp >= $ENDDATE))" $DIR/data.json $FILE > $DIR/data.combined.json
        mv -f $DIR/data.combined.json $DIR/data.json

        LENGTH=$(cat $DIR/data.json | jq -r 'length')
        if [ $LENGTH -eq 0 ]; then
            break
        fi

    done
    rmdir find-helper
    cd - > /dev/null

    LENGTH=$(cat $DIR/data.json | jq -r 'length')
    if [ $LENGTH -eq 0 ]; then
        continue
    fi

    echo "  {" >> $DIR/result.json
    echo "    label: \"${AREA}\"," >> $DIR/result.json
    echo -n "    data: " >> $DIR/result.json
    cat $DIR/data.json | jq -rc ". |= map(.x = .timestamp | .y = .euro | del(.timestamp, .euro)) | sort_by(.x)" | tr -d \\n >> $DIR/result.json
    echo ".map((e) => ({x:e.x *= 1000, y:e.y}))," >> $DIR/result.json
    echo "    pointBackgroundColor: \"${COLOR}\", backgroundColor: \"${COLOR}\", borderColor: \"${COLOR}\"," >> $DIR/result.json
    echo '  },' >> $DIR/result.json

done

echo '] };' >> $DIR/result.json

cat $DIR/result.json
