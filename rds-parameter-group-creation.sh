#!/bin/bash

# Ensure at least one argument (account_id) is provided
if [[ "$#" < 1 ]]; then
    echo
    echo "Usage: $(basename $0) <account_id>"
    echo
    exit 1  # Exit with an error if no account ID is provided
fi

# Assign the first argument as the AWS account ID
account_id=$1

# Define the JSON file containing RDS parameters (hardcoded path in the repository)
json_file="bin/example/postgres15-rds-parameter-final.json"

# Validate the JSON format using jq
if ! jq empty "$json_file" >/dev/null 2>&1; then
    echo "Error: JSON file is not properly formatted."
    exit 1  # Exit if JSON validation fails
fi

# Assume an IAM role to obtain temporary AWS credentials for the given account
aws sts assume-role --role-arn "arn:aws:iam::${account_id}:role/${ROLE}" --role-session-name Jenkins-Session > assume-out.txt

# Extract temporary credentials from the assume-role output file
AWS_ACCESS_KEY_ID=$(grep AccessKeyId assume-out.txt | awk '{print $2}' | tr -d '",')
AWS_SECRET_ACCESS_KEY=$(grep SecretAccessKey assume-out.txt | awk '{print $2}' | tr -d '",')
AWS_SESSION_TOKEN=$(grep SessionToken assume-out.txt | awk '{print $2}' | tr -d '",')

echo
echo "#####"
echo "Checking Account: $account_id"

# Retrieve and display the AWS account alias (friendly name for easier identification)
echo "Alias: $(aws iam list-account-aliases --query 'AccountAliases[0]' --output=text)"

# Create a new RDS DB parameter group with predefined configurations
aws rds create-db-parameter-group \
    --db-parameter-group-name "${DB_PARAMETER_GROUP_NAME}" \
    --db-parameter-group-family "${DB_PARAMETER_GROUP_FAMILY}" \
    --description "Reviewed and approved by ISSO, hardened RDS parameter group" \
    --tags '[{"Key": "Name", "Value": "RDS-database"},{"Key": "EngineType", "Value": "'"${ENGINE_TYPE}"'"},{"Key": "EngineVersion", "Value": "'"${ENGINE_VERSION}"'"},{"Key": "Name", "Value": "'"${DB_PARAMETER_GROUP_NAME}"'"},{"Key": "POC", "Value": "email address"},{"Key": "ISSO", "Value": "approved"}]'

# Apply parameter modifications from the JSON file to the created DB parameter group
aws rds modify-db-parameter-group \
    --db-parameter-group-name "${DB_PARAMETER_GROUP_NAME}" \
    --cli-input-json file://"$json_file"

echo "#####"

# Remove the assume-role credentials file after execution for security
rm assume-out.txt

