#!/bin/bash
set -e
# Usage: Automate check behavior regression report

cd contribution/checkstyle-tester || exit 1

CS_REPO_PATH="../../${CHECKSTYLE_DIRECTORY}"
CONFIG_PATH="../../configs/${CONFIG_FILE}"
PROJECTS_PATH="../../projects/projects-to-test-on.properties"

if [ ! -d "$CS_REPO_PATH" ]; then
  echo "$CS_REPO_PATH does not exist."
fi

groovy diff.groovy \
  -r "$CS_REPO_PATH" \
  -b master \
  -p "$PATCH_BRANCH" \
  -c "$CONFIG_PATH" \
  -l "$PROJECTS_PATH" \
  -xm "-Dcheckstyle.failsOnError=false" \
  --allowExcludes
