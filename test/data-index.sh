#!/bin/sh

# Setup
find /tmp/t/ -type f -exec rm {} +
find /tmp/t/ -type d -mindepth 1 -exec rm -rf {} +
mkdir /tmp/t/empty-data-folder
mkdir /tmp/t/empty-data-folder/find-helper

# Test non-existing file
set +e
sh src/data-index.sh .non-existing-file.json /tmp/t/empty-data-folder with-zone > /dev/null
[ $? -eq 1 ] || exit 1

# Test non-existing directory
set +e
sh src/data-index.sh configuration/zones.json /tmp/t/non-existing-directory/ with-zone > /dev/null
[ $? -eq 2 ] || exit 1

# Test missing mode
set +e
sh src/data-index.sh configuration/zones.json /tmp/t/empty-data-folder /prefix > /dev/null
[ $? -eq 4 ] || exit 1

# Test incorrect prefix
set +e
sh src/data-index.sh configuration/zones.json /tmp/t/empty-data-folder /prefix/ with-zone > /dev/null
[ $? -eq 3 ] || exit 1

# Test with no existing data that index outputs no data
set -e
sh src/data-index.sh configuration/zones.json /tmp/t/empty-data-folder/ /prefix with-zone | jq -r '.' > /tmp/t/result
echo '[]' > /tmp/t/expected
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with existing well-known data index outputs as expected
set -e
sh src/data-index.sh configuration/zones.json test/fixtures/existing-data-write-output/ /data with-zone | jq -r '.' > /tmp/t/result
diff -q test/fixtures/data-index-generated-output.json /tmp/t/result || { echo "Unexpected difference:"; diff test/fixtures/data-index-generated-output.json /tmp/t/result; exit 1; }

# Test with existing well-known data v2 index outputs as expected
set -e
sh src/data-index.sh configuration/zones.json test/fixtures/existing-data-write-output/v2/ /data with-index | jq -r '.' > /tmp/t/result
diff -q test/fixtures/data-v2-index-generated-output.json /tmp/t/result || { echo "Unexpected difference:"; diff test/fixtures/data-v2-index-generated-output.json /tmp/t/result; exit 1; }
