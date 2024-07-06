#!/bin/sh

# Setup
find /tmp/ -type f -exec rm {} +
find /tmp/ -type d -mindepth 1 -exec rmdir {} +

cat << EOF > /tmp/open-incident.json
[
  {
    "from": 1704067200,
    "to": null,
    "type": "delay"
  }
]
EOF

cat << EOF > /tmp/closed-incident.json
[
  {
    "from": 1704067200,
    "to": 1704099900,
    "type": "delay"
  }
]
EOF

cat << EOF > /tmp/open-and-old-incident.json
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

cat << EOF > /tmp/closed-and-old-incident.json
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

cat << EOF > /tmp/foo-and-bar-incident.json
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

cat << EOF > /tmp/closed-foo-and-open-bar-incident.json
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

sh src/incident-close.sh DK1 1704099900 delay /tmp/not-there > /dev/null
[ $? -eq 4 ] || exit 1

# Test with that incident is created
set +e

rm -rf /tmp/testing || true
mkdir /tmp/testing
cp /tmp/open-incident.json /tmp/testing/DK1.json

sh src/incident-close.sh DK1 1704099900 delay /tmp/testing
[ $? -eq 0 ] || exit 1

set -e
jq -r < /tmp/closed-incident.json > /tmp/expected
jq -r < /tmp/testing/DK1.json > /tmp/result
set +e
diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }

# Test with that incident is not created twice
set +e

rm -rf /tmp/testing || true
mkdir /tmp/testing
cp /tmp/open-incident.json /tmp/testing/DK1.json

sh src/incident-close.sh DK1 1704099900 delay /tmp/testing
[ $? -eq 0 ] || exit 1

sh src/incident-close.sh DK1 1704099900 delay /tmp/testing
[ $? -eq 0 ] || exit 1

set -e
jq -r < /tmp/closed-incident.json > /tmp/expected
jq -r < /tmp/testing/DK1.json > /tmp/result
set +e
diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }

# Test with that incident is created with type
set +e

rm -rf /tmp/testing || true
mkdir /tmp/testing
cp /tmp/foo-and-bar-incident.json /tmp/testing/DK1.json

sh src/incident-close.sh DK1 1704099900 foo /tmp/testing
[ $? -eq 0 ] || exit 1

set -e
jq -r < /tmp/closed-foo-and-open-bar-incident.json > /tmp/expected
jq -r < /tmp/testing/DK1.json > /tmp/result
set +e
diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }

# Test with that old incidents are preserved
set +e

rm -rf /tmp/testing
mkdir /tmp/testing
cp /tmp/open-and-old-incident.json /tmp/testing/DK1.json

sh src/incident-close.sh DK1 1704099900 delay /tmp/testing
[ $? -eq 0 ] || exit 1

set -e
jq -r < /tmp/closed-and-old-incident.json > /tmp/expected
jq -r < /tmp/testing/DK1.json > /tmp/result
set +e
diff -q /tmp/expected /tmp/result || { echo "Unexpected difference:"; diff /tmp/expected /tmp/result; exit 1; }
