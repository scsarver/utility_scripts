#!/usr/bin/env bash
#
# Created By: sarvers
# Created Date: 20200421-152635
#
# Purpose and References:
# Followed the concourse tutorial here: https://concoursetutorial.com/basics/task-hello-world/
#
# Where you want the options to take effect, use set -o option-name or, in short form, set -option-abbrev, To disable an option within a script, use set +o option-name or set +option-abbrev: https://www.tldp.org/LDP/abs/html/options.html
set +x #xtrace
set +v #verbose
set -e #errexit
set -u #nounset


pushd .
cd ../../../

if [ ! -d "starkandwayne" ]; then
  mkdir starkandwayne
fi
cd starkandwayne
if [ ! -d "concourse-tutorial" ]; then
  git clone https://github.com/starkandwayne/concourse-tutorial.git
fi
# cd concourse-tutorial/tutorials/basic/task-hello-world
# fly -t tutorial execute -c task_hello_world.yml
popd

if false; then
  echo " "
  echo "____________ "
  echo " Tutorial #1 "
  echo "____________ "

  ./fly -t tutorial execute -c ../../../starkandwayne/concourse-tutorial/tutorials/basic/task-hello-world/task_hello_world.yml

  echo " "
  echo " "
  echo "================================================================================"

  echo " "
  echo "____________ "
  echo " Tutorial #2 "
  echo "____________ "

  ./fly -t tutorial execute -c ../../../starkandwayne/concourse-tutorial/tutorials/basic/task-hello-world/task_ubuntu_uname.yml

  echo " "
  echo " "
  echo "================================================================================"

  echo " "
  echo "____________ "
  echo " Self directed test #1 for tasks "
  echo "____________ "

  # Tried adding task inputs, it seems this is really only for uploading a directory instead of passing a string into the container.
  # ./fly -t tutorial execute -c concourse_task_test.yaml -i date-message="Message: Testing inputs to concourse task!"
  ./fly -t tutorial execute -c concourse_task_test.yaml

  echo " "
  echo "config file:  concourse_task_test.yaml "
  cat concourse_task_test.yaml
  echo " "
  echo "findings:"
  echo " "
  echo " - the config node 'run' allows you to pass 'path' to an executable"
  echo " - the config node 'run' allows you to pass 'args' to the executable in path"
  echo "   - By setting path to date and args to +%Y%m%d%H%M%S  we can essentially call the date executable and format the date"
  echo "   date +%Y%m%d%H%M%S - $(date +%Y%m%d%H%M%S)"
  echo " "
fi

echo " "
echo "____________ "
echo " Self directed test #1 for pipelines "
echo "____________ "

./fly -t tutorial sp -c concourse_pipeline_test.yaml -p hello-world
./fly -t tutorial up -p hello-world

echo " "
echo "watching: [hello-world/job-hello-world] "
./fly -t tutorial watch -j hello-world/job-hello-world

echo " "
echo "Show builds: "
./fly -t tutorial builds

echo " "
echo "Trigger job: hello-world/job-hello-world"
./fly -t tutorial trigger-job -j hello-world/job-hello-world

echo " "
echo "watching after explicitly triggering: [hello-world/job-hello-world] "
./fly -t tutorial watch -j hello-world/job-hello-world

# Combines both trigger and watch!
# ./fly -t tutorial trigger-job -j hello-world/job-hello-world -w

echo " "
echo " "
echo "================================================================================"
echo "http://localhost:8080/builds/1 is viewable in the browser. It is another view of the same task."
echo " "
echo " open http://localhost:8080/builds/1"
echo " "
echo "================================================================================"
