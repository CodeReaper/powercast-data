#!/bin/sh

# Takes up to three arguments:
#   - config file:
#       Will be used to create matrix for generating data.
#       Examples:
#           - .config.json
#           - test.json
#   - directory:
#       Data will be used to evaluate how old the current data is.
#       Must be a valid path to a directory with data from `data-write`.
#       Examples:
#           - ./
#           - data/
#   - date:
#       Optional, will default to now.
#       Script will believe that "date" is now.
#       Must be a unix timestamp.
#       Example: 1654012800

# Output example:
# [
#   {
#     "zone": "DK2",
#     "endDate": 1654041600,
#     "expectedDelay": 286400
#   },
#   ...
# ]

CONFIG=$1
FOLDER=$2
CURRENTDATE=${3:-$(date +"%s")}
DIR=/tmp/$$

set -e
which mkdir dirname cat jq tr sed > /dev/null

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

SCRIPTS=$(dirname $0)

[ -f "$CONFIG" ] || { echo "Not a file: $CONFIG"; exit 1; }
[ -d "$FOLDER" ] || { echo "Not a directory: $FOLDER"; exit 2; }

cat "$CONFIG" | jq -rc '.' | tr -d []\\n | sed 's|}\,|}\n|g' > $DIR/inputs
echo >> $DIR/inputs
echo -n '[' > $DIR/matrix.json
cat $DIR/inputs | while read ITEM; do
    AREA=$(echo $ITEM | jq -r '.zone')
    ENDDATE=$(echo $ITEM | jq -r '.endDate')
    DELAY=$(echo $ITEM | jq -r '.expectedDelay')
    LATEST=$(sh "${SCRIPTS}/data-freshness.sh" "$FOLDER" "$AREA" "$ENDDATE")
    DIFFERENCE=$(($CURRENTDATE-$LATEST))
    if [ $DIFFERENCE -gt $DELAY ]; then
        echo -n "$ITEM" >> $DIR/matrix.json
        echo -n "," >> $DIR/matrix.json
    fi
done

echo -n ']' >> $DIR/matrix.json

cat $DIR/matrix.json | sed 's|,]|]|g' | jq -r '.'