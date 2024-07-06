#!/bin/sh

# Setup
find /tmp/t/ -type f -exec rm {} +
find /tmp/t/ -type d -mindepth 1 -exec rmdir {} +
echo '[]' > /tmp/t/empty-file

# Test non-existing file
set +e
sh src/data-freshness-file.sh .non-existing-file.json 0 > /dev/null
[ $? -eq 1 ] || exit 1

# Test missing fall back date
set +e
sh src/data-freshness-file.sh /tmp/t/empty-file > /dev/null
[ $? -eq 2 ] || exit 1

# Test freshness with no data will outout fall back date
set -e
sh src/data-freshness-file.sh /tmp/t/empty-file 12345 > /tmp/t/result
echo '12345' > /tmp/t/expected
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test freshness with existing data will output as expected
set -e
sh src/data-freshness-file.sh test/fixtures/energy-price-data-pull-generated-output.json 12345 > /tmp/t/result
echo '1658178000' > /tmp/t/expected
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }
