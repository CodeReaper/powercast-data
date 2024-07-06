#!/bin/sh

# Setup
find /tmp/ -type f -exec rm {} +
find /tmp/ -type d -mindepth 1 -exec rmdir {} +
mkdir /tmp/empty-data-folder
echo '[]' > /tmp/empty-data-file

# Test non-existing file
set +e
sh src/data-write.sh .non-existing-file.json /tmp/empty-data-folder DK1 > /dev/null
[ $? -eq 1 ] || exit 1

# Test non-existing directory
set +e
sh src/data-write.sh test/fixtures/existing-data-write-output/2022/06/01/DK1.json /tmp/non-existing-directory/ DK1 > /dev/null
[ $? -eq 2 ] || exit 1

# Test when given no data that write outputs no files
set -e
sh src/data-write.sh /tmp/empty-data-file /tmp/empty-data-folder DK1
[ -z "$(ls -1A /tmp/empty-data-folder)" ] || { echo "Unexpected files/folders:"; find /tmp/empty-data-folder; exit 1; }

# Test with existing well-known energy price data that write actually writes output files as expected
set -e
mkdir /tmp/test
sh src/data-write.sh test/fixtures/existing-data-write-output/2022/06/01/DK1.json /tmp/test DK1
diff -rq /tmp/test test/fixtures/data-write-generated-energy-price-output || { echo "Unexpected difference:"; diff -r /tmp/test test/fixtures/data-write-generated-energy-price-output; exit 1; }
rm -rf /tmp/test

# Test with existing well-known renewables data that write actually writes output files as expected
set -e
mkdir /tmp/test
sh src/data-write.sh test/fixtures/renewables-data-pull-generated-output.json /tmp/test DK1
diff -rq /tmp/test test/fixtures/data-write-generated-renewables-output || { echo "Unexpected difference:"; diff -r /tmp/test test/fixtures/data-write-generated-renewables-output; exit 1; }
rm -rf /tmp/test

# Test with existing well-known co2 emission data that write actually writes output files as expected
set -e
mkdir /tmp/test
sh src/data-write.sh test/fixtures/co2-emission-data-pull-generated-output.json /tmp/test DK1
diff -rq /tmp/test test/fixtures/data-write-generated-co2-emission-output || { echo "Unexpected difference:"; diff -r /tmp/test test/fixtures/data-write-generated-co2-emission-output; exit 1; }
rm -rf /tmp/test

# Test that write outputs uniquely with energy price data
set -e
mkdir /tmp/test
mkdir /tmp/test2
jq -r '. | map(.euro = 0)' test/fixtures/data-write-generated-energy-price-output/2022/06/01/DK1.json > /tmp/changed
sh src/data-write.sh test/fixtures/data-write-generated-energy-price-output/2022/06/01/DK1.json /tmp/test DK1
sh src/data-write.sh test/fixtures/data-write-generated-energy-price-output/2022/06/01/DK1.json /tmp/test2 DK1
sh src/data-write.sh /tmp/changed /tmp/test2 DK1
diff -rq /tmp/test /tmp/test2 || { echo "Unexpected difference:"; diff -r /tmp/test /tmp/test2; exit 1; }
rm -rf /tmp/test*
rm /tmp/changed

# Test that write outputs uniquely with renewables data
set -e
mkdir /tmp/test
mkdir /tmp/test2
jq -r '. | map(.sources[].energy = 0)' test/fixtures/data-write-generated-renewables-output/2022/07/17/DK1.json > /tmp/changed
sh src/data-write.sh test/fixtures/data-write-generated-renewables-output/2022/07/17/DK1.json /tmp/test DK1
sh src/data-write.sh test/fixtures/data-write-generated-renewables-output/2022/07/17/DK1.json /tmp/test2 DK1
sh src/data-write.sh /tmp/changed /tmp/test2 DK1
diff -rq /tmp/test /tmp/test2 || { echo "Unexpected difference:"; diff -r /tmp/test /tmp/test2; exit 1; }
rm -rf /tmp/test*
rm /tmp/changed

# Test that write outputs uniquely with co2 emission data
set -e
mkdir /tmp/test
mkdir /tmp/test2
jq -r '. | map(.co2 = 0)' test/fixtures/data-write-generated-co2-emission-output/2022/07/17/DK1.json > /tmp/changed
sh src/data-write.sh test/fixtures/data-write-generated-co2-emission-output/2022/07/17/DK1.json /tmp/test DK1
sh src/data-write.sh test/fixtures/data-write-generated-co2-emission-output/2022/07/17/DK1.json /tmp/test2 DK1
sh src/data-write.sh /tmp/changed /tmp/test2 DK1
diff -rq /tmp/test /tmp/test2 || { echo "Unexpected difference:"; diff -r /tmp/test /tmp/test2; exit 1; }
rm -rf /tmp/test*
rm /tmp/changed

# Test that write handles updating files correctly
set -e
mkdir /tmp/test
mkdir /tmp/test2
jq -r '[ .[] | select(.timestamp < 1654084800)]' test/fixtures/data-write-generated-energy-price-output/2022/06/01/DK1.json > /tmp/half
sh src/data-write.sh test/fixtures/data-write-generated-energy-price-output/2022/06/01/DK1.json /tmp/test DK1
sh src/data-write.sh /tmp/half /tmp/test2 DK1
sh src/data-write.sh test/fixtures/data-write-generated-energy-price-output/2022/06/01/DK1.json /tmp/test2 DK1
diff -rq /tmp/test /tmp/test2 || { echo "Unexpected difference:"; diff -r /tmp/test /tmp/test2; exit 1; }
rm -rf /tmp/test*
rm /tmp/half