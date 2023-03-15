#!/bin/bash
# Usage: Automate check behavior regression report

cd contribution/checkstyle-tester || exit 1

groovy diff.groovy \
  -r "../../${CHECKSTYLE_DIRECTORY}" \
  -b master -p "$PATCH_BRANCH" \
  -c "../../configs/$CONFIG_FILE" \
  -l ../../projects/projects-to-test-on.properties
