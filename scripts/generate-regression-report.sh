#!/bin/bash
set -e
# Usage: Automate check behavior regression report

cd contribution/checkstyle-tester || exit 1

CS_REPO_PATH="${ROOT_DIR}/${CHECKSTYLE_DIRECTORY}"
CONFIG_PATH="${ROOT_DIR}/main/configs/${CONFIG_FILE}"
PROJECTS_PATH="${ROOT_DIR}/main/projects/${PROJECTS_FILE}"

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
