#!/bin/sh

# Takes three arguments:
#   - filtered data file:
#       Must contain pricing data for network companies.
#       Examples:
#           - data.json
#           - data-for-DE.json
#   - grid config file:
#       Must contain grid pricing data for zone.
#       Examples:
#           - .config.json
#           - DE.json
#   - price area:
#       Data will be restricted to this price area.
#       Must be a singular valid area.
#       Examples:
#           - DK1
#           - DE

# Output example:
# {
#   "vat": 0.25,
#   "exchangeRate": 746,
#   "grid": [
#     {
#       "from": 1293836400,
#       "to": 1325372400,
#       "electricityCharge": 73.0,
#       "transmissionTariff": 4.5,
#       "systemTariff": 2.9
#     },
#     ...
#   ]
#   "network": [
#     {
#       "id": 4992492444,
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

INPUT=$1
CONFIG=$2
AREA=$3

[ -f "$INPUT" ] || { echo "Not a file: $INPUT"; exit 1; }
[ -f "$CONFIG" ] || { echo "Not a file: $CONFIG"; exit 2; }
AREA=$(echo "$AREA" | tr '[:lower:]' '[:upper:]')
[ -z "$AREA" ] && { echo "Invalid/Missing area."; exit 3; }

which jq > /dev/null

VAT=0.25
RATE=746

jq -r --arg vat "$VAT" --arg rate "$RATE" --arg zone "$AREA" -s '{vat: [{from: 0, to: null, vat: $vat|tonumber}], exchange: [{from: 0, to: null, rate: $rate|tonumber}], grid: .[0][$zone], network: .[1]}' "$CONFIG" "$INPUT"
