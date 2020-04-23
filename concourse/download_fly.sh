#!/usr/bin/env bash
#
# Created By: sarvers
# Created Date: 20200421-151357
#
# Purpose and References:
#
#
# Where you want the options to take effect, use set -o option-name or, in short form, set -option-abbrev, To disable an option within a script, use set +o option-name or set +option-abbrev: https://www.tldp.org/LDP/abs/html/options.html
set +x #xtrace
set +v #verbose
set -e #errexit
set -u #nounset

curl "http://localhost:8080/api/v1/cli?arch=amd64&platform=darwin" -o fly
chmod 740 fly

echo " "
echo " "
echo "================================================================================"
echo "Test login to fly:"
echo " "
./fly -t tutorial login -c http://localhost:8080 -u test -p test
echo "================================================================================"
