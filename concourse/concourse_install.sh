#!/usr/bin/env bash
#
# Created By: sarvers
# Created Date: 20200421-150053
#
# Purpose and References:
#
#
# Where you want the options to take effect, use set -o option-name or, in short form, set -option-abbrev, To disable an option within a script, use set +o option-name or set +option-abbrev: https://www.tldp.org/LDP/abs/html/options.html
set +x #xtrace
set +v #verbose
set -e #errexit
set -u #nounset

docker -v
if [ "0" != "$?" ]; then
  echo "Docker is required to use this setup and install script!"
  exit
fi

curl https://concourse-ci.org/docker-compose.yml -o docker-compose.yml
cat docker-compose.yml
docker-compose up -d
echo " "
echo " "
echo "================================================================================"
echo "Concourse will be running at localhost:8080. You can log in with the username/password as test/test."
echo " "
echo " open localhost:8080"
echo " "
echo "================================================================================"
