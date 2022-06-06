#!/bin/sh

set -e

FILE=$1
FOLDER=$2
AREA=$3
DIR=/tmp/$$

which mkdir jq cat > /dev/null

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

[ -f "$FILE" ] || { echo "Not a file: $FILE"; exit 1; }
[ -d "$FOLDER" ] || { echo "Not a directory: $FOLDER"; exit 2; }


