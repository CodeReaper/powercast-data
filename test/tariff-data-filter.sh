# Setup
find /tmp/ -type f -exec rm {} +
find /tmp/ -type d -mindepth 1 -exec rmdir {} +
touch /tmp/data.json

cat << EOF > /tmp/config.json
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

cat << EOF > /tmp/multi-code-config.json
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

sh src/tariff-data-filter.sh /tmp/data.json > /dev/null
[ $? -eq 2 ] || exit 1

sh src/tariff-data-filter.sh /tmp/data.json /tmp/config.json > /dev/null
[ $? -eq 3 ] || exit 1

# Test with non-existing files
set +e

sh src/tariff-data-filter.sh not-found.json /tmp/config.json 5790001089030 > /dev/null
[ $? -eq 1 ] || exit 1

sh src/tariff-data-filter.sh /tmp/data.json not-found.json 5790001089030 > /dev/null
[ $? -eq 2 ] || exit 1

# Test with no existing data that filter outputs no data
set -e

echo '[]' > /tmp/empty.json

sh src/tariff-data-filter.sh /tmp/empty.json /tmp/config.json 5790001089030 > /tmp/result

echo '[]' | jq -r > /tmp/expected
diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }

# Test with existing data that filter outputs as expected
set -e

cp test/fixtures/tariff-data-filter-input.json /tmp/known-data.json
cp test/fixtures/tariff-data-filter-output.json /tmp/expected

sh src/tariff-data-filter.sh /tmp/known-data.json /tmp/config.json 5790001089030 > /tmp/result

diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }

# Test with existing data with id containing spaces that filter outputs as expected
set -e

cp test/fixtures/tariff-data-filter-input-spaces.json /tmp/known-data.json
cp test/fixtures/tariff-data-filter-output.json /tmp/expected

sh src/tariff-data-filter.sh /tmp/known-data.json /tmp/config.json 5790001089999 > /tmp/result

diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }

# Test with existing repeated data that filter outputs as expected
set -e

cp test/fixtures/tariff-data-filter-input-repeated.json /tmp/known-data.json
cp test/fixtures/tariff-data-filter-output.json /tmp/expected

sh src/tariff-data-filter.sh /tmp/known-data.json /tmp/config.json 5790001089030 > /tmp/result

diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }

# Test with existing repeated data with set end date that filter outputs as expected
set -e

cp test/fixtures/tariff-data-filter-input-repeated-nonnull.json /tmp/known-data.json
cp test/fixtures/tariff-data-filter-output-nonnull.json /tmp/expected

sh src/tariff-data-filter.sh /tmp/known-data.json /tmp/config.json 5790001089030 > /tmp/result

diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }

# Test with existing unpackable repeated data that filter outputs as expected
set -e

cp test/fixtures/tariff-data-filter-input-repeated-unpackable.json /tmp/known-data.json
cp test/fixtures/tariff-data-filter-output-unpackable.json /tmp/expected

sh src/tariff-data-filter.sh /tmp/known-data.json /tmp/config.json 5790001089030 > /tmp/result

diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }

# Test with multi code network data that filter outputs as expected
set -e

cp test/fixtures/tariff-data-filter-input-multi-code.json /tmp/known-data.json
cp test/fixtures/tariff-data-filter-output.json /tmp/expected

sh src/tariff-data-filter.sh /tmp/known-data.json /tmp/multi-code-config.json 5790001089030 > /tmp/result

diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }

# Test with multi code network data with none matching that filter outputs as expected
set -e

cp test/fixtures/tariff-data-filter-input-multi-code-no-matches.json /tmp/known-data.json
echo '[]' | jq -r > /tmp/expected

sh src/tariff-data-filter.sh /tmp/known-data.json /tmp/multi-code-config.json 5790001089030 > /tmp/result

diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }

# Test with sloppy multi code network data that filter outputs as expected
set -e

cp test/fixtures/tariff-data-filter-input-sloppy-multi-code.json /tmp/known-data.json
cp test/fixtures/tariff-data-filter-output.json /tmp/expected

sh src/tariff-data-filter.sh /tmp/known-data.json /tmp/multi-code-config.json 5790001089030 > /tmp/result

diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }
