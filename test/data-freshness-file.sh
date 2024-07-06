#!/bin/sh

# Setup
find /tmp/ -type f -exec rm {} +
find /tmp/ -type d -mindepth 1 -exec rmdir {} +
echo '[]' > /tmp/empty-file

# Test non-existing file
set +e
sh src/data-freshness-file.sh .non-existing-file.json 0 > /dev/null
[ $? -eq 1 ] || exit 1

# Test missing fall back date
set +e
sh src/data-freshness-file.sh /tmp/empty-file > /dev/null
[ $? -eq 2 ] || exit 1

# Test freshness with no data will outout fall back date
set -e

sh src/data-freshness-file.sh /tmp/empty-file 12345 > /tmp/result
echo '12345' > /tmp/expected
diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }

# Test freshness with existing data will output as expected
set -e

sh src/data-freshness-file.sh test/fixtures/energy-price-data-pull-generated-output.json 12345 > /tmp/result
echo '1658178000' > /tmp/expected
diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }
