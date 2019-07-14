#!/bin/sh

echo "Checking currently configured AWS credentials"
aws sts get-caller-identity \
    || {
    echo "ERROR: AWS credentials are not valid." >&2
    exit 1
}

STATE_FILE_JSON=$(mktemp)
trap 'rm $STATE_FILE_JSON' EXIT

ACCOUNT_NAME=$(openssl rand -hex 8)

read_status_json() {
    # first parameter is the JSON field inside of CreateAccountStatus
    jq "CreateAccountStatus.$1" $STATE_JSON_FILE
}

echo "Creating a new AWS account under the existing organization"
aws organizations create-account \
    --email "$ACCOUNT_NAME@company.com" \
    --account-name $ACCOUNT_NAME \
2>&1 > $STATE_JSON_FILE

while [ "$(jq CreateAccountStatus.State $STATE_JSON_FILE)" = "IN_PROGRESS" ]; do
    sleep 10

    aws organizations describe-create-account-status \
        --create-account-request-id "$(jq CreateAccountStatus.Id $STATE_JSON_FILE)" \
    2>&1 > $STATE_JSON_FILE \
    || {
        echo "ERROR: Could not describe account creation status." >&2
        cat $STATE_JSON_FILE >&2
        exit 1
    }
done

if [ "$(jq CreateAccountStatus.State $STATE_JSON_FILE)" != "SUCCEEDED" ]; then
    echo "ERROR: Failed to create a new Account under AWS Organization" >&2
    cat $STATE_JSON_FILE >&2
    exit 1
fi

echo "Successfully created a new AWS Account under AWS Organization"
echo
echo "Account ID: $(jq CreateAccountStatus.AccountId $STATE_JSON_FILE)"
echo
echo "Assume role ARN:"
echo "    arn:aws:iam::$(jq CreateAccountStatus.AccountId $STATE_JSON_FILE):role/OrganizationAccountAccessRole"
echo

ASSUME_ROLE_JSON_FILE=$(mktemp)
trap 'rm $ASSUME_ROLE_JSON_FILE $STATE_JSON_FILE' EXIT
aws sts assume-role \
    --role-arn "arn:aws:iam::$(jq CreateAccountStatus.AccountId $STATE_JSON_FILE):role/OrganizationAccountAccessRole" \
    --role-session-name AccountCreationSession \
2>&1 > $ASSUME_ROLE_JSON_FILE \
|| {
    echo "ERROR: Could not successfully AssumeRole" >&2
    cat $ASSUME_ROLE_JSON_FILE >&2
    exit 1
}

echo "Temporary credentials from sts:AssumeRole will expire at $(jq .Credentials.Expiration $ASSUME_ROLE_JSON_FILE)"
echo "    export AWS_ACCESS_KEY_ID=$(jq .Credentials.AccessKeyId $ASSUME_ROLE_JSON_FILE)"
echo "    export AWS_SECRET_ACCESS_KEY=$(jq .Credentials.SecretAccessKey $ASSUME_ROLE_JSON_FILE)"
echo "    export AWS_SESSION_TOKEN=$(jq .Credentials.SessionToken $ASSUME_ROLE_JSON_FILE)"
echo
