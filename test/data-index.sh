# Setup
find /tmp/ -type f -exec rm {} +
find /tmp/ -type d -mindepth 1 -exec rmdir {} +
mkdir /tmp/empty-data-folder

# Test non-existing file
set +e
sh src/data-index.sh .non-existing-file.json /tmp/empty-data-folder > /dev/null
[ $? -eq 1 ] || exit 1

# Test non-existing directory
set +e
sh src/data-index.sh configuration/zones.json /tmp/non-existing-directory/ > /dev/null
[ $? -eq 2 ] || exit 1

# Test missing prefix
set +e
sh src/data-index.sh configuration/zones.json /tmp/empty-data-folder > /dev/null
[ $? -eq 3 ] || exit 1

# Test incorrect prefix
set +e
sh src/data-index.sh configuration/zones.json /tmp/empty-data-folder /prefix/ > /dev/null
[ $? -eq 3 ] || exit 1

# Test with no existing data that index outputs no data
set -e
sh src/data-index.sh configuration/zones.json /tmp/empty-data-folder/ /prefix | jq -r '.' > /tmp/result
echo '[]' > /tmp/expected
diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }

# Test with existing well-known data index outputs as expected
set -e
sh src/data-index.sh configuration/zones.json test/fixtures/existing-data-write-output/ /data | jq -r '.' > /tmp/result
diff -q test/fixtures/data-index-generated-output.json /tmp/result || { echo "Unexpected difference:"; diff test/fixtures/data-index-generated-output.json /tmp/result; exit 1; }
