#!/bin/sh

# Setup
find /tmp/t/ -type f -exec rm {} +
find /tmp/t/ -type d -mindepth 1 -exec rmdir {} +
touch /tmp/t/data.json

cat << EOF > /tmp/t/config.json
{
  "DK1": [
    {
      "name": "N1 A/S",
      "gln": 5790001089030,
      "codes": [
        {
          "from": 0,
          "to": null,
          "code": "CD"
        }
      ]
    },
    {
      "name": "SPACE A/S",
      "gln": 5790001089999,
      "codes": [
        {
          "from": 0,
          "to": null,
          "code": "S P A C E S"
        }
      ]
    }
  ]
}
EOF

cat << EOF > /tmp/t/multi-code-config.json
{
  "DK1": [
    {
      "name": "N1 A/S",
      "gln": 5790001089030,
      "codes": [
        {
          "from": 0,
          "to": 1704067200,
          "code": "DC"
        },
        {
          "from": 1704067200,
          "to": null,
          "code": "CD"
        }
      ]
    }
  ]
}
EOF

# Test with too few arguments
set +e
sh src/tariff-data-filter.sh > /dev/null
[ $? -eq 1 ] || exit 1

sh src/tariff-data-filter.sh /tmp/t/data.json > /dev/null
[ $? -eq 2 ] || exit 1

sh src/tariff-data-filter.sh /tmp/t/data.json /tmp/t/config.json > /dev/null
[ $? -eq 3 ] || exit 1

# Test with non-existing files
set +e
sh src/tariff-data-filter.sh not-found.json /tmp/t/config.json 5790001089030 > /dev/null
[ $? -eq 1 ] || exit 1

sh src/tariff-data-filter.sh /tmp/t/data.json not-found.json 5790001089030 > /dev/null
[ $? -eq 2 ] || exit 1

# Test with no existing data that filter outputs no data
set -e
echo '[]' > /tmp/t/empty.json

sh src/tariff-data-filter.sh /tmp/t/empty.json /tmp/t/config.json 5790001089030 > /tmp/t/result

echo '[]' | jq -r > /tmp/t/expected
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with existing data that filter outputs as expected
set -e
cp test/fixtures/tariff-data-filter-input.json /tmp/t/known-data.json
cp test/fixtures/tariff-data-filter-output.json /tmp/t/expected

sh src/tariff-data-filter.sh /tmp/t/known-data.json /tmp/t/config.json 5790001089030 > /tmp/t/result

diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with existing data with id containing spaces that filter outputs as expected
set -e
cp test/fixtures/tariff-data-filter-input-spaces.json /tmp/t/known-data.json
cp test/fixtures/tariff-data-filter-output.json /tmp/t/expected

sh src/tariff-data-filter.sh /tmp/t/known-data.json /tmp/t/config.json 5790001089999 > /tmp/t/result

diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with existing repeated data that filter outputs as expected
set -e
cp test/fixtures/tariff-data-filter-input-repeated.json /tmp/t/known-data.json
cp test/fixtures/tariff-data-filter-output.json /tmp/t/expected

sh src/tariff-data-filter.sh /tmp/t/known-data.json /tmp/t/config.json 5790001089030 > /tmp/t/result

diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with existing repeated data with set end date that filter outputs as expected
set -e
cp test/fixtures/tariff-data-filter-input-repeated-nonnull.json /tmp/t/known-data.json
cp test/fixtures/tariff-data-filter-output-nonnull.json /tmp/t/expected

sh src/tariff-data-filter.sh /tmp/t/known-data.json /tmp/t/config.json 5790001089030 > /tmp/t/result

diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with existing unpackable repeated data that filter outputs as expected
set -e
cp test/fixtures/tariff-data-filter-input-repeated-unpackable.json /tmp/t/known-data.json
cp test/fixtures/tariff-data-filter-output-unpackable.json /tmp/t/expected

sh src/tariff-data-filter.sh /tmp/t/known-data.json /tmp/t/config.json 5790001089030 > /tmp/t/result

diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with multi code network data that filter outputs as expected
set -e
cp test/fixtures/tariff-data-filter-input-multi-code.json /tmp/t/known-data.json
cp test/fixtures/tariff-data-filter-output.json /tmp/t/expected

sh src/tariff-data-filter.sh /tmp/t/known-data.json /tmp/t/multi-code-config.json 5790001089030 > /tmp/t/result

diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with multi code network data with none matching that filter outputs as expected
set -e
cp test/fixtures/tariff-data-filter-input-multi-code-no-matches.json /tmp/t/known-data.json
echo '[]' | jq -r > /tmp/t/expected

sh src/tariff-data-filter.sh /tmp/t/known-data.json /tmp/t/multi-code-config.json 5790001089030 > /tmp/t/result

diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with sloppy multi code network data that filter outputs as expected
set -e
cp test/fixtures/tariff-data-filter-input-sloppy-multi-code.json /tmp/t/known-data.json
cp test/fixtures/tariff-data-filter-output.json /tmp/t/expected

sh src/tariff-data-filter.sh /tmp/t/known-data.json /tmp/t/multi-code-config.json 5790001089030 > /tmp/t/result

diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with existing data with true nulls in valid to property that filter outputs as expected
set -e
cp test/fixtures/tariff-data-filter-input-with-nulls.json /tmp/t/known-data.json
cp test/fixtures/tariff-data-filter-output.json /tmp/t/expected

sh src/tariff-data-filter.sh /tmp/t/known-data.json /tmp/t/config.json 5790001089030 > /tmp/t/result

diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with existing data with true nulls in prices that filter outputs as expected
set -e
cp test/fixtures/tariff-data-filter-input-single-price.json /tmp/t/known-data.json
cp test/fixtures/tariff-data-filter-output-single-price.json /tmp/t/expected

sh src/tariff-data-filter.sh /tmp/t/known-data.json /tmp/t/config.json 5790001089030 > /tmp/t/result

diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }