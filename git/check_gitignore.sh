#!/usr/bin/env bash
#
# Created By: sarvers
# Created Date: 20200616-143618
#
# Purpose and References:
# Looking for missing .gitignore files
#
# Where you want the options to take effect, use set -o option-name or, in short form, set -option-abbrev, To disable an option within a script, use set +o option-name or set +option-abbrev: https://www.tldp.org/LDP/abs/html/options.html
set +x #xtrace
set +v #verbose
set -e #errexit
set -u #nounset
SCRIPTDIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
SCRIPTNAME=$(basename $0)
REPOS_DIR="$SCRIPTDIR/../.."

for PROJECT in $(ls -1 "$REPOS_DIR")
do
  if [ -d "$REPOS_DIR/$PROJECT" ]; then
    if [ ! -f "$REPOS_DIR/$PROJECT/.gitignore" ]; then
      echo "MISSING: $PROJECT/.gitignore"
    fi
  fi
done
