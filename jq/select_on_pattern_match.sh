#!/usr/bin/env bash
#
# Created By: sarvers
# Created Date: 20200617-171814
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

MESSAGE=$(cat <<HEREDOCMESSAGE
{
    "ConfigRules": [
        {
            "ConfigRuleName": "SOMEPREFIX-BucketPublicReadProhibit-SOMESUFFIX",
            "ConfigRuleArn": "arn:aws:config:us-east-1:123456789012:config-rule/config-rule-123450",
            "ConfigRuleId": "config-rule-123450",
            "Scope": {
                "ComplianceResourceTypes": [
                    "AWS::S3::Bucket"
                ]
            },
            "Source": {
                "Owner": "AWS",
                "SourceIdentifier": "S3_BUCKET_PUBLIC_READ_PROHIBITED"
            },
            "ConfigRuleState": "ACTIVE"
        },
        {
            "ConfigRuleName": "SOMEPREFIX-EBSEncryptionAtRestCheck-SOMESUFFIX",
            "ConfigRuleArn": "arn:aws:config:us-east-1:123456789012:config-rule/config-rule-123451",
            "ConfigRuleId": "config-rule-123451",
            "Source": {
                "Owner": "AWS",
                "SourceIdentifier": "ENCRYPTED_VOLUMES"
            },
            "ConfigRuleState": "ACTIVE"
        },
        {
            "ConfigRuleName": "SOMEPREFIX-RDSEncryptionAtRestCheck-SOMESUFFIX",
            "ConfigRuleArn": "arn:aws:config:us-east-1:123456789012:config-rule/config-rule-123452",
            "ConfigRuleId": "config-rule-123452",
            "Source": {
                "Owner": "AWS",
                "SourceIdentifier": "RDS_STORAGE_ENCRYPTED"
            },
            "ConfigRuleState": "ACTIVE"
        },
        {
            "ConfigRuleName": "SOMEPREFIX-S3EncryptionAtRestCheckR-SOMESUFFIX",
            "ConfigRuleArn": "arn:aws:config:us-east-1:123456789012:config-rule/config-rule-123453",
            "ConfigRuleId": "config-rule-123454",
            "Source": {
                "Owner": "AWS",
                "SourceIdentifier": "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
            },
            "ConfigRuleState": "ACTIVE"
        }
    ]
}
HEREDOCMESSAGE
)

CONFIG_RULE_NAME_PATTERN="S3EncryptionAtRestCheck"
echo "$MESSAGE" | jq -r --arg CONFIG_RULE_NAME_PATTERN $CONFIG_RULE_NAME_PATTERN '.ConfigRules[] | select(.ConfigRuleName|test("." + $CONFIG_RULE_NAME_PATTERN + ".")) | .ConfigRuleName'
