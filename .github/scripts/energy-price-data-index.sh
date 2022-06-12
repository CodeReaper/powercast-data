#!/bin/sh

# Takes three arguments:
#   - config file:
#       Will be used to create matrix for generating data.
#       Examples:
#           - .config.json
#           - test.json
#   - directory:
#       Must be a valid path to a directory with data from `energy-price-data-write`.
#       Examples:
#           - ./
#           - data/
#   - prefix:
#       Optional, will be used to prefix each latest link.
#       Default is '/'. Must not end on '/'.
#       Example: /data

# Output example:
# [
#   {
#     "zone": "DK2",
#     "latest": "/data/2022/01/30/DK2.json",
#   },
#   ...
# ]


CONFIG=$1
FOLDER=$2
PREFIX=$3
DIR=/tmp/$$

set -e
which mkdir dirname grep cat jq tr sed > /dev/null

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

[ -f "$CONFIG" ] || { echo "Not a file: $CONFIG"; exit 1; }
[ -d "$FOLDER" ] || { echo "Not a directory: $FOLDER"; exit 2; }

set +e
echo "$PREFIX" | grep -vq /$
[ $? -eq 0 ] || { echo "Prefix cannot end on a '/'. Given: $PREFIX"; exit 3; }
set -e

echo -n '[' > $DIR/output.json
cat "$CONFIG" | jq -rc '.[] | del(.display)' | while read ITEM; do
    [ -z "$ITEM" ] && continue

    cd $FOLDER
    mkdir find-helper
    AREA=$(echo $ITEM | jq -r '.zone')
    LATEST=$(find * -type f -name "${AREA}.json" | sort | tail -n1)
    rmdir find-helper
    cd - > /dev/null

    [ -z "$LATEST" ] && continue

    echo -n "{\"latest\":\"${PREFIX}/${LATEST}\",\"zone\":\"${AREA}\"}," >> $DIR/output.json
done

echo -n ']' >> $DIR/output.json

cat $DIR/output.json | sed 's|,]|]|g' | jq -r '.'
