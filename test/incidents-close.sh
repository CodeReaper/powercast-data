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

cat << EOF > /tmp/t/closed-incident.json
[
  {
    "from": 1704067200,
    "to": 1704099900,
    "type": "delay"
  }
]
EOF

cat << EOF > /tmp/t/open-and-old-incident.json
[
  {
    "from": 1704067200,
    "to": null,
    "type": "delay"
  },
  {
    "from": 1604067200,
    "to": 1604099900,
    "type": "delay"
  }
]
EOF

cat << EOF > /tmp/t/closed-and-old-incident.json
[
  {
    "from": 1704067200,
    "to": 1704099900,
    "type": "delay"
  },
  {
    "from": 1604067200,
    "to": 1604099900,
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

cat << EOF > /tmp/t/closed-foo-and-open-bar-incident.json
[
  {
    "from": 1704067200,
    "to": 1704099900,
    "type": "foo"
  },
  {
    "from": 1704067200,
    "to": null,
    "type": "bar"
  }
]
EOF

# Test with too few arguments
set +e

sh src/incident-close.sh > /dev/null
[ $? -eq 1 ] || exit 1

sh src/incident-close.sh DK1 > /dev/null
[ $? -eq 2 ] || exit 1

sh src/incident-close.sh DK1 1704099900 > /dev/null
[ $? -eq 3 ] || exit 1

sh src/incident-close.sh DK1 1704099900 delay > /dev/null
[ $? -eq 4 ] || exit 1

# Test with handling non-existing directory
set +e
sh src/incident-close.sh DK1 1704099900 delay /tmp/t/not-there > /dev/null
[ $? -eq 4 ] || exit 1

# Test with that incident is created
set +e
rm -rf /tmp/t/testing || true
mkdir /tmp/t/testing
cp /tmp/t/open-incident.json /tmp/t/testing/DK1.json

sh src/incident-close.sh DK1 1704099900 delay /tmp/t/testing
[ $? -eq 0 ] || exit 1
set -e
jq -r < /tmp/t/closed-incident.json > /tmp/t/expected
jq -r < /tmp/t/testing/DK1.json > /tmp/t/result
set +e
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with that incident is not created twice
set +e
rm -rf /tmp/t/testing || true
mkdir /tmp/t/testing
cp /tmp/t/open-incident.json /tmp/t/testing/DK1.json

sh src/incident-close.sh DK1 1704099900 delay /tmp/t/testing
[ $? -eq 0 ] || exit 1

sh src/incident-close.sh DK1 1704099900 delay /tmp/t/testing
[ $? -eq 0 ] || exit 1

set -e
jq -r < /tmp/t/closed-incident.json > /tmp/t/expected
jq -r < /tmp/t/testing/DK1.json > /tmp/t/result
set +e
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with that incident is created with type
set +e
rm -rf /tmp/t/testing || true
mkdir /tmp/t/testing
cp /tmp/t/foo-and-bar-incident.json /tmp/t/testing/DK1.json

sh src/incident-close.sh DK1 1704099900 foo /tmp/t/testing
[ $? -eq 0 ] || exit 1

set -e
jq -r < /tmp/t/closed-foo-and-open-bar-incident.json > /tmp/t/expected
jq -r < /tmp/t/testing/DK1.json > /tmp/t/result
set +e
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }

# Test with that old incidents are preserved
set +e
rm -rf /tmp/t/testing
mkdir /tmp/t/testing
cp /tmp/t/open-and-old-incident.json /tmp/t/testing/DK1.json

sh src/incident-close.sh DK1 1704099900 delay /tmp/t/testing
[ $? -eq 0 ] || exit 1

set -e
jq -r < /tmp/t/closed-and-old-incident.json > /tmp/t/expected
jq -r < /tmp/t/testing/DK1.json > /tmp/t/result
set +e
diff -q /tmp/t/expected /tmp/t/result || { echo "Unexpected difference:"; diff /tmp/t/expected /tmp/t/result; exit 1; }
