#!/usr/bin/env bash
#
# Created By: stephansarver
# Created Date: 20180702-125058
#
# Dependencies: jq, awscli
#
# ./assume_role.sh --adid=ssarver --region=us-east-1 --role=OrganizationAccountAccessRole --accounts=473830466053
# ./assume_role.sh --adid=YOUR_USERNAME --region=YOUR_REGION --role=YOUR_ROLE --accounts=YOUR_ACCOUNTS_COMMA_SEPERATED_LIST
# set -o errexit
# set -o nounset

clear

aws_account_default_region="us-east-1"
aws_account_provider_prefix='arn:aws:iam::'
aws_account_provider_suffix=':role/'
aws_account_provider_arn=''

aws_profile="default"
aws_assumed_role_out_file='awstmp'
aws_shared_credentials_file='awscreds_'

#Initialize the inputs
input_name_adid="adid"
input_name_region="region"
input_name_role="role"
input_name_accounts="accounts"

input_value_adid=''
input_value_region=''
input_value_role=''
input_value_accounts=''

function usage(){
  echo "USAGE:"
  echo " "
  echo "  Name: $0"
  echo " "
  echo "  Description: "
  echo "      This script is used to run multiple sts role assumptions creating"
  echo "      locally stored temp credentials to allow for quickly switching"
  echo "      between tenants.  This can be donw by switching the environment"
  echo "      variable pointing to the credentials file to use these "
  echo "      credentials files will be stored in the directory that this"
  echo "      script is called from."
  echo "      See additional notes below."
  echo " "
  echo " "
  echo "  Command inputs:"
  echo "      --adid=myadid"
  echo "      --accounts=\"123456789011,123456789012\""
  echo "      --role=your_role_name"
  echo "      --region=us-east-1"
  echo " "
  echo "      The adid is your Active Directoy NT ID that you use for account"
  echo "      federation and is required for identifying the user doing role"
  echo "      assumptions."
  echo "      The accounts parameter is a comma seperated list of accounts that"
  echo "      you want the multi assume script to generate temp credentials for"
  echo "      the siupplied role."
  echo " "
  echo " "
  echo "  Additional Notes:"
  echo "      When using the temporary credentials file you wil need to unset"
  echo "      your profile set in the terminal session:"
  echo "          unset AWS_PROFILE"
  echo " "
  echo "      To use switch to a specific accounts temp creds file you will"
  echo "      need to set the environment variable to point to the temporarty"
  echo "      credentilas file."
  echo " "
  echo "      Example:"
  echo "          export AWS_SHARED_CREDENTIALS_FILE=<THE_CREDS_FILE_YOU_NEED>"
  echo " "
  echo "          aws iam list-account-aliases | jq -r '.AccountAliases | .[]'"
  echo " "
}

echo " "
echo " "

function throw_error(){
  local_param_property=$1
  local_param_message=$2

  echo "********************"
  echo "Error: "
  echo " "
  echo "  $local_param_message $local_param_property"
  echo " "
  echo "********************"
  exit 1
}

# Add validation to show usage if there are no inputs supplied.
if [ 0 -eq $# ]; then
  usage
  throw_error "inputs not found!" "Required"
  exit 1
fi

#exit 1

#Set the parameter values and validate
for arg in $@
do
  if [[ "$arg" == "--$input_name_adid"* ]]; then
    input_value_adid="${arg#*$input_name_adid=}"
    #echo "Set: $input_value_adid"
  elif [[ "$arg" == "--$input_name_accounts"* ]]; then
    input_value_accounts="${arg#*$input_name_accounts=}"
    #echo "Set: $input_value_accounts"
  elif [[ "$arg" == "--$input_name_role"* ]]; then
    input_value_role="${arg#*$input_name_role=}"
    #echo "Set: $input_value_role"
  elif [[ "$arg" == "--$input_name_region"* ]]; then
    input_value_region="${arg#*$input_name_region=}"
    #echo "Set: $input_value_region"
  else
    usage
    echo "********************"
    echo "Error: "
    echo " "
    echo "Unexpected input found: $arg"
    echo " "
    echo "********************"
    exit 1
  fi
done

# Throw errors for missing input values
if [ '' == "$input_value_adid" ]; then
  throw_error "$input_name_adid (Active Director ID)" "A command line input is required for: "
fi
if [ '' == "$input_value_accounts" ]; then
  throw_error "$input_name_accounts (AWS Account numbers)" "A command line input is required for: "
fi
if [ '' == "$input_value_role" ]; then
  throw_error "$input_name_role (AWS Role name)" "A command line input is required for: "
fi
if [ '' == "$input_value_region" ]; then
  throw_error "$input_name_region (AWS region)" "A command line input is required for: "
fi

count=0
# Store original field separator and set to comma for the iteration of the accounts
OIFS=$IFS
IFS=','
for account in ${input_value_accounts[@]}
do
  aws_account_provider_arn="$aws_account_provider_prefix$account$aws_account_provider_suffix$input_value_role"
  #echo "Role assumption for: $input_value_role using arn: $aws_account_provider_arn"
  export "AWS_PROFILE"=$aws_profile
  #echo "Using profile: $AWS_PROFILE"

  assume_out=$((aws sts assume-role --role-arn $aws_account_provider_arn --role-session-name assume-role-script-$count-$input_value_adid)2>&1)

  # echo "++++++++++++++++++++++++++++++++++++++"
  # echo "$assume_out"
  # echo "++++++++++++++++++++++++++++++++++++++"

  #Matching on errors that should make the script exit.
  if [[ $assume_out == *"A client error"* || $assume_out == *"An error occurred"* || $assume_out == *"Connection reset"* ]]; then
    echo "********************"
    echo "Error: "
    echo " "
    echo "$assume_out"
    echo "Please refresh your login credentials!"
    echo " "
    echo "********************"
    exit 1
  fi

  # Set temp assume role output file and parse assume output.
  aws_assumed_role_output="$aws_assumed_role_out_file$count"
  touch $aws_assumed_role_output
  echo "$assume_out" |  jq -r '.Credentials.AccessKeyId, .Credentials.SecretAccessKey, .Credentials.SessionToken'>$aws_assumed_role_output

  #echo "$aws_assumed_role_output"

  # Unset the currently profile currently set in AWS_PROFILE env var and run the aws config into the AWS_SHARED_CREDENTIALS_FILE env var.
  unset AWS_PROFILE
  touch "$aws_shared_credentials_file$account"
  export AWS_SHARED_CREDENTIALS_FILE=$aws_shared_credentials_file$account
  aws configure set aws_access_key_id $(sed -n '1p' $aws_assumed_role_output)
  aws configure set aws_secret_access_key $(sed -n '2p' $aws_assumed_role_output)
  aws configure set aws_session_token $(sed -n '3p' $aws_assumed_role_output)
  aws configure set region "$aws_account_default_region"

  # Unsewt the AWS_SHARED_CREDENTIALS_FILE fot the next iteration.
  unset AWS_SHARED_CREDENTIALS_FILE
  count=$((count+1))
  # Remove the tmp file writen to when storing the sts response.
  rm "$aws_assumed_role_output"
  #echo "The account: $account has temp creds created set ENV var using: export AWS_SHARED_CREDENTIALS_FILE=$aws_shared_credentials_file$account"
  echo "Set temp creds in ENV variables for $account using: export AWS_SHARED_CREDENTIALS_FILE=$aws_shared_credentials_file$account"
done
# Reset the original field separator from the comma after the iteration of the accounts
IFS=$OIFS

echo " "
echo " "
echo "Temp AWS credentials requires you to unset your profile from ENV variables:"
echo "          unset AWS_PROFILE"
echo "See above for setting the shared credentials file into the ENV variables: "
#echo "          export AWS_SHARED_CREDENTIALS_FILE=NAME_OF_YOUR_FILE"
echo "When moving back to using the original aws profile remove the temp shared credentionals from the ENV variables."
echo " "
