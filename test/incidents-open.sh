#!/bin/sh

# Setup
find /tmp/t/ -type f -exec rm {} +
find /tmp/t/ -type d -mindepth 1 -exec rm -rf {} +

cat << EOF > /tmp/t/open-incident.json
[
  {
    "from": 1704067200,
    "to": null,
    "type": "delay"
  }
]
EOF

cat << EOF > /tmp/t/foo-and-bar-incident.json
[
  {
    "from": 1704067200,
    "to": null,
    "type": "foo"
  },
  {
    "from": 1704067200,
    "to": null,
    "type": "bar"
  }
]
EOF

cat << EOF > /tmp/t/old-incident.json
[
  {
    "from": 1604067200,
    "to": 1604099900,
    "type": "delay"
  }
]
EOF

cat << EOF > /tmp/t/open-and-old-incident.json
[
  {
    "from": 1604067200,
    "to": 1604099900,
    "type": "delay"
  },
  {
    "from": 1704067200,
    "to": null,
    "type": "delay"
  }
]
EOF

# Test with too few arguments
set +e

sh src/incident-open.sh > /dev/null
[ $? -eq 1 ] || exit 1

sh src/incident-open.sh DK1 > /dev/null
[ $? -eq 2 ] || exit 1

sh src/incident-open.sh DK1 1704067200 > /dev/null
[ $? -eq 3 ] || exit 1

sh src/incident-open.sh DK1 1704067200 delay > /dev/null
[ $? -eq 4 ] || exit 1

# Test with handling non-existing directory
set +e
sh src/incident-open.sh DK1 1704067200 delay /tmp/t/not-there-beforehand > /dev/null
[ $? -eq 0 ] || exit 1

[ -d /tmp/t/not-there-beforehand ] || exit 2

# Test with that incident is created
set +e
rm -rf /tmp/t/testing || true

sh src/incident-open.sh DK1 1704067200 delay /tmp/t/testing
[ $? -eq 0 ] || exit 1

[ -f /tmp/t/testing/DK1.json ] || exit 2

set -e
jq -r < /tmp/t/open-incident.json > /tmp/t/expected
jq -r < /tmp/t/testing/DK1.json > /tmp/t/result
set +e
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with that incident is not created twice
set +e
rm -rf /tmp/t/testing || true

sh src/incident-open.sh DK1 1704067200 delay /tmp/t/testing
[ $? -eq 0 ] || exit 1

sh src/incident-open.sh DK1 1704067200 delay /tmp/t/testing
[ $? -eq 0 ] || exit 1

set -e
jq -r < /tmp/t/open-incident.json > /tmp/t/expected
jq -r < /tmp/t/testing/DK1.json > /tmp/t/result
set +e
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with that incident is created with type
set +e
rm -rf /tmp/t/testing || true

sh src/incident-open.sh DK1 1704067200 foo /tmp/t/testing
[ $? -eq 0 ] || exit 1

sh src/incident-open.sh DK1 1704067200 bar /tmp/t/testing
[ $? -eq 0 ] || exit 1

set -e
jq -r < /tmp/t/foo-and-bar-incident.json > /tmp/t/expected
jq -r < /tmp/t/testing/DK1.json > /tmp/t/result
set +e
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with that old incidents are preserved
set +e
rm -rf /tmp/t/testing || true
mkdir /tmp/t/testing || true
cp /tmp/t/old-incident.json /tmp/t/testing/DK1.json

sh src/incident-open.sh DK1 1704067200 delay /tmp/t/testing
[ $? -eq 0 ] || exit 1

set -e
jq -r < /tmp/t/open-and-old-incident.json > /tmp/t/expected
jq -r < /tmp/t/testing/DK1.json > /tmp/t/result
set +e
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }
