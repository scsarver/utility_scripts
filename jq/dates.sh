#!/usr/bin/env bash
#
# Created By: sarvers
# Created Date: 20200609-151031
#
# Purpose and References:
#
#
# Where you want the options to take effect, use set -o option-name or, in short form, set -option-abbrev, To disable an option within a script, use set +o option-name or set +option-abbrev: https://www.tldp.org/LDP/abs/html/options.html
set +x #xtrace
set +v #verbose
set -e #errexit
set -u #nounset
SCRIPTDIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
SCRIPTNAME=$(basename $0)

cat "test-files/aws-config-rule-status-insufficient-data.json" |  jq -r '.'
echo "__________"
echo "Convert from date in a formatted string to a newly formatted date string"
cat "test-files/aws-config-rule-status-insufficient-data.json" |  jq -r '.ConfigRulesEvaluationStatus[] |  .FirstActivatedTime | split(".")[0] | split(":")[0] | strptime("%Y-%m-%dT%H") | mktime | strftime("%Y-%m-%d %H:%M")'
