#!/bin/sh

# Takes two arguments:
#   - filtered data file:
#       Must contain pricing data for network companies.
#       Examples:
#           - data.json
#           - data-for-DE.json
#   - zone config file:
#       Must contain pricing data for zone.
#       Examples:
#           - .config.json
#           - DE.json

# Output example:
# {
#   "vat": 0.25,
#   "exchangeRate": 746,
#   "electricityNetwork": [
#     {
#       "from": 1293836400,
#       "to": 1325372400,
#       "electricityCharge": 73.0,
#       "transmissionTarrif": 4.5,
#       "systemTarrif": 2.9
#     },
#     ...
#   ]
#   "networkCompanies": [
#     {
#       "name": "N1 A/S",
#       "tariffs": [
#         {
#           "from": 1293836400,
#           "to": 1325372400,
#           "tariffs": [0.1101, ...] // 24 entries with hourly tariffs
#         }
#       ]
#     },
#     ...
#   ]
# }

set -e

DIR=/tmp/$$
INPUT=$1
CONFIG=$2

[ -f "$INPUT" ] || { echo "Not a file: $INPUT"; exit 1; }
[ -f "$CONFIG" ] || { echo "Not a file: $CONFIG"; exit 2; }

which mkdir jq > /dev/null

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

VAT=0.25
RATE=746

jq -r --arg vat "$VAT" --arg rate "$RATE" -s '{vat: $vat|tonumber, exchangeRate: $rate|tonumber, electricityNetwork: .[0], networkCompanies: .[1]}' "$CONFIG" "$INPUT"
