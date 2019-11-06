#!/usr/bin/env bash
#
# Created By: stephansarver
# Created Date: 20191106-110823
#
# Purpose and References:
#
#
# Where you want the options to take effect, use set -o option-name or, in short form, set -option-abbrev, To disable an option within a script, use set +o option-name or set +option-abbrev: https://www.tldp.org/LDP/abs/html/options.html
set +x #xtrace
set +v #verbose
set -e #errexit
# set -u #nounset

wait_seconds=5

echo "Starting Mouse Robot!"

if [ "" == "$2" ]; then
  echo "Waiting between bot movements for the default: $wait_seconds seconds."
else
  if ! [[ $2 =~ '^[0-9]+$' ]] ; then
    wait_seconds=$2
    echo "Waiting between bot movements for: $wait_seconds seconds."
  fi
fi

echo "The bot will move $1 times:"
if [ "" == "$1" ]; then
  java MouseRobot
else
  if ! [[ $1 =~ '^[0-9]+$' ]] ; then
    echo "regex - matched"
    # for run in {1.."$1"}
    for ((n=0;n<$1;n++))
    do
      iteration_number=$(($n+1))
      echo "$(date +%Y.%m.%d-%H:%M:%S ) - $iteration_number"
      java MouseRobot
      sleep $wait_seconds
    done
  fi
fi
