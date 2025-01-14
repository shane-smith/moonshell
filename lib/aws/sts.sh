#!/usr/bin/env bash
#
# SECURITY TOKEN SERVICE FUNCTIONS
#
sts_account_id () {
    aws sts get-caller-identity \
        --region ${AWS_REGION} \
        --query "Account" \
        --output text
    return $?
}

sts_assume_role () {
    if [[ $# -lt 2 ]] ;then
        echoerr "Usage: ${FUNCNAME[0]} STACK_NAME ROLE_NAME [DURATION_SECONDS]"
        return 1
    fi

    local stack_name="$1"
    local role="$2"
    local duration="${3:-3600}"

    # See: aws sts assume-role help
    if [[ ! ${duration} =~ ^[0-9]+$ ]]; then
        echoerr "ERROR: Duration is not an integer"
        return 1
    elif [[ ${duration} -lt 900 ]]; then
        duration=900
    elif [[ ${duration} -gt 43200 ]]; then
        duration=43200
    fi

    local role_arn role_output role_resource_id role_session_name

    echoerr "INFO: Finding resource id for logical resource: ${role}"
    role_resource_id=$(stack_resource_id ${stack_name} ${role} 2>/dev/null)

    if [[ -z ${role_resource_id-} ]]; then
        echoerr "ERROR: Can not find logical resource: ${role}"
        return 1
    fi

    echoerr "INFO: Finding ARN for logical resource: ${role_resource_id}"
    role_arn=$(aws iam list-roles --query "Roles[?RoleName=='${role_resource_id}'].Arn" --output text)

    if [[ -z ${role_arn-} ]]; then
        echoerr "ERROR: Can not find an ARN for role: ${role_resource_id}"
        return 1
    fi

    role_session_name="${USER}-${role}"

    echoerr "INFO: Assuming role for session: ${role_session_name}"
    role_output=$(aws sts assume-role \
        --role-arn ${role_arn} \
        --role-session-name ${role_session_name})

    if [[ -z ${role_output-} ]]; then
        echoerr "ERROR: Can not find an ARN for role: ${role_resource_id}"
        return 1
    fi

    export AWS_ASSUMED_ROLE_USER_ARN=$(echo ${role_output} | jq -r '.AssumedRoleUser.Arn')
    export AWS_CREDENTIALS_EXPIRATION=$(echo ${role_output} | jq -r '.Credentials.Expiration')

    export AWS_ACCESS_KEY_ID=$(echo ${role_output} | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo ${role_output} | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo ${role_output} | jq -r '.Credentials.SessionToken')

    echoerr "INFO: Assumed role of: ${AWS_ASSUMED_ROLE_USER_ARN}"

    unset role_output
}
