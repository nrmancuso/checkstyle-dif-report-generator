#!/bin/bash
set -e
# Usage: Automate ANTLR regression report

#cd contribution/checkstyle-tester || exit 1
# TODO: this is a temprorary hack, we need to move script into this file
#git fetch --all
#git checkout fix-remotes

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

# ATTENTION: we need to delete the existing projects file and use our own!
#rm -f projects-to-test-on.properties
# need to grep this project's name from the projects file

grep "$PROJECT" "$REPORT_REPO_DIR/projects/projects-to-test-on.properties" > projects-to-test-on.properties
echo "Generated projects file contents:"
cat projects-to-test-on.properties

#./launch_diff_antlr.sh "$PATCH_BRANCH"

#!/bin/bash

EXTPROJECTS=()
USE_CUSTOM_MASTER=false

function mvn_package {
  echo "mvn --batch-mode -Pno-validations clean package -Passembly"
  mvn --batch-mode -Pno-validations clean package -Passembly

  if [ $? -ne 0 ]; then
    echo "Maven Package Failed!"
    exit 1
  fi

  mv target/checkstyle-*-all.jar $TEMP_DIR/checkstyle-$PATCH_BRANCH-all.jar
}

function launch {
    if [ ! -d "$PATCH_BRANCH" ]; then
      mkdir $PATCH_BRANCH
    fi
    if [ ! -d "$2" ]; then
      mkdir $2
    fi

    while read line ; do
      [[ "$line" == \#* ]] && continue # Skip lines with comments
      [[ -z "$line" ]] && continue     # Skip empty lines

      REPO_NAME=`echo $line | cut -d '|' -f 1`
      REPO_TYPE=`echo $line | cut -d '|' -f 2`
      REPO_URL=` echo $line | cut -d '|' -f 3`
      COMMIT_ID=`echo $line | cut -d '|' -f 4`
      EXCLUDES=` echo $line | cut -d '|' -f 5`

      echo "Running Launches on $REPO_NAME ..."

      if [ ! -d "$REPOSITORIES_DIR" ]; then
        mkdir $REPOSITORIES_DIR
      fi
      REPO_SOURCES_DIR=

      if [ "$REPO_TYPE" == "git" ]; then
        GITPATH=$REPOSITORIES_DIR/$REPO_NAME

        if [ ! -d "$GITPATH" ]; then
          echo "Cloning $REPO_TYPE repository '${REPO_NAME}' ..."
          git clone $REPO_URL $GITPATH
          echo -e "Cloning $REPO_TYPE repository '$REPO_NAME' - completed"
        fi
        if [ "$COMMIT_ID" != "" ] && [ "$COMMIT_ID" != "master" ]; then
          echo "Reseting $REPO_TYPE sources to commit '$COMMIT_ID'"
          cd $GITPATH
          if $CONTACTSERVER ; then
            git fetch origin
          fi
          git reset --hard $COMMIT_ID
          git clean -f -d
          cd -
        else
          echo "Reseting GIT $REPO_TYPE sources to head"
          cd $GITPATH
          if $CONTACTSERVER ; then
            git fetch origin
            git reset --hard origin/master
          fi
          git clean -f -d
          cd -
        fi

        REPO_SOURCES_DIR=$GITPATH
      else
        echo "Unknown RepoType: $REPO_TYPE"
        exit 1
      fi

      if [ -z "$REPO_SOURCES_DIR" ] || [ ! -d "$REPO_SOURCES_DIR" ]; then
        echo "Unable to find RepoDir for $REPO_NAME: $REPO_SOURCES_DIR"
        exit 1
      fi

      SECONDS=0
      echo "Running Checkstyle on all files in $SITE_SOURCES_DIR"

      for f in $(find $REPO_SOURCES_DIR -name '*.java')
      do
        result=$()
echo "$f"
        saveMasterFile=${f#$REPO_SOURCES_DIR/}
        saveMasterFile=${saveMasterFile%".java"}
        saveMasterFile=$PATCH_BRANCH/$REPO_NAME/$saveMasterFile.tree
        saveMasterDir=$(dirname "$saveMasterFile")

        if [ ! -d "$saveMasterDir" ]; then
          mkdir -p $saveMasterDir
        fi

        savePatchFile=${f#$REPO_SOURCES_DIR/}
        savePatchFile=${savePatchFile%".java"}
        savePatchFile=$2/$REPO_NAME/$savePatchFile.tree
        savePatchDir=$(dirname "$savePatchFile")

        if [ ! -d "$savePatchDir" ]; then
          mkdir -p $savePatchDir
        fi

        # parallel run
        java -jar $TEMP_DIR/checkstyle-master-all.jar -J $f > $saveMasterFile 2>&1 &
        java -jar $TEMP_DIR/checkstyle-patch-all.jar -J $f > $savePatchFile 2>&1 &
        wait
      done

      duration=$SECONDS
      echo "Running Checkstyle on $SITE_SOURCES_DIR - finished - $(($duration / 60)) minutes and $(($duration % 60)) seconds."

      if ! containsElement "$REPO_NAME" "${EXTPROJECTS[@]}" ; then
        EXTPROJECTS+=($REPO_NAME)
      fi

      echo "Running Launch on $REPO_NAME - completed"
    done < $TESTER_DIR/projects-to-test-on.properties
}

function containsElement {
  local e
  for e in "${@:2}";
  do
    [[ "$e" == "$PATCH_BRANCH" ]] && return 0;
  done
  return 1
}

# ============================================================
# ============================================================
# ============================================================

if [ ! -d "$TEMP_DIR" ]; then
  mkdir $TEMP_DIR
fi

echo "Testing Checkstyle Starting"

cd $CHECKSTYLE_DIR


git checkout master

git clean -f -d

echo "Packaging Master"

mvn_package "master"

echo "Checking out and Installing PR $PATCH_BRANCH"

git fetch $PULL_REMOTE

if [ ! `git rev-parse --verify $PULL_REMOTE/$PATCH_BRANCH` ] ;
then
  echo "Branch $PULL_REMOTE/$PATCH_BRANCH doesn't exist"
  exit 1
fi

git checkout $PULL_REMOTE/$PATCH_BRANCH
git clean -f -d

mvn_package "patch"

echo "Starting all Launchers"

rm -rf $SITE_SAVE_MASTER_DIR
rm -rf $SITE_SAVE_PULL_DIR

launch $SITE_SAVE_MASTER_DIR $SITE_SAVE_PULL_DIR

echo "Starting all Reports"

if [ ! -d "$FINAL_RESULTS_DIR" ]; then
  mkdir $FINAL_RESULTS_DIR
else
  rm -rf $FINAL_RESULTS_DIR/*
fi

OUTPUT_FILE="$FINAL_RESULTS_DIR/index.html"

if [ -f $OUTPUT_FILE ] ; then
  rm $OUTPUT_FILE
fi
echo "<html><head>" >> $OUTPUT_FILE
echo "<link rel='icon' href='https://checkstyle.org/images/favicon.png' type='image/x-icon' />" >> $OUTPUT_FILE
echo "<title>Checkstyle Tester Report Diff Summary</title>" >> $OUTPUT_FILE
echo "</head><body>" >> $OUTPUT_FILE

REMOTE="master"

cd $CHECKSTYLE_DIR
HASH=$(git rev-parse $REMOTE)
MSG=$(git log $REMOTE -1 --pretty=%B)

echo "<h6>" >> $OUTPUT_FILE
echo "Base branch: $REMOTE<br />" >> $OUTPUT_FILE
echo "Base branch last commit SHA: $HASH<br />" >> $OUTPUT_FILE
echo "Base branch last commit message: $MSG<br />" >> $OUTPUT_FILE
echo "</h6>" >> $OUTPUT_FILE

REMOTE="$PULL_REMOTE/$PATCH_BRANCH"

cd $CHECKSTYLE_DIR
HASH=$(git rev-parse $REMOTE)
MSG=$(git log $REMOTE -1 --pretty=%B)

echo "<h6>" >> $OUTPUT_FILE
echo "Patch branch: $REMOTE<br />" >> $OUTPUT_FILE
echo "Patch branch last commit SHA: $HASH<br />" >> $OUTPUT_FILE
echo "Patch branch last commit message: $MSG<br />" >> $OUTPUT_FILE
echo "</h6>" >> $OUTPUT_FILE

echo "Tested projects: ${#EXTPROJECTS[@]}" >> $OUTPUT_FILE
echo "<br /><br /><br />" >> $OUTPUT_FILE

for extp in "${EXTPROJECTS[@]}"
do
  if [ ! -d "$FINAL_RESULTS_DIR/$extp" ]; then
    parentDir=$(dirname "$SITE_SAVE_MASTER_DIR")

    echo "java -jar $DIFF_JAR \
      --compareMode text --baseReport $SITE_SAVE_MASTER_DIR/$extp \
      --patchReport $SITE_SAVE_PULL_DIR/$extp
      --output $FINAL_RESULTS_DIR/$extp -refFiles $parentDir"

    java -jar $DIFF_JAR --compareMode text \
    --baseReport $SITE_SAVE_MASTER_DIR/$extp \
    --patchReport $SITE_SAVE_PULL_DIR/$extp \
    --output $FINAL_RESULTS_DIR/$extp \
    -refFiles $parentDir

    if [ "$?" != "0" ]  if [ ! `git rev-parse --verify $PULL_REMOTE/$CUSTOM_MASTER` ] ;

    then
      echo "patch-diff-report-tool failed on $extp"
      exit 1
    fi
  else
    echo "Skipping patch-diff-report-tool for $extp"
  fi

  total=($(grep -Eo 'totalDiff">[0-9]+' $FINAL_RESULTS_DIR/$extp/index.html | grep -Eo '[0-9]+'))

  echo "<a href='$extp/index.html'>$extp</a>" >> $OUTPUT_FILE
  if [ ${#total[@]} != "0" ] ; then
    if [ ${total[0]} -ne 0 ] ; then
      echo " (${total[0]})" >> $OUTPUT_FILE
    fi
  fi
  echo "<br />" >> $OUTPUT_FILE
done

echo "</body></html>" >> $OUTPUT_FILE

echo "Complete"

exit 0

