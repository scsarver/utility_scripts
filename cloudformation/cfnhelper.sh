#!/usr/bin/env bash
#
# Created By: sarvers
# Created Date: 20200916-121907
#
# Purpose and References: See usage function defined below - ref: https://en.wikipedia.org/wiki/Usage_message
# Where you want the options to take effect, use set -o option-name or, in short form, set -option-abbrev, To disable an option within a script, use set +o option-name or set +option-abbrev: https://www.tldp.org/LDP/abs/html/options.html
set +x #xtrace
set +v #verbose
set -e #errexit
set -o pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
# set -u #nounset - This is off by default until the parameter parsing while block usage of $1 forcing an error can be figured out.
DRY_RUN="false"
QUIET="false"
VERBOSE="false"
LOG_TO_FILE="false"
readonly SCRIPTDIR="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
readonly SCRIPTNAME="$(basename "$0")"
readonly LOGFILE="${SCRIPTNAME%.*}-$(date +%Y%m%d-%H%M%S).log"
function missing_arg { echo "Error: Argument for $1 is missing" >&2; exit 1; }
function unsupported_flag { echo "Error: Unsupported flag $1" >&2; exit 1; }
function usage {
cat <<HEREDOCUSAGE
  Usage: $SCRIPTNAME Path:$SCRIPTDIR
  Purpose:
    This script contains the functions to handle cloudformation deployments, showing stack events and stack removal.
  Flags:
    -v|--verbose [true|false - default false]- Used to increase the verbosity of output.
    -q|--quiet   [true|false - default false]- Used to turn off logging and output.
    -l|--log [true|false - default false]- Used to turn on logging output to a file with the naming pattern [${SCRIPTNAME%.*}-%Y%m%d-%H%M%S.log]
    -u|--usage - Used to display this usage documentation and exit.
    -p|--product-name - [string] - This string will be used to prefix the cloudformation stack names.
    -k|--location-directory - [string] - This is a path to the directory where the cloudformation templates are, defaults to the current working directory.
    -s|--show-stack-names - Will show the stack names that will be used based on the configured files and product.
    -d|--deploy - run the deploy steps
    -r|--remove-stack - [string stackName] - Will delete a stack in the ROLLBACK_COMPLETE status.
    -f|--force-remove-stack - [string stackName] - Will delete a stack in any status.
    -y|--stack-events-since-yesterday - Will list a stacks events filtered by the last 24hrs



TODOS:
  - Add tagging to the cloudformation stacks
    - team, product, createdby
  - Add ability to override parameters in a consitent way
  - Inteligently detrmine when stacks need to be created with the following   --capabilities CAPABILITY_NAMED_IAM


HEREDOCUSAGE
}
# Consider enhancing with color logging some examples found here: https://github.com/docker/docker-bench-security/blob/master/output_lib.sh
function log {
  if [ "true" != "$QUIET" ]; then
    if [ "true" == "$LOG_TO_FILE" ]; then
      if [ "" == "$(which tee)" ]; then
        echo "$1" && echo "$1">>"$LOGFILE"
      else
        echo "$1" | tee -a "$LOGFILE"
      fi
    else
      echo "$1"
    fi
  fi
}
function vlog {
  if [ "true" == "$VERBOSE" ]; then
    log "$1"
  fi
}
if [ "true" == "$LOG_TO_FILE" ]; then
  touch "$LOGFILE" #This happens after flags are parsed
fi

readonly REQUIRED_SOFTWARE='aws jq yq'
for REQUIRED in $REQUIRED_SOFTWARE; do
  command -v "$REQUIRED" >/dev/null 2>&1 || { printf "%s command not found and is required for [$SCRIPTNAME].\n" "$REQUIRED"; exit 1; }
done

readonly RETRIES=(
5
8
13
21
34
55
)

PRODUCT='sample-fargate'
TEMPLATE_DIRECTORY="$(PWD)"
# TODO: The template file should be able to be supplied or looked up.
TEMPLATE_FILES=(
driftcheck-cloudtrail.yaml
secrets2.yaml
)

# secrets.yaml

# TODO: The product should be able to be supplied or looked up.
readonly TEMPLATE_PACKAGING_BUCKET_PREFIX='cf-templates'
# TEMPLATE_PACKAGING_BUCKET_NAME="$(aws s3api list-buckets --query "Buckets[?starts_with(Name, '$(TEMPLATE_PACKAGING_BUCKET_PREFIX)')].Name" --output text)"
# aws s3api list-buckets --query "Buckets[?starts_with(Name, 'cf-templates')].Name" --output text


# readonly AWS_CLOUDFORMATION_IAM_CAPABILITIES_TYPES=(
# CAPABILITY_IAM
# CAPABILITY_NAMED_IAM
# )
#
# readonly AWS_IAM_TYPES=(
# AWS::IAM::AccessKey
# AWS::IAM::Group
# AWS::IAM::InstanceProfile
# AWS::IAM::Policy
# AWS::IAM::Role
# AWS::IAM::User
# AWS::IAM::UserToGroupAddition
# )
#
# readonly AWS_CLOUDFORMATION_EXECUTION_STATUSES=(
# UNAVAILABLE
# AVAILABLE
# EXECUTE_IN_PROGRESS
# EXECUTE_COMPLETE
# EXECUTE_FAILED
# OBSOLETE
# )
#
# readonly AWS_CLOUDFORMATION_PROCEED_EXECUTION_STATUSES=(
# AVAILABLE
# )
#
# readonly AWS_CLOUDFORMATION_RETRY_EXECUTION_STATUSES=(
# UNAVAILABLE
# )
#
# readonly AWS_CLOUDFORMATION_FAIL_EXECUTION_STATUSES=(
# EXECUTE_IN_PROGRESS
# EXECUTE_COMPLETE
# EXECUTE_FAILED
# OBSOLETE
# )


function set_template_file_list {
   local DIRECTORY_FILE_LIST=($( ls $TEMPLATE_DIRECTORY ))
   declare -a NEW_TEMPLATE_FILE_LIST
   for DIRECTORY_FILE_LIST_ITEM in ${DIRECTORY_FILE_LIST[@]}
   do
     if [[ "$DIRECTORY_FILE_LIST_ITEM" == *".yaml" ]] || [[ "$DIRECTORY_FILE_LIST_ITEM" == *".yml" ]]; then
       TEMPLATE_VERSION="$(yq read "${TEMPLATE_DIRECTORY}/${DIRECTORY_FILE_LIST_ITEM}" 'AWSTemplateFormatVersion')"
       if [ "2010-09-09" == "$TEMPLATE_VERSION" ]; then
         NEW_TEMPLATE_FILE_LIST+=("$DIRECTORY_FILE_LIST_ITEM")
         continue
       fi
       RESOURCE_TYPE="$(yq read "${TEMPLATE_DIRECTORY}/$DIRECTORY_FILE_LIST_ITEM" 'Resources.*.Type')"
       if [[ "$RESOURCE_TYPE" == *"AWS::"* ]]; then
         # echo "MATCHED ************ - $DIRECTORY_FILE_LIST_ITEM"
         NEW_TEMPLATE_FILE_LIST+=("$DIRECTORY_FILE_LIST_ITEM")
         continue
       fi
     fi
  done

  if [ "0" == "${#NEW_TEMPLATE_FILE_LIST[@]}" ]; then
    echo "No AWS Cloudformation template files were found! - [$TEMPLATE_DIRECTORY]"
    exit 1
  else
    TEMPLATE_FILES=(${NEW_TEMPLATE_FILE_LIST[@]})
    vlog "  - Matched [*.yaml, *.yml] file Cloudformation templates in [$TEMPLATE_DIRECTORY]"
    for TEMPLATE_FILE in ${TEMPLATE_FILES[@]}
    do
      vlog "    - $TEMPLATE_FILE"
    done
  fi

}


function show_aws_account {
  if [ "" == "$AWS_PROFILE" ]; then
    log "Expecting to have the AWS_PROFILE environment variable set!"
    exit 1
  fi
  if [ "" == "$AWS_REGION" ]; then
    log "Expecting to have the AWS_REGION environment variable set!"
    exit 1
  fi
  local ACCTOUNT_NUMBER="$(aws sts get-caller-identity | jq -r '.Account')"
  local TIMESTAMP="$(date +%Y%m%d%H%M%S)"
  vlog "============================================================"
  log "  - $AWS_PROFILE - $ACCTOUNT_NUMBER : AWS Cloudformation deployment - [$SCRIPTDIR][$SCRIPTNAME] - $TIMESTAMP "
  vlog " "
  vlog "============================================================"
  log " "
}

function generate_stack_name_from_template_file {
  local TEMPLATE_FILE="$1"
  if [ "" == "$TEMPLATE_FILE" ]; then
    echo "A template file is required!"
    exit 1
  fi
  local TRIMMED_TEMPLATE_FILE="${TEMPLATE_FILE%.yaml}"
  local STACK_NAME="$PRODUCT-${TRIMMED_TEMPLATE_FILE%.yml}"
  echo "$STACK_NAME"
}

function does_stack_exist {
  local STACK_NAME="$1"
  if [ "" == "$STACK_NAME" ]; then
    echo "A stack name is required!"
    exit 1
  fi
  local OUTPUT_DESCRIBE_STACK="$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[*].StackName" --output text 2>&1)"
  # An error occurred (ValidationError) when calling the DescribeStacks operation: Stack with id <XXXXXXXXX> does not exist
  if [[ "$OUTPUT_DESCRIBE_STACK" == *"does not exist"* ]]; then
    echo "false"
  else
    echo "true"
  fi
}

function validate_template {
  local TEMPLATE_FILE="$1"
  if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "The cloudformation template file [$TEMPLATE_FILE] does not exist!"
    exit 1
  fi
  # aws cloudformation validate-template --template-body "file://$TEMPLATE_FILE"
  aws cloudformation validate-template --template-body "file://$TEMPLATE_FILE" | jq -r "."
}

function handle_stack_waiter {
  local STACK_NAME="$1"
  local STACK_EVENT_TIMESTAMP_FILTER="$2"
  local WAITER_TYPE="$3"
  if [ "" == "$STACK_NAME" ]; then
    echo "A stack name is required!"
    exit 1
  fi
  if [ "" == "$STACK_EVENT_TIMESTAMP_FILTER" ]; then
    echo "A timestamp in utc is required! [this can be achieved using this format example: date -u \'+%Y-%m-%dT%H:%M:%SZ\']"
    exit 1
  fi
  if [ "" == "$WAITER_TYPE" ]; then
    echo "A waiter type is required! - see [aws cloudformation wait help]"
    exit 1
  fi

  local OUTPUT_WAITER="$( aws cloudformation wait "$WAITER_TYPE" --stack-name "$STACK_NAME" 2>&1)"
  show_stack_event_summaries_after_timestamp_filter "$STACK_NAME" "$STACK_EVENT_TIMESTAMP_FILTER"

  if [[ "$OUTPUT_WAITER" == *"failed: Waiter encountered a terminal failure state"* ]]; then
    echo "$OUTPUT_WAITER"
    exit 1
  fi
}

function show_stack_resources_and_statuses {
  local STACK_NAME="$1"
  if [ "" == "$STACK_NAME" ]; then
    echo "A stack name is required!"
    exit 1
  fi
  local OUTPUT_DESCRIBE_STACK_RESOURCES="$(aws cloudformation describe-stack-resources --stack-name "$STACK_NAME" --query "StackResources[*]" 2>&1 || true)"
  local RESOURCE_COUNT_TOTAL="$(echo "$OUTPUT_DESCRIBE_STACK_RESOURCES" | jq -r '.|length')"
  if [ "0" != "$RESOURCE_COUNT_TOTAL" ]; then
    echo "  - Showing stack resource statuses:"
    for RESOURCE_COUNT in $(seq 0 $(($RESOURCE_COUNT_TOTAL-1)))
    do
      local STACK_RESOURCE="$(echo $OUTPUT_DESCRIBE_STACK_RESOURCES | jq -r --arg RESOURCE_COUNT $RESOURCE_COUNT '.[$RESOURCE_COUNT|tonumber] | .')"
      local STACK_RESOURCE_LOGICAL_ID="$(echo "$STACK_RESOURCE" | jq -r '.LogicalResourceId')"
      local STACK_RESOURCE_PHYSICAL_ID="$(echo "$STACK_RESOURCE" | jq -r '.PhysicalResourceId')"
      local STACK_RESOURCE_STAUS="$(echo "$STACK_RESOURCE" | jq -r '.ResourceStatus')"
      echo "    - $STACK_RESOURCE_STAUS - $STACK_RESOURCE_LOGICAL_ID [$STACK_RESOURCE_PHYSICAL_ID]"
    done
  fi
}

function show_stack_event_summaries_after_timestamp_filter {
  local STACK_NAME="$1"
  local STACK_EVENT_TIMESTAMP_FILTER="$2"
  if [ "" == "$STACK_NAME" ]; then
    echo "A stack name is required!"
    exit 1
  fi
  if [ "" == "$STACK_EVENT_TIMESTAMP_FILTER" ]; then
    echo "A timestamp in utc is required! [this can be achieved using this format example: date -u \'+%Y-%m-%dT%H:%M:%SZ\']"
    exit 1
  fi
  local OUTPUT_STACK_EVENTS="$(aws cloudformation describe-stack-events --stack-name "$STACK_NAME" --query "StackEvents[?Timestamp>='$STACK_EVENT_TIMESTAMP_FILTER']" 2>&1)"
  local STACK_EVENT_COUNT_TOTAL="$(echo "$OUTPUT_STACK_EVENTS" | jq -r '.|length')"
  if [ "0" != "$STACK_EVENT_COUNT_TOTAL" ]; then
    echo ' '
    echo "  - Listing stack event summaries: [$STACK_NAME] from after [$STACK_EVENT_TIMESTAMP_FILTER]"
    # We want to see which resource delete failed so we look them up if an DELETE_FAILED stack event is found.
    local DELETE_FAILED='false'
    for STACK_EVENT_COUNT in $(seq 0 $(($STACK_EVENT_COUNT_TOTAL-1)))
    do
      local STACK_EVENT="$(echo $OUTPUT_STACK_EVENTS | jq -r --arg STACK_EVENT_COUNT $STACK_EVENT_COUNT '.[$STACK_EVENT_COUNT|tonumber] | .')"
      local EVENT_ID="$(echo "$OUTPUT_STACK_EVENTS" | jq -r --arg STACK_EVENT_COUNT $STACK_EVENT_COUNT '.[$STACK_EVENT_COUNT|tonumber] | .EventId')"
      local RESOURCE_ID="$(echo "$OUTPUT_STACK_EVENTS" | jq -r --arg STACK_EVENT_COUNT $STACK_EVENT_COUNT '.[$STACK_EVENT_COUNT|tonumber] | .LogicalResourceId')"
      local RESOURCE_STATUS="$(echo "$OUTPUT_STACK_EVENTS" | jq -r --arg STACK_EVENT_COUNT $STACK_EVENT_COUNT '.[$STACK_EVENT_COUNT|tonumber] | .ResourceStatus')"
      local RESOURCE_STATUS_REASON="$(echo "$OUTPUT_STACK_EVENTS" | jq -r --arg STACK_EVENT_COUNT $STACK_EVENT_COUNT '.[$STACK_EVENT_COUNT|tonumber] | .ResourceStatusReason')"
      local STACK_EVENT_TIMESTAMP="$(echo $OUTPUT_STACK_EVENTS | jq -r --arg STACK_EVENT_COUNT $STACK_EVENT_COUNT '.[$STACK_EVENT_COUNT|tonumber] | .Timestamp')"
      echo "    - $STACK_EVENT_TIMESTAMP - $RESOURCE_ID [$RESOURCE_STATUS - $RESOURCE_STATUS_REASON] - $EVENT_ID"
      if [ "DELETE_FAILED" == "$RESOURCE_STATUS" ]; then
        DELETE_FAILED='true'
      fi
    done
    echo ' '
    if [ "true" == "$DELETE_FAILED" ]; then
      show_stack_resources_and_statuses "$STACK_NAME"
    fi

  fi
}

function show_stack_event_summaries_since_yesterday {
  local STACK_NAME="$1"
  if [ "" == "$STACK_NAME" ]; then
    echo "A stack name is required!"
    exit 1
  fi
  show_aws_account
  show_stack_event_summaries_after_timestamp_filter "$1" "$(date -v-1d +%Y-%m-%dT%H:%M:%SZ)"
}

function create_stack {
  local STACK_NAME="$1"
  local STACK_EVENT_TIMESTAMP_FILTER="$2"
  local TEMPLATE_FILE="$3"
  if [ "" == "$STACK_NAME" ]; then
    echo "A stack name is required!"
    exit 1
  fi
  if [ "" == "$STACK_EVENT_TIMESTAMP_FILTER" ]; then
    echo "A timestamp in utc is required! [this can be achieved using this format example: date -u \'+%Y-%m-%dT%H:%M:%SZ\']"
    exit 1
  fi
  if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "The cloudformation template file [$TEMPLATE_FILE] does not exist!"
    exit 1
  fi
  show_aws_account
  local OUTPUT_DESCRIBE_STACK="$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[*].StackName" --output text 2>&1)"
  if [[ "$OUTPUT_DESCRIBE_STACK" == *"does not exist"* ]]; then
    true # Nothing to do
  else
    echo "A stack with the name [$STACK_NAME] already exisits!"
    exit 1
  fi
  echo "  - Creating stack: $STACK_NAME"
  local OUTPUT_CREATE_STACK_ID="$(aws cloudformation create-stack --stack-name "$STACK_NAME" --template-body "file://$TEMPLATE_FILE" --query "StackId" --output text 2>&1)"
  echo "  - Creating stack: $OUTPUT_CREATE_STACK_ID"
  echo "  - waiting for stack status to reach [CREATE_COMPLETE] for stack [$STACK_NAME] with id [$OUTPUT_CREATE_STACK_ID] "
  handle_stack_waiter "$STACK_NAME" "$STACK_EVENT_TIMESTAMP_FILTER" "stack-create-complete"
}

function remove_stack {
  local STACK_NAME="$1"
  if [ "" == "$STACK_NAME" ]; then
    echo "A stack name is required!"
    exit 1
  fi
  delete_stack "$STACK_NAME" "false"
}

function force_remove_stack {
  local STACK_NAME="$1"
  if [ "" == "$STACK_NAME" ]; then
    echo "A stack name is required!"
    exit 1
  fi
  delete_stack "$STACK_NAME" "true"
}

function delete_stack {
  local STACK_NAME="$1"
  local FORCE_DELETE="$2"
  if [ "" == "$STACK_NAME" ]; then
    echo "A stack name is required!"
    exit 1
  fi
  if [ "true" != "$FORCE_DELETE" ]; then
    FORCE_DELETE="false"
  fi
  show_aws_account
  local STACK_EVENT_TIMESTAMP_FILTER="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  local OUTPUT_DESCRIBE_STACK_STATUS="$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[*].StackStatus" --output text 2>&1)"
  if [[ "$OUTPUT_DESCRIBE_STACK_STATUS" == *"does not exist"* ]]; then
    echo "A stack with the name [$STACK_NAME] does not exist!"
    exit 1
  elif [ "$OUTPUT_DESCRIBE_STACK_STATUS" != "ROLLBACK_COMPLETE" ]; then
    if [ "false" == "$FORCE_DELETE" ]; then
      echo "The expected status for removing a stack is [ROLLBACK_COMPLETE]."
      echo "the status for stack [$STACK_NAME] is [$OUTPUT_DESCRIBE_STACK_STATUS] and will not be deleted!"
      exit 1
    else
      echo '============================================================'
      echo 'Warning: You are about to force delete a stack!'
      echo "  [$STACK_NAME] has a status of: [$OUTPUT_DESCRIBE_STACK_STATUS]"
      echo ' '
      echo ' Are you sure you would like to continue? [type y for yes]'
      echo ' '


echo ' '
echo ' '
echo "TODO:"
echo "  DOES THIS STACK CONTAIN AN S# BUCKET THAT NEEDS TO BE EMPTIED?"
echo "  - aws s3 ls -> match against teh resources declared in the stack to be destroyed!"
echo ' '
echo ' '



      echo '============================================================'
      read CONTINUE_FORCE_DELETE
      if [ "y" != "$CONTINUE_FORCE_DELETE" ]; then
        echo ' '
        echo 'Aborting!'
        exit 1
      fi
    fi
  fi
  # NOTE: For stacks being delete we need to pass the stack id!
  local STACK_ID="$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[*].StackId" --output text 2>&1)"
  echo "  - Deleting stack: $STACK_NAME using its id [$STACK_ID]"
  if [ "true" == "$DRY_RUN" ]; then
    log "************************************************************"
    log "EXECUTING IN DRY RUN MODE: "
    log '   - The following commands would have been executed!'
    log "  [aws cloudformation delete-stack --stack-name \"$STACK_ID\"]"
    log "  [handle_stack_waiter \"$STACK_ID\" \"$STACK_EVENT_TIMESTAMP_FILTER\" \"stack-delete-complete\"]"
    log "************************************************************"
  else
    aws cloudformation delete-stack --stack-name "$STACK_ID"
    echo "  - waiting for stack [$STACK_NAME] status to reach [DELETE_COMPLETE]"
    handle_stack_waiter "$STACK_ID" "$STACK_EVENT_TIMESTAMP_FILTER" "stack-delete-complete"
  fi
}

function check_stack_drift {
  local STACK_NAME="$1"
  if [ "" == "$STACK_NAME" ]; then
    echo "A stack name is required!"
    exit 1
  fi
  echo "  - Checking for stack drift [$STACK_NAME]"
  local OUTPUT_STACK_DRIFT_CHECK_ID="$(aws cloudformation detect-stack-drift --stack-name "$STACK_NAME" --query "StackDriftDetectionId" --output text 2>&1 || true)"
  # Catching a Validation error here: An error occurred (ValidationError) when calling the DetectStackDrift operation: Drift detection cannot be performed on stack [arn:aws:cloudformation:us-east-1:223088857621:stack/sample-fargate-driftcheck-cloudtrail/e9e64cd0-f922-11ea-8979-0ecdc090d557] while it is in [ROLLBACK_COMPLETE] state
  if [[ "$OUTPUT_STACK_DRIFT_CHECK_ID" == *'An error occurred (ValidationError)'* ]]; then
    echo "$OUTPUT_STACK_DRIFT_CHECK_ID"
    exit 1
  fi
  echo "  - Waiting for drift detection [$OUTPUT_STACK_DRIFT_CHECK_ID] to complete..."
  local OUTPUT_STACK_DRIFT_CHECK=''
  for RETRY in ${RETRIES[@]}
  do
    sleep "$RETRY"
    OUTPUT_STACK_DRIFT_CHECK="$(aws cloudformation describe-stack-drift-detection-status --stack-drift-detection-id "$OUTPUT_STACK_DRIFT_CHECK_ID" 2>&1)"
    local STACK_DRIFT_CHECK_STATUS="$(echo "$OUTPUT_STACK_DRIFT_CHECK" | jq -r '.DetectionStatus')"
    if [ "DETECTION_COMPLETE" == "$STACK_DRIFT_CHECK_STATUS" ]; then
      echo "  - Drift detection check is complete! [$STACK_DRIFT_CHECK_STATUS]"
      break;
    elif [ "DETECTION_FAILED" == "$STACK_DRIFT_CHECK_STATUS" ]; then
      echo "  - The stack drift detection operation has failed for at least one resource in the stack! [$STACK_DRIFT_CHECK_STATUS]"
      break;
    else
      echo "  - waiting on status change: [$STACK_DRIFT_CHECK_STATUS]"
    fi
  done

  if [ "DETECTION_FAILED" != "$STACK_DRIFT_CHECK_STATUS" ]; then
    # Here we ensure the drift detection has verified the current template and its resources are in sync.
    local OUTPUT_STACK_DRIFT_CHECK_DRIFT_STATUS="$(echo "$OUTPUT_STACK_DRIFT_CHECK" | jq -r '.StackDriftStatus')"
    if [ "IN_SYNC" != "$OUTPUT_STACK_DRIFT_CHECK_DRIFT_STATUS" ]; then
      echo "  - Drift detection determined this stack is not in sync with the original template! [$STACK_NAME] has status: [$OUTPUT_STACK_DRIFT_CHECK_DRIFT_STATUS]"
      echo '  - Showing Drifts:'
      echo ' '
      local OUTPUT_STACK_DRIFT_CHECK_DRIFT="$(aws cloudformation describe-stack-resource-drifts --stack-name "$STACK_NAME" --query "StackResourceDrifts[?StackResourceDriftStatus!='IN_SYNC']" 2>&1)"
      local DRIFT_COUNT_TOTAL="$(echo "$OUTPUT_STACK_DRIFT_CHECK_DRIFT" | jq -r '.|length')"
      if [ "0" != "$DRIFT_COUNT_TOTAL" ]; then
        for DRIFT_COUNT in $(seq 0 $(($DRIFT_COUNT_TOTAL-1)))
        do
          local DRIFT="$(echo $OUTPUT_STACK_DRIFT_CHECK_DRIFT | jq -r --arg DRIFT_COUNT $DRIFT_COUNT '.[$DRIFT_COUNT|tonumber] | .')"
          local RESOURCE_TYPE="$(echo "$DRIFT" | jq -r '.ResourceType')"
          local RESOURCE_ID="$(echo "$DRIFT" | jq -r '.LogicalResourceId')"
          local PROPERTY_DIFFS="$(echo "$DRIFT" | jq -r '.PropertyDifferences')"
          local DRIFT_STATUS="$(echo "$DRIFT" | jq -r '.StackResourceDriftStatus')"
          echo "    - $RESOURCE_TYPE [$RESOURCE_ID] - $DRIFT_STATUS"
          local DRIFT_PROPERTY_COUNT_TOTAL="$(echo "$PROPERTY_DIFFS" | jq -r '.|length')"
          if [ "0" != "$DRIFT_PROPERTY_COUNT_TOTAL" ]; then
            for DRIFT_PROPERTY_COUNT in $(seq 0 $(($DRIFT_PROPERTY_COUNT_TOTAL-1)))
            do
              local DRIFT_PROPERTY="$(echo $PROPERTY_DIFFS | jq -r --arg DRIFT_PROPERTY_COUNT $DRIFT_PROPERTY_COUNT '.[$DRIFT_PROPERTY_COUNT|tonumber] | .')"
              local DRIFT_PROPERTY_TYPE="$(echo "$DRIFT_PROPERTY" | jq -r '.DifferenceType')"
              local DRIFT_PROPERTY_PATH="$(echo "$DRIFT_PROPERTY" | jq -r '.PropertyPath')"
              local DRIFT_PROPERTY_EXPECTED="$(echo "$DRIFT_PROPERTY" | jq -r '.ExpectedValue')"
              local DRIFT_PROPERTY_ACTUAL="$(echo "$DRIFT_PROPERTY" | jq -r '.ActualValue')"
              echo "      - $DRIFT_PROPERTY_TYPE [$DRIFT_PROPERTY_PATH]"
              echo "        Expected: [$DRIFT_PROPERTY_EXPECTED] | Actual: [$DRIFT_PROPERTY_ACTUAL]"
            done
          fi
        done
      fi
      echo ' '
      echo '============================================================'
      echo 'Warning: Drifts must be resolved before continuing or you will lose the changes made to the resources!'
      echo "  [$STACK_NAME] has a status of: [$OUTPUT_DESCRIBE_STACK_STATUS]"
      echo ' '
      echo "Do you want to override the stacks drifts and apply the templates"
      echo '  changes and continue? [type y for yes]'
      echo ' '
      echo '============================================================'
      read CONTINUE_OVERRIDE_DRIFTS
      if [ "y" != "$CONTINUE_OVERRIDE_DRIFTS" ]; then
        echo ' '
        echo 'Aborting!'
        exit 1
      else
        echo 'Continuing: Drifts will be overwritten and the changes made to the resources will be lost!'
        echo ' '
      fi
    else
      echo "  - Drift detection completed, stack status is: [$OUTPUT_STACK_DRIFT_CHECK_DRIFT_STATUS] compared to the original template. [$STACK_NAME]"
    fi
  fi
}





function deploy {
  echo "Starting Cloudformation deployment:"
  show_aws_account
  set_template_file_list
  for TEMPLATE_FILE in ${TEMPLATE_FILES[@]}
  do
    echo ' '
    echo "Validating template [$TEMPLATE_FILE]"
    validate_template "${TEMPLATE_DIRECTORY}/${TEMPLATE_FILE}"
    echo ' '

    local STACK_NAME="$(generate_stack_name_from_template_file "$TEMPLATE_FILE")"
    echo "Deploy [$STACK_NAME]"
    local STACK_EVENT_TIMESTAMP_FILTER="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    if [ "false" == "$( does_stack_exist "$STACK_NAME" )" ]; then
      echo "  Creating [$STACK_NAME]"
      if [ "true" == "$DRY_RUN" ]; then
        log "************************************************************"
        log "EXECUTING IN DRY RUN MODE: "
        log '   - The following command would have been executed!'
        log "  [create_stack \"$STACK_NAME\" \"$STACK_EVENT_TIMESTAMP_FILTER\" \"${TEMPLATE_DIRECTORY}/${TEMPLATE_FILE}\"]"
        log "************************************************************"
      else
        create_stack "$STACK_NAME" "$STACK_EVENT_TIMESTAMP_FILTER" "${TEMPLATE_DIRECTORY}/${TEMPLATE_FILE}"
      fi
    else
      echo "  Updating [$STACK_NAME]"
      local STACK_CHANGESET_TIMESTAMP="$(date +%Y%m%d%H%M%S)"
  		local STACK_CHANGESET_NAME="$STACK_NAME-$STACK_CHANGESET_TIMESTAMP"
      check_stack_drift "$STACK_NAME"

      echo "  - Starting changeset [$STACK_CHANGESET_NAME]"
      local OUTPUT_CREATE_CHANGE_SET="$(aws cloudformation create-change-set --stack-name "$STACK_NAME" --change-set-name "$STACK_CHANGESET_NAME" --template-body "file://${TEMPLATE_DIRECTORY}/${TEMPLATE_FILE}" 2>&1 || true)"
      # echo "$OUTPUT_CREATE_CHANGE_SET"
      # Catching a Validation error here: An error occurred (ValidationError) when calling the CreateChangeSet operation: Stack:arn:aws:cloudformation:us-east-1:223088857621:stack/sample-fargate-driftcheck-cloudtrail/fc7c4840-f9bd-11ea-b6e9-0a48dc861a07 is in DELETE_FAILED state and can not be updated.
      if [[ "$OUTPUT_CREATE_CHANGE_SET" == *'An error occurred (ValidationError)'* ]]; then
        echo "$OUTPUT_CREATE_CHANGE_SET"
        show_stack_resources_and_statuses "$STACK_NAME"
        exit 1
      fi

      local OUTPUT_DESCRIBE_CHANGE_SET=''
      # Here we loop throu the retries array while we wait on changeset status
      # TODO: Refactor to use wait: https://docs.aws.amazon.com/cli/latest/reference/cloudformation/wait/change-set-create-complete.html
      echo "  - Waiting for Changeset creation to complete..."
      for RETRY in ${RETRIES[@]}
      do
        sleep "$RETRY"
        local OUTPUT_DESCRIBE_CHANGE_SET="$(aws cloudformation describe-change-set --stack-name "$STACK_NAME" --change-set-name "$STACK_CHANGESET_NAME" 2>&1)"
        local CHANGE_SET_STATUS="$(echo "$OUTPUT_DESCRIBE_CHANGE_SET" | jq -r '.Status')"
        # Make the string a constant!!!!
        if [ "CREATE_COMPLETE" == "$CHANGE_SET_STATUS" ]; then
          echo "  - Change set is ready! [$CHANGE_SET_STATUS]"
          break;
        elif [ "FAILED" == "$CHANGE_SET_STATUS" ]; then
          echo ' '
          echo "  - Change set failed: [$CHANGE_SET_STATUS]"
          local CHANGE_SET_STATUS_REASON="$(echo "$OUTPUT_DESCRIBE_CHANGE_SET" | jq -r '.StatusReason')"
          echo "    - $CHANGE_SET_STATUS_REASON"
          break;
        else
          echo "  - waiting on status change: [$CHANGE_SET_STATUS]"
        fi
      done

      local CHANGE_SET_EXECUTION_STATUS="$(echo "$OUTPUT_DESCRIBE_CHANGE_SET" | jq -r '.ExecutionStatus')"
      local CHANGE_COUNT_TOTAL="$(echo "$OUTPUT_DESCRIBE_CHANGE_SET" | jq -r '.Changes|length')"
      if [ "0" != "$CHANGE_COUNT_TOTAL" ]; then
        echo "  ============================================================"
        for CHANGE_COUNT in $(seq 0 $(($CHANGE_COUNT_TOTAL-1)))
        do
          local CHANGE="$(echo $OUTPUT_DESCRIBE_CHANGE_SET | jq -r --arg CHANGE_COUNT $CHANGE_COUNT '.Changes[$CHANGE_COUNT|tonumber] | .')"
          echo "$CHANGE" | jq -r '.'
        done
        echo "  ============================================================"
        echo "  - Change set ExecutionStatus: [$CHANGE_SET_EXECUTION_STATUS]"
        if [ "AVAILABLE" != "$CHANGE_SET_EXECUTION_STATUS" ]; then
          echo "   - ERROR: Unexpected execution status: [$CHANGE_SET_EXECUTION_STATUS]"
        else
          echo "  - Executing change set [$STACK_CHANGESET_NAME]"
          if [ "true" == "$DRY_RUN" ]; then
            log "************************************************************"
            log "EXECUTING IN DRY RUN MODE: "
            log '   - The following command would have been executed!'
            log "  [aws cloudformation execute-change-set --stack-name \"$STACK_NAME\" --change-set-name \"$STACK_CHANGESET_NAME\" 2>&1]"
            log "  [handle_stack_waiter \"$STACK_NAME\" \"$STACK_EVENT_TIMESTAMP_FILTER\" \"stack-update-complete\"]"
            log "************************************************************"
          else
            aws cloudformation execute-change-set --stack-name "$STACK_NAME" --change-set-name "$STACK_CHANGESET_NAME" 2>&1
            echo "  - waiting for stack [$STACK_NAME] status to reach [UPDATE_COMPLETE]"
            handle_stack_waiter "$STACK_NAME" "$STACK_EVENT_TIMESTAMP_FILTER" "stack-update-complete"
          fi
        fi
      else
        echo "  - NO CHANGES - [$STACK_NAME]"
        echo ' '
        continue;
      fi
    fi
  done
}

