#!/bin/sh

# Setup
find /tmp/t/ -type f -exec rm {} +
find /tmp/t/ -type d -mindepth 1 -exec rmdir {} +
mkdir /tmp/t/empty-data-folder

# Test non-existing file
set +e
sh src/data-index.sh .non-existing-file.json /tmp/t/empty-data-folder > /dev/null
[ $? -eq 1 ] || exit 1

# Test non-existing directory
set +e
sh src/data-index.sh configuration/zones.json /tmp/t/non-existing-directory/ > /dev/null
[ $? -eq 2 ] || exit 1

# Test missing prefix
set +e
sh src/data-index.sh configuration/zones.json /tmp/t/empty-data-folder > /dev/null
[ $? -eq 3 ] || exit 1

# Test incorrect prefix
set +e
sh src/data-index.sh configuration/zones.json /tmp/t/empty-data-folder /prefix/ > /dev/null
[ $? -eq 3 ] || exit 1

# Test with no existing data that index outputs no data
set -e
sh src/data-index.sh configuration/zones.json /tmp/t/empty-data-folder/ /prefix | jq -r '.' > /tmp/t/result
echo '[]' > /tmp/t/expected
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with existing well-known data index outputs as expected
set -e
sh src/data-index.sh configuration/zones.json test/fixtures/existing-data-write-output/ /data | jq -r '.' > /tmp/t/result
diff -q test/fixtures/data-index-generated-output.json /tmp/t/result || { echo "Unexpected difference:"; diff test/fixtures/data-index-generated-output.json /tmp/t/result; exit 1; }
