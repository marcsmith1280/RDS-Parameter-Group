#!/bin/bash

if [[ "$#" < 1 ]]; then
    echo
    echo "Usage: $(basename $0) <account_id>"
    echo
    exit 1
fi

account_id=$1
json_file="bin/example/postgres15-rds-parameter-final.json"  # Hardcoded path in repo

# Validate JSON format
if ! jq empty "$json_file" >/dev/null 2>&1; then
    echo "Error: JSON file is not properly formatted."
    exit 1
fi

# Assume role to get AWS credentials
aws sts assume-role --role-arn "arn:aws:iam::${account_id}:role/${ROLE}" --role-session-name Jenkins-Session > assume-out.txt

AWS_ACCESS_KEY_ID=$(grep AccessKeyId assume-out.txt | awk '{print $2}' | tr -d '",')
AWS_SECRET_ACCESS_KEY=$(grep SecretAccessKey assume-out.txt | awk '{print $2}' | tr -d '",')
AWS_SESSION_TOKEN=$(grep SessionToken assume-out.txt | awk '{print $2}' | tr -d '",')

echo
echo "#####"
echo "Checking Account: $account_id"
echo "Alias: $(aws iam list-account-aliases --query 'AccountAliases[0]' --output=text)"

# Create DB Parameter Group
aws rds create-db-parameter-group \
    --db-parameter-group-name "${DB_PARAMETER_GROUP_NAME}" \
    --db-parameter-group-family "${DB_PARAMETER_GROUP_FAMILY}" \
    --description "Reviewed and approved by CMS ISSO, hardened RDS parameter group" \
    --tags '[{"Key": "ADO", "Value": "CCOM"},{"Key": "EngineType", "Value": "'"${ENGINE_TYPE}"'"},{"Key": "EngineVersion", "Value": "'"${ENGINE_VERSION}"'"},{"Key": "Name", "Value": "'"${DB_PARAMETER_GROUP_NAME}"'"},{"Key": "POC", "Value": "email address"},{"Key": "CMS ISSO", "Value": "approved"}]'

# Modify DB Parameter Group using the JSON file from the repo
aws rds modify-db-parameter-group \
    --db-parameter-group-name "${DB_PARAMETER_GROUP_NAME}" \
    --cli-input-json file://"$json_file"

echo "#####"
rm assume-out.txt