function show_stack_name_from_files {
  set_template_file_list
  echo "Showing stack names based on the cloudformation template files and product:"
  echo ' '
  echo " Product: [$PRODUCT] - This is used to prefix the base filenames to get the stack name."
  echo " Template Directory: [$TEMPLATE_DIRECTORY] - This is the filesystem location of the cloudformation templates."
  echo ' '
  for TEMPLATE_FILE in ${TEMPLATE_FILES[@]}
  do
    local STACK_NAME="$(generate_stack_name_from_template_file "$TEMPLATE_FILE")"
    echo " - $STACK_NAME from file [$TEMPLATE_FILE]"
  done
  echo ' '
}

# NOTE: This should be refactored but in order to capture all flags and set the properties correctly we can not call the functions directly!!!!!
EXECUTE_FUNCTION=''
EXECUTE_FUNCTION_PARAM=''
while (( "$#" )); do #Referenced: https://medium.com/@Drew_Stokes/bash-argument-parsing-54f3b81a6a8f
  case "$1" in
    -x|--dry-run) export DRY_RUN="true";shift;;
    -q|--quiet) export QUIET="true";shift;;
    -v|--verbose) export VERBOSE="true";shift;;
    -l|--log) export LOG_TO_FILE="true";shift;;
    -k|--location-directory)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export TEMPLATE_DIRECTORY="$2";
        if [ ! -d "$2" ]; then
          log ' ';
          log "The supplied directory does not exist [$TEMPLATE_DIRECTORY]";
          exit 1;
        fi
        shift 2;
      else
        missing_arg "$1"
      fi;;
    -p|--product-name)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export PRODUCT="$2";
        shift 2;
      else
        missing_arg "$1"
      fi;;
    -h|-u|--help|--usage ) export EXECUTE_FUNCTION="usage";shift;;
    -r|--remove-stack)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export EXECUTE_FUNCTION="remove_stack";
        export EXECUTE_FUNCTION_PARAM="$2";
        shift 2;
      else
        missing_arg "$1"
      fi;;
    -f|--force-remove-stack)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export EXECUTE_FUNCTION="force_remove_stack";
        export EXECUTE_FUNCTION_PARAM="$2";
        shift 2;
      else
        missing_arg "$1"
      fi;;
    -y|--stack-events-since-yesterday)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export EXECUTE_FUNCTION="show_stack_event_summaries_since_yesterday";
        export EXECUTE_FUNCTION_PARAM="$2";
        shift 2;
      else
        missing_arg "$1"
      fi;;
    -s|--show-stack-names)export EXECUTE_FUNCTION="show_stack_name_from_files";
        shift;;
    -d|--deploy)export EXECUTE_FUNCTION="deploy";shift;;
    -*|--*=) # Error on unsupported flags
      unsupported_flag "$1";;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1";shift;;
  esac
done
if [ "true" == "$LOG_TO_FILE" ]; then
  touch "$LOGFILE" #This happens after flags are parsed
fi

if [ "" != "$EXECUTE_FUNCTION" ]; then
  # echo "$EXECUTE_FUNCTION $EXECUTE_FUNCTION_PARAM"
  "$EXECUTE_FUNCTION" "$EXECUTE_FUNCTION_PARAM"
else
  usage
fi
