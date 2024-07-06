# Setup
OLDPATH=$PATH
find /tmp/ -type f -exec rm {} +
find /tmp/ -type d -mindepth 1 -exec rmdir {} +
mkdir /tmp/empty-data-folder

# Test non-existing file
set +e
sh src/data-matrix.sh .non-existing-file.json energy-price /tmp/data/ > /dev/null
[ $? -eq 1 ] || exit 1

# Test missing capabillity
set +e
sh src/data-matrix.sh configuration/zones.json > /dev/null
[ $? -eq 2 ] || exit 1

# Test non-existing directory
set +e
sh src/data-matrix.sh configuration/zones.json energy-price /tmp/non-existing-directory/ > /dev/null
[ $? -eq 3 ] || exit 1

# Test invalid optional from timestamp
set +e
sh src/data-matrix.sh configuration/zones.json energy-price /tmp/empty-data-folder/ not-a-number 100 > /dev/null
[ $? -eq 4 ] || exit 1

# Test invalid optional end timestamp
set +e
sh src/data-matrix.sh configuration/zones.json energy-price /tmp/empty-data-folder/ 100 not-a-number > /dev/null
[ $? -eq 5 ] || exit 1

# Test invalid timestamps
set +e
sh src/data-matrix.sh configuration/zones.json energy-price /tmp/empty-data-folder/ 100 > /dev/null
[ $? -eq 6 ] || exit 1

# Test with no existing data that matrix contains all items from the configuration
set -e
export PATH=test/mocks/date/:$PATH
export DATE_OVERRIDE=100
sh src/data-matrix.sh configuration/zones.json energy-price /tmp/empty-data-folder/ | jq -r '.' > /tmp/result
jq -r 'map(reduce . as $item ({}; .zone = $item.zone | .latest = 0 | .end = 1209700))' configuration/zones.json > /tmp/expected
diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }
export PATH=$OLDPATH

# Test with mismatched capabillity that matrix is empty
set -e
sh src/data-matrix.sh configuration/zones.json not-a-thing test/fixtures/existing-data-write-output/ | jq -rc '.' > /tmp/result
echo '[]' > /tmp/expected
diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }

# Test with existing well-known data when it was fresh that matrix does not contain DK1 items from the configuration
set -e
export PATH=test/mocks/date/:$PATH
export DATE_OVERRIDE=100
printf '[{"zone": "DK1","capabilities": ["energy-price"]}]' > /tmp/config.json
printf '[{"zone":"DK1","latest":1654297200,"end":1209700}]\n' > /tmp/expected
sh src/data-matrix.sh /tmp/config.json energy-price test/fixtures/existing-data-write-output/ | jq -rc '.' > /tmp/result
diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }
export PATH=$OLDPATH

# Test with existing well-known data but with overriden timestamps
set -e
printf '[{"zone": "DK1","capabilities": ["energy-price"]}]' > /tmp/config.json
printf '[{"zone":"DK1","latest":1701302400,"end":1701302400}]\n' > /tmp/expected
sh src/data-matrix.sh /tmp/config.json energy-price test/fixtures/existing-data-write-output/ 1701302400 1701302400 | jq -rc '.' > /tmp/result
diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }
