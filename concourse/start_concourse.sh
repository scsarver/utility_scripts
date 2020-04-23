#!/usr/bin/env bash
#
# Created By: sarvers
# Created Date: 20200421-150652
#
# Purpose and References:
#
#
# Where you want the options to take effect, use set -o option-name or, in short form, set -option-abbrev, To disable an option within a script, use set +o option-name or set +option-abbrev: https://www.tldp.org/LDP/abs/html/options.html
set +x #xtrace
set +v #verbose
set -e #errexit
set -u #nounset

docker-compose up -d

echo " "
echo " "
echo "================================================================================"
echo "Concourse will be running at localhost:8080. You can log in with the username/password as test/test."
echo " "
echo " open localhost:8080"
echo " "
echo "================================================================================"
