#!/bin/sh

# Takes three arguments:
#   - data file:
#       Must contain pricing data for network companies.
#       Examples:
#           - data.json
#           - data-for-zone.json
#   - network configuration file:
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
#     "id": 4992492444,
#     "name": "N1 A/S",
#     "tariffs": [
#       {
#         "from": 1293836400,
#         "to": 1325372400,
#         "tariffs": [0.1101, ...] // 24 entries with hourly tariffs
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

which mkdir jq > /dev/null

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

jq -rc --arg zone "$AREA" '.[$zone][]' < "$CONFIG" | while read -r ITEM; do
    [ -z "$ITEM" ] && continue

    id=$(echo "$ITEM" | jq -r '.gln')
    code=$(echo "$ITEM" | jq -r '.code')
    name=$(echo "$ITEM" | jq -r '.name')

    [ -z "$id" ] && continue
    [ -z "$code" ] && continue
    [ -z "$name" ] && continue

    CLEANUP='[.[] | del(.ChargeOwner, .GLN_Number, .ChargeType, .ChargeTypeCode, .Note, .Description, .VATClass, .TransparentInvoicing, .TaxIndicator, .ResolutionDuration)]'
    TRANSFORMATION='. |= map(.from = (.ValidFrom + "Z"|fromdateiso8601) | .to = if (.ValidTo|type) == "object" then null else (.ValidTo + "Z"|fromdateiso8601) end | del(.ValidFrom, .ValidTo))'
    UPDATE='[.[] | if (.Price2 == 0 and .Price3 == 0 and .Price4 == 0 and .Price5 == 0 and .Price6 == 0 and .Price7 == 0 and .Price8 == 0 and .Price9 == 0 and .Price10 == 0 and .Price11 == 0 and .Price12 == 0 and .Price13 == 0 and .Price14 == 0 and .Price15 == 0 and .Price16 == 0 and .Price17 == 0 and .Price18 == 0 and .Price19 == 0 and .Price20 == 0 and .Price21 == 0 and .Price22 == 0 and .Price23 == 0 and .Price24 == 0) then (. | .Price2 = .Price1 | .Price3 = .Price1 | .Price4 = .Price1 | .Price5 = .Price1 | .Price6 = .Price1 | .Price7 = .Price1 | .Price8 = .Price1 | .Price9 = .Price1 | .Price10 = .Price1 | .Price11 = .Price1 | .Price12 = .Price1 | .Price13 = .Price1 | .Price14 = .Price1 | .Price15 = .Price1 | .Price16 = .Price1 | .Price17 = .Price1 | .Price18 = .Price1 | .Price19 = .Price1 | .Price20 = .Price1 | .Price21 = .Price1 | .Price22 = .Price1 | .Price23 = .Price1 | .Price24 = .Price1) else . end]'
    MERGE='. |= map(.tariffs = [.Price1, .Price2, .Price3, .Price4, .Price5, .Price6, .Price7, .Price8, .Price9, .Price10, .Price11, .Price12, .Price13, .Price14, .Price15, .Price16, .Price17, .Price18, .Price19, .Price20, .Price21, .Price22, .Price23, .Price24] | del(.Price1, .Price2, .Price3, .Price4, .Price5, .Price6, .Price7, .Price8, .Price9, .Price10, .Price11, .Price12, .Price13, .Price14, .Price15, .Price16, .Price17, .Price18, .Price19, .Price20, .Price21, .Price22, .Price23, .Price24))'
    # shellcheck disable=SC2016
    GROUP='group_by(.tariffs) | . as $group | map(reduce .[] as $item ({}; .from = if (.from == null or $item.from < .from) then $item.from else .from end, .to = if (.to == null or $item.to > .to) then $item.to else .to end, .from = $item.from | .to = $item.to | .tariffs = $item.tariffs)) | if (. | length) > 0 then .[0].to = $group[0][0].to else . end'

    jq -r --arg id "$id" --arg code "$code" '[.[] | select(.GLN_Number == $id) | select(.ChargeType == "D03") | select(.ChargeTypeCode == $code)]' < "$INPUT" | \
    jq -r "$CLEANUP" | \
    jq -r "$TRANSFORMATION" | \
    jq -r "$UPDATE" | \
    jq -r "$MERGE" | \
    jq -r "$GROUP" | \
    jq -r --arg id "$id" --arg name "$name" '[{id: $id|tonumber, name: $name, tariffs: .}]' > "$DIR/$id.json"
done

jq -s add $DIR/*.json | jq -r
