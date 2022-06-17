#!/bin/sh

# Takes one argument:
#   - file:
#       The workflow file which contains the tests to run.
#       Must be a workflow file with script-based tests.
#       Examples:
#           - workflow.yaml
#           - ../workflow.yaml

# Output example:
# Name of a job
#  - Name of a step: Pass
#  - Name of a failing step: Fail

FILE=$1

DIR=/tmp/$$

[ -f "$FILE" ] || { echo "Not a FILE: $FILE"; exit 1; }

rm -fr $DIR/* > /dev/null
mkdir -p $DIR > /dev/null
trap 'set +x; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

set -e
which yq git > /dev/null

echo -n 'Preparing runnner...'

echo 'TOTAL_PASS=0; TOTAL_FAIL=0' > $DIR/runner.sh

yq -o json "$FILE" | jq -rc '.jobs | to_entries[] | [{group: .key, groupName: .value.name, script: .value.steps}] | .[]' | while read -r JOB; do

    GROUP=$(echo "$JOB" | jq -rj '.group')
    GROUP_NAME=$(echo "$JOB" | jq -rj '.groupName')

    echo "cd '${DIR}/workspace/'; git reset HEAD --hard > /dev/null; git clean -fdx . > /dev/null; sh '${DIR}/${GROUP}.sh'" >> $DIR/runner.sh
    echo "TOTAL_PASS=\$((TOTAL_PASS+\$(cat ${DIR}/PASS))); TOTAL_FAIL=\$((TOTAL_FAIL+\$(cat ${DIR}/FAIL)))" >> $DIR/runner.sh
    echo "echo; echo '$GROUP_NAME'" > "${DIR}/${GROUP}.sh"
    echo "GREEN=$'\e[0;32m'; RED=$'\e[0;31m'; NC=$'\e[0m'; PASS=0; FAIL=0" >> "${DIR}/${GROUP}.sh"

    I=0
    echo "$JOB" | jq -rc '.script[] | select(.run != null)' | while read -r STEP; do
        STEP_NAME=$(echo "$STEP" | jq -rj '.name')
        RUN=$(echo "$STEP" | jq -rj '.run')

        echo "$RUN" > "${DIR}/${GROUP}.${I}.sh"

        echo "echo -n ' - ${STEP_NAME}: '" >> "${DIR}/${GROUP}.sh"
        echo "set +e; sh '${DIR}/${GROUP}.${I}.sh' > messages 2>&1" >> "${DIR}/${GROUP}.sh"
        echo "if [ \$? -eq 0 ]; then echo -e \${GREEN}'Pass'\${NC}; PASS=\$((PASS+1)); else echo -e \${RED}'Fail'\${NC}; FAIL=\$((FAIL+1)); cat messages; fi;" >> "${DIR}/${GROUP}.sh"

        I=$((I+1))
    done

    echo "echo -n \$PASS > '${DIR}/PASS'; echo -n \$FAIL > '${DIR}/FAIL'" >> "${DIR}/${GROUP}.sh"

done

echo 'TOTAL=$((TOTAL_PASS+TOTAL_FAIL))' >> $DIR/runner.sh
echo 'echo; echo -e "Tests; Total: \033[1m${TOTAL}\033[0m Passes: \033[1m${TOTAL_PASS}\033[0m Fails: \033[1m${TOTAL_FAIL}\033[0m"' >> $DIR/runner.sh

echo ' done!'

echo -n 'Preparing workspace... '
mkdir $DIR/workspace
cp -r $(ls -1qA . | grep -v .git$ | tr \\n \ ) $DIR/workspace/
cd $DIR/workspace/
git init > /dev/null 2>&1
git add . > /dev/null
git commit -am "known state" > /dev/null
echo ' done!'

trap 'set +x; cd - > /dev/null; rm -fr $DIR >/dev/null 2>&1' 0
trap 'exit 2' 1 2 3 15

echo 'Executing runner...'
sh $DIR/runner.sh
