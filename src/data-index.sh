#!/bin/sh

# Takes three arguments:
#   - config file:
#       Will be used to create matrix for generating data.
#       Examples:
#           - .config.json
#           - test.json
#   - directory:
#       Must be a valid path to a directory with data files.
#       Examples:
#           - ./
#           - data/
#   - prefix:
#       Will be used to prefix each latest link.
#       Must not end on '/'.
#       Example:
#           - /
#           - /data
#   - mode:
#       Changes which files to search for.
#       Options:
#           - with-zone
#           - with-index

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
MODE=$4
DIR=/tmp/$$

set -e
which mkdir dirname grep cat jq tr sed > /dev/null

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

[ -f "$CONFIG" ] || { echo "Not a file: $CONFIG"; exit 1; }
[ -d "$FOLDER" ] || { echo "Not a directory: $FOLDER"; exit 2; }

set +e
[ -z "$PREFIX" ] && { echo "Prefix missing"; exit 3; }
if ! echo "$PREFIX" | grep -vq /$; then
    echo "Prefix cannot end on a '/'. Given: $PREFIX";
    exit 3;
fi

if [ ! "$MODE" = "with-index" ] && [ ! "$MODE" = "with-zone" ]; then
    echo "Modes can only be 'with-zone' or 'with-index'. Given: $MODE";
    exit 4;
fi

set -e

printf '[' > $DIR/output.json
jq -rc '.[]' "$CONFIG" | while read -r ITEM; do
    [ -z "$ITEM" ] && continue

    cd "$FOLDER"
    AREA=$(echo "$ITEM" | jq -r '.zone')
    if [ "$MODE" = "with-zone" ]; then
      find -- * -type f -mindepth 3 -name "${AREA}.json" | sort > "$DIR/found"
    else
      find -- * -type d -mindepth 3 -name "${AREA}" | sort > "$DIR/found"
    fi

    LATEST=$(tail -n1 < $DIR/found)
    OLDEST=$(head -n1 < $DIR/found)
    cd - > /dev/null

    [ -z "$LATEST" ] && continue
    [ -z "$OLDEST" ] && continue

    printf "{\"latest\":\"%s\",\"oldest\":\"%s\",\"zone\":\"%s\"}," "$PREFIX/$LATEST" "$PREFIX/$OLDEST" "$AREA" >> $DIR/output.json
done

printf ']' >> $DIR/output.json

cat $DIR/output.json | sed 's|,]|]|g' | jq -r '.'
