#!/bin/sh

# Setup
OLDPATH="$PATH"
find /tmp/t/ -type f -exec rm {} +
find /tmp/t/ -type d -mindepth 1 -exec rm -rf {} +
mkdir /tmp/t/empty-data-folder

# Test non-existing file
set +e
sh src/data-matrix.sh .non-existing-file.json energy-price /tmp/t/data/ > /dev/null
[ $? -eq 1 ] || exit 1

# Test missing capabillity
set +e
sh src/data-matrix.sh configuration/zones.json > /dev/null
[ $? -eq 2 ] || exit 1

# Test non-existing directory
set +e
sh src/data-matrix.sh configuration/zones.json energy-price /tmp/t/non-existing-directory/ > /dev/null
[ $? -eq 3 ] || exit 1

# Test invalid optional from timestamp
set +e
sh src/data-matrix.sh configuration/zones.json energy-price /tmp/t/empty-data-folder/ not-a-number 100 > /dev/null
[ $? -eq 4 ] || exit 1

# Test invalid optional end timestamp
set +e
sh src/data-matrix.sh configuration/zones.json energy-price /tmp/t/empty-data-folder/ 100 not-a-number > /dev/null
[ $? -eq 5 ] || exit 1

# Test invalid timestamps
set +e
sh src/data-matrix.sh configuration/zones.json energy-price /tmp/t/empty-data-folder/ 100 > /dev/null
[ $? -eq 6 ] || exit 1

# Test with no existing data that matrix contains all items from the configuration
set -e
export PATH="test/mocks/date/:$PATH"
export DATE_OVERRIDE=100
sh src/data-matrix.sh configuration/zones.json energy-price /tmp/t/empty-data-folder/ | jq -r '.' > /tmp/t/result
jq -r 'map(reduce . as $item ({}; .zone = $item.zone | .latest = 0 | .end = 1209700))' configuration/zones.json > /tmp/t/expected
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }
export PATH="$OLDPATH"

# Test with mismatched capabillity that matrix is empty
set -e
sh src/data-matrix.sh configuration/zones.json not-a-thing test/fixtures/existing-data-write-output/ | jq -rc '.' > /tmp/t/result
echo '[]' > /tmp/t/expected
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with existing well-known data when it was fresh that matrix does not contain DK1 items from the configuration
set -e
export PATH="test/mocks/date/:$PATH"
export DATE_OVERRIDE=100
printf '[{"zone": "DK1","capabilities": ["energy-price"]}]' > /tmp/t/config.json
printf '[{"zone":"DK1","latest":1654297200,"end":1209700}]\n' > /tmp/t/expected
sh src/data-matrix.sh /tmp/t/config.json energy-price test/fixtures/existing-data-write-output/ | jq -rc '.' > /tmp/t/result
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }
export PATH="$OLDPATH"

# Test with existing well-known data but with overriden timestamps
set -e
printf '[{"zone": "DK1","capabilities": ["energy-price"]}]' > /tmp/t/config.json
printf '[{"zone":"DK1","latest":1701302400,"end":1701302400}]\n' > /tmp/t/expected
sh src/data-matrix.sh /tmp/t/config.json energy-price test/fixtures/existing-data-write-output/ 1701302400 1701302400 | jq -rc '.' > /tmp/t/result
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with multiple uneven well-known data that matrix contains DK1 and DK2 items with different lastest values
set -e
export PATH="test/mocks/date/:$PATH"
export DATE_OVERRIDE=100
printf '[{"zone": "DK1","capabilities": ["energy-price"]},{"zone": "DK2","capabilities": ["energy-price"]}]' > /tmp/t/config.json
printf '[{"zone":"DK1","latest":1654297200,"end":1209700},{"zone":"DK2","latest":1654210800,"end":1209700}]\n' > /tmp/t/expected
sh src/data-matrix.sh /tmp/t/config.json energy-price test/fixtures/uneven-existing-data-write-output/ | jq -rc '.' > /tmp/t/result
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }
export PATH="$OLDPATH"
