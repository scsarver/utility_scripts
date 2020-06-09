#!/usr/bin/env bash
#
# Created By: sarvers
# Created Date: 20200609-133458
#
# Purpose and References:
#
# Testing and expirimenting with jq padding functions found here:
# https://github.com/stedolan/jq/issues/2033
#
# Where you want the options to take effect, use set -o option-name or, in short form, set -option-abbrev, To disable an option within a script, use set +o option-name or set +option-abbrev: https://www.tldp.org/LDP/abs/html/options.html
set +x #xtrace
set +v #verbose
set -e #errexit
set -u #nounset
SCRIPTDIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
SCRIPTNAME=$(basename $0)

echo "Left pad function example:"
# First test function not a friendly to using nested properties
# cat "aws-config-rules.json" | jq -r 'def pad(n): if n==0 then (.) else " " + (.) | pad(n - 1) end; .ConfigRules[] | .ConfigRuleName | pad(20)'
# Second test function better for nested properties
cat "aws-config-rules.json" | jq -r 'def lpad(string;len;fill): if len == 0 then string else (fill * len)[0:len] + string end; .ConfigRules[] | "[" + lpad(.ConfigRuleName;10;" ") + "]"'
echo " "
echo "Right pad function example:"
# cat "aws-config-rules.json" | jq -r 'def pad(n): if n==0 then (.) else (.) + " " | pad(n - 1) end; .ConfigRules[] | .ConfigRuleName | pad(5) | "[" + . + "]"'
cat "aws-config-rules.json" | jq -r 'def rpad(string;len;fill): if len - (string | length) <= 0 then string else string + (fill * (len - (string | length)))[0:len] end;.ConfigRules[] | "[" + rpad(.ConfigRuleName;40;" ") + "]"'
