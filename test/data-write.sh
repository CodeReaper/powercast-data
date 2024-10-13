#!/bin/sh

# Setup
find /tmp/t/ -type f -exec rm {} +
find /tmp/t/ -type d -mindepth 1 -exec rm -rf {} +
mkdir /tmp/t/empty-data-folder
echo '[]' > /tmp/t/empty-data-file

# Test non-existing file
set +e
sh src/data-write.sh .non-existing-file.json /tmp/t/empty-data-folder DK1 > /dev/null
[ $? -eq 1 ] || exit 1

# Test non-existing directory
set +e
sh src/data-write.sh test/fixtures/existing-data-write-output/2022/06/01/DK1.json /tmp/t/non-existing-directory/ DK1 > /dev/null
[ $? -eq 2 ] || exit 1

# Test when given no data that write outputs no files
set -e
sh src/data-write.sh /tmp/t/empty-data-file /tmp/t/empty-data-folder DK1
[ -z "$(ls -1A /tmp/t/empty-data-folder)" ] || { echo "Unexpected files/folders:"; find /tmp/t/empty-data-folder; exit 1; }

# Test with existing well-known energy price data that write actually writes output files as expected
set -e
mkdir /tmp/t/test
sh src/data-write.sh test/fixtures/existing-data-write-output/2022/06/01/DK1.json /tmp/t/test DK1
diff -rq /tmp/t/test test/fixtures/data-write-generated-energy-price-output || { echo "Unexpected difference:"; diff -r /tmp/t/test test/fixtures/data-write-generated-energy-price-output; exit 1; }
rm -rf /tmp/t/test

# Test with existing well-known renewables data that write actually writes output files as expected
set -e
mkdir /tmp/t/test
sh src/data-write.sh test/fixtures/renewables-data-pull-generated-output.json /tmp/t/test DK1
diff -rq /tmp/t/test test/fixtures/data-write-generated-renewables-output || { echo "Unexpected difference:"; diff -r /tmp/t/test test/fixtures/data-write-generated-renewables-output; exit 1; }
rm -rf /tmp/t/test

# Test with existing well-known co2 emission data that write actually writes output files as expected
set -e
mkdir /tmp/t/test
sh src/data-write.sh test/fixtures/co2-emission-data-pull-generated-output.json /tmp/t/test DK1
diff -rq /tmp/t/test test/fixtures/data-write-generated-co2-emission-output || { echo "Unexpected difference:"; diff -r /tmp/t/test test/fixtures/data-write-generated-co2-emission-output; exit 1; }
rm -rf /tmp/t/test

# Test that write outputs uniquely with energy price data
set -e
mkdir /tmp/t/test
mkdir /tmp/t/test2
jq -r '. | map(.euro = 0)' test/fixtures/data-write-generated-energy-price-output/2022/06/01/DK1.json > /tmp/t/changed
sh src/data-write.sh test/fixtures/data-write-generated-energy-price-output/2022/06/01/DK1.json /tmp/t/test DK1
sh src/data-write.sh test/fixtures/data-write-generated-energy-price-output/2022/06/01/DK1.json /tmp/t/test2 DK1
sh src/data-write.sh /tmp/t/changed /tmp/t/test2 DK1
diff -rq /tmp/t/test /tmp/t/test2 || { echo "Unexpected difference:"; diff -r /tmp/t/test /tmp/t/test2; exit 1; }
rm -rf /tmp/t/test*
rm /tmp/t/changed

# Test that write outputs uniquely with renewables data
set -e
mkdir /tmp/t/test
mkdir /tmp/t/test2
jq -r '. | map(.sources[].energy = 0)' test/fixtures/data-write-generated-renewables-output/2022/07/17/DK1.json > /tmp/t/changed
sh src/data-write.sh test/fixtures/data-write-generated-renewables-output/2022/07/17/DK1.json /tmp/t/test DK1
sh src/data-write.sh test/fixtures/data-write-generated-renewables-output/2022/07/17/DK1.json /tmp/t/test2 DK1
sh src/data-write.sh /tmp/t/changed /tmp/t/test2 DK1
diff -rq /tmp/t/test /tmp/t/test2 || { echo "Unexpected difference:"; diff -r /tmp/t/test /tmp/t/test2; exit 1; }
rm -rf /tmp/t/test*
rm /tmp/t/changed

# Test that write outputs uniquely with co2 emission data
set -e
mkdir /tmp/t/test
mkdir /tmp/t/test2
jq -r '. | map(.co2 = 0)' test/fixtures/data-write-generated-co2-emission-output/2022/07/17/DK1.json > /tmp/t/changed
sh src/data-write.sh test/fixtures/data-write-generated-co2-emission-output/2022/07/17/DK1.json /tmp/t/test DK1
sh src/data-write.sh test/fixtures/data-write-generated-co2-emission-output/2022/07/17/DK1.json /tmp/t/test2 DK1
sh src/data-write.sh /tmp/t/changed /tmp/t/test2 DK1
diff -rq /tmp/t/test /tmp/t/test2 || { echo "Unexpected difference:"; diff -r /tmp/t/test /tmp/t/test2; exit 1; }
rm -rf /tmp/t/test*
rm /tmp/t/changed

# Test that write handles updating files correctly
set -e
mkdir /tmp/t/test
mkdir /tmp/t/test2
jq -r '[ .[] | select(.timestamp < 1654084800)]' test/fixtures/data-write-generated-energy-price-output/2022/06/01/DK1.json > /tmp/t/half
sh src/data-write.sh test/fixtures/data-write-generated-energy-price-output/2022/06/01/DK1.json /tmp/t/test DK1
sh src/data-write.sh /tmp/t/half /tmp/t/test2 DK1
sh src/data-write.sh test/fixtures/data-write-generated-energy-price-output/2022/06/01/DK1.json /tmp/t/test2 DK1
diff -rq /tmp/t/test /tmp/t/test2 || { echo "Unexpected difference:"; diff -r /tmp/t/test /tmp/t/test2; exit 1; }
rm -rf /tmp/t/test*
rm /tmp/t/half
