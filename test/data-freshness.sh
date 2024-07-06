#!/bin/sh

# Setup
find /tmp/t/ -type f -exec rm {} +
find /tmp/t/ -type d -mindepth 1 -exec rmdir {} +
mkdir /tmp/t/empty-data-folder

# Test non-existing directory
set +e
sh src/data-freshness.sh /tmp/t/non-existing-directory/ DK1 0 > /dev/null
[ $? -eq 1 ] || exit 1

# Test missing area
set +e
sh src/data-freshness.sh /tmp/t/empty-data-folder/ 0 > /dev/null
[ $? -ne 0 ] || exit 1

# Test missing end date
set +e
sh src/data-freshness.sh /tmp/t/empty-data-folder/ DK1 > /dev/null
[ $? -eq 3 ] || exit 1

# Test with no existing data that freshness outputs the fall back date
set -e
sh src/data-freshness.sh /tmp/t/empty-data-folder/ DK1 12345 > /tmp/t/result
echo '12345' > /tmp/t/expected
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with existing well-known data that freshness outputs as /tmp/t/expected
set -e
sh src/data-freshness.sh test/fixtures/existing-data-write-output/ DK1 12345 > /tmp/t/result
echo '1654297200' > /tmp/t/expected
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }
