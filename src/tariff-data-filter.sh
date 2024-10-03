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
#   - network id:
#       Data will be restricted to this network id.
#       Examples:
#           - 5790000000000

# Output example:
# [
#   {
#     "from": 1293836400,
#     "to": 1325372400,
#     "tariffs": [0.1101, ...] // 24 entries with hourly tariffs
#   },
#   ...
# ]

set -e

DIR=/tmp/$$
INPUT=$1
CONFIG=$2
NETWORK=$3

[ -f "$INPUT" ] || { echo "Not a file: $INPUT"; exit 1; }
[ -f "$CONFIG" ] || { echo "Not a file: $CONFIG"; exit 2; }
[ -z "$NETWORK" ] && { echo "Missing network id."; exit 3; }

which mkdir jq > /dev/null

mkdir -p $DIR
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

FILTERED=$DIR/filtered.json
PARTS=$DIR/parts/
COMBINED=$DIR/combined.lines

mkdir $PARTS

jq -r --arg id "$NETWORK" '[.[] | select(.GLN_Number == $id and .ChargeType == "D03")]' < "$INPUT" > $FILTERED

jq -r --arg id "$NETWORK" '.[][] | select(.gln == ($id|tonumber)) | .codes[] | "\(.code)=\(.from)=\(.to)"' < "$CONFIG" | while IFS='=' read -r CODE FROM TO; do
  TRANSFORMATION='. |= map(.from = (.ValidFrom + "Z"|fromdateiso8601) | .to = if .ValidTo == null or (.ValidTo|type) == "object" then null else (.ValidTo + "Z"|fromdateiso8601) end)'
  UPDATE='[.[] | if (.Price2|type) == "object" or (.Price2 == 0 and .Price3 == 0 and .Price4 == 0 and .Price5 == 0 and .Price6 == 0 and .Price7 == 0 and .Price8 == 0 and .Price9 == 0 and .Price10 == 0 and .Price11 == 0 and .Price12 == 0 and .Price13 == 0 and .Price14 == 0 and .Price15 == 0 and .Price16 == 0 and .Price17 == 0 and .Price18 == 0 and .Price19 == 0 and .Price20 == 0 and .Price21 == 0 and .Price22 == 0 and .Price23 == 0 and .Price24 == 0) then (. | .Price2 = .Price1 | .Price3 = .Price1 | .Price4 = .Price1 | .Price5 = .Price1 | .Price6 = .Price1 | .Price7 = .Price1 | .Price8 = .Price1 | .Price9 = .Price1 | .Price10 = .Price1 | .Price11 = .Price1 | .Price12 = .Price1 | .Price13 = .Price1 | .Price14 = .Price1 | .Price15 = .Price1 | .Price16 = .Price1 | .Price17 = .Price1 | .Price18 = .Price1 | .Price19 = .Price1 | .Price20 = .Price1 | .Price21 = .Price1 | .Price22 = .Price1 | .Price23 = .Price1 | .Price24 = .Price1) else . end]'
  # shellcheck disable=SC2016
  MERGE='. |= map(.tariffs = [.Price1, .Price2, .Price3, .Price4, .Price5, .Price6, .Price7, .Price8, .Price9, .Price10, .Price11, .Price12, .Price13, .Price14, .Price15, .Price16, .Price17, .Price18, .Price19, .Price20, .Price21, .Price22, .Price23, .Price24]) | map(. as $item | {from: $item.from, to: $item.to, tariffs: $item.tariffs})'
  CONVERT='[.[] | .tariffs[] |= (. * 1000000 | round / 10000)]'

  jq -r --arg code "$CODE" '[.[] | select(.ChargeTypeCode == $code)]' < "$FILTERED" | \
  jq -r "$TRANSFORMATION" | \
  jq -r "$UPDATE" | \
  jq -r "$MERGE" | \
  jq -r "$CONVERT" | \
  jq -r --arg from "$FROM" --arg to "$TO" '[.[] | select(.from >= ($from|tonumber) and if ($to == "null") then true else .to <= ($to|tonumber) end)]' > "$PARTS/$FROM"
done

jq -rcs 'add' "$PARTS"/* | jq -rc '. | sort_by(.from) | .[]' > "$COMBINED"

{
  printf '['
  while read -r ITEM; do
    from=$(echo "$ITEM" | jq -r '.from')
    to=$(echo "$ITEM" | jq -r '.to')
    indicator=$(echo "$ITEM" | jq -rc '.tariffs' | tr -d \[\]\,)

    if [ "$previous" = "" ]; then
      printf "{\"from\": %s," "$from"
    elif [ ! "$previous" = "$indicator" ]; then
      printf "\"to\": %s, \"tariffs\":%s}," "$from" "$tariffs"
      printf "{\"from\": %s," "$from"
    fi

    tariffs=$(echo "$ITEM" | jq -rc '.tariffs')
    previous=$indicator
  done < "$COMBINED"
  if [ -z "$tariffs" ]; then
    printf ']'
  else
    printf "\"to\": %s, \"tariffs\":%s}]" "$to" "$tariffs"
  fi
} | jq -r reverse
