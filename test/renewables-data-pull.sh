#!/bin/sh

# Setup
OLDPATH=$PATH
export PATH="test/mocks/wget/:$PATH"

# Test if endpoints does not answer pull will fail
set +e
unset WGET_OVERRIDE
sh src/renewables-data-pull.sh DK1 1658318400 1658361600 > /dev/null
[ $? -ne 0 ] || exit 1

# Test with existing well-known data that pull outputs as expected
set -e
export WGET_OVERRIDE=test/fixtures/endpoint-response/forecasts_hour
sh src/renewables-data-pull.sh DK1 1658318400 1658361600 > /tmp/result
diff -q test/fixtures/renewables-data-pull-generated-output.json /tmp/result || { echo "Unexpected difference:"; diff test/fixtures/renewables-data-pull-generated-output.json /tmp/result; exit 1; }

# Test pull makes a request with end date set to now
set +e
unset WGET_OVERRIDE
now=$(($(date +"%s")+86400))
tomorrow=$((now+86400))
sh src/renewables-data-pull.sh DK1 $now $tomorrow > /dev/null
[ $? -ne 0 ] || exit 1

# Teardown
export PATH="$OLDPATH"
