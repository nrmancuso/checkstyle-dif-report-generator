#!/bin/bash
set -e
# Usage: Automate ANTLR regression report

cd contribution/checkstyle-tester || exit 1
# TODO: this is a temproraru hack, we need to move script into this file
git fetch --all
git checkout fix-remotes

if [ -z "$ROOT_DIR" ]; then
  echo "'ROOT_DIR' variable must be set." && exit 1
fi

if [ -z "$PROJECT" ]; then
  echo "'PROJECT' variable must be set." && exit 1
fi

if [ -z "$PATCH_BRANCH" ]; then
  echo "'PATCH_BRANCH' variable must be set." && exit 1
fi

# this should point to the report generation repo
if [ ! -d "$REPORT_REPO_DIR" ]; then
  echo "'REPORT_REPO_DIR' variable must be set." && exit 1
fi

# set env variables, depends on $ROOT_DIR
export CONTACTSERVER=false
export PULL_REMOTE=remotes/origin
export CHECKSTYLE_DIR=$ROOT_DIR/checkstyle
export SEVNTU_DIR=$ROOT_DIR/sevntu.checkstyle
export CONTRIBUTION_DIR=$ROOT_DIR/contribution
export TEMP_DIR=/tmp/launch_diff
export TESTER_DIR=$CONTRIBUTION_DIR/checkstyle-tester
export DIFF_JAR=$CONTRIBUTION_DIR/patch-diff-report-tool/target/patch-diff-report-tool-0.1-SNAPSHOT-jar-with-dependencies.jar
export REPOSITORIES_DIR=$TESTER_DIR/repositories
export FINAL_RESULTS_DIR=$TESTER_DIR/reports/diff
export SITE_SAVE_MASTER_DIR=$TESTER_DIR/reports/savemaster
export SITE_SAVE_PULL_DIR=$TESTER_DIR/reports/savepull
export MINIMIZE=true
export SITE_SOURCES_DIR=$TESTER_DIR/src/main/java
export SITE_SAVE_REF_DIR=$TESTER_DIR/reports/saverefs

# comment out source line, we handle variables above
sed -e '/source/s/^/#/g' -i launch_diff_antlr.sh

# ATTENTION: we need to delete the existing projects file and use our own!
rm -f projects-to-test-on.properties
# need to grep this project's name from the projects file

grep "$PROJECT" "$REPORT_REPO_DIR/projects/projects-to-test-on.properties" > projects-to-test-on.properties
echo "Generated projects file contents:"
cat projects-to-test-on.properties

./launch_diff_antlr.sh "$PATCH_BRANCH"
