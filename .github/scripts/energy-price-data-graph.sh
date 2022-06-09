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

# Output example:
# "HTML" that can display graphs

CONFIG=$1
FOLDER=$2
DIR=/tmp/$$

set -e
which mkdir dirname grep cat jq tr sed > /dev/null # TODO: check

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

[ -f "$CONFIG" ] || { echo "Not a file: $CONFIG"; exit 1; }
[ -d "$FOLDER" ] || { echo "Not a directory: $FOLDER"; exit 2; }


# READ CONFIG

# FETCH DATA BACK TO A POINT IN TIME

# MERGE AND TRANSFROM INTO EXAMPLE BELOW

cat << EOF
const data = {
    datasets: [
        {
            label: "DK1",
            data: [{x: 1654041600000, y: 199.09},{x: 1654045200000, y: 182.53},{x: 1654048800000, y:182.28}]
        },
        {
            label: "DK2",
            data: [{x: 1654041600000, y: 168.09},{x: 1654045200000, y: 161.53},{x: 1654048800000, y:147.28}]
        }
    ]
};
EOF