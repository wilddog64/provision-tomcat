#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"

_err() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

command -v aws >/dev/null 2>&1 || _err "aws CLI not found"

NEW_SUBNET_ID=$(aws ec2 describe-subnets --region "${AWS_REGION}" --filters "Name=tag:Project,Values=Tomcat-Provisioning" "Name=tag:Type,Values=Test" --query "Subnets[0].SubnetId" --output text 2>/dev/null)
if [[ "${NEW_SUBNET_ID}" == "None" || -z "${NEW_SUBNET_ID}" ]]; then
  NEW_SUBNET_ID=$(aws ec2 describe-subnets --region "${AWS_REGION}" --filters "Name=availability-zone,Values=${AWS_REGION}e" --query "Subnets[0].SubnetId" --output text 2>/dev/null)
fi
if [[ "${NEW_SUBNET_ID}" == "None" || -z "${NEW_SUBNET_ID}" ]]; then
  NEW_SUBNET_ID=$(aws ec2 describe-subnets --region "${AWS_REGION}" --query "Subnets[0].SubnetId" --output text 2>/dev/null)
fi
[[ "${NEW_SUBNET_ID}" == "None" || -z "${NEW_SUBNET_ID}" ]] && _err "Failed to discover subnet"

NEW_SECURITY_GROUP_IDS=$(aws ec2 describe-security-groups --region "${AWS_REGION}" --filters "Name=tag:Project,Values=Tomcat-Provisioning" "Name=tag:Type,Values=Test" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)
if [[ "${NEW_SECURITY_GROUP_IDS}" == "None" || -z "${NEW_SECURITY_GROUP_IDS}" ]]; then
  NEW_SECURITY_GROUP_IDS=$(aws ec2 describe-security-groups --region "${AWS_REGION}" --filters "Name=group-name,Values=default" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)
fi
[[ "${NEW_SECURITY_GROUP_IDS}" == "None" || -z "${NEW_SECURITY_GROUP_IDS}" ]] && _err "Failed to discover security group"

NEW_AMI_ID=$(aws ec2 describe-images --region "${AWS_REGION}" --owners amazon --filters "Name=name,Values=Windows_Server-2019-English-Full-Base*" --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text 2>/dev/null)
if [[ "${NEW_AMI_ID}" == "None" || -z "${NEW_AMI_ID}" ]]; then
  NEW_AMI_ID=$(aws ec2 describe-images --region "${AWS_REGION}" --owners amazon --filters "Name=name,Values=Windows_Server-2016-English-Full-Base*" --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text 2>/dev/null)
fi
[[ "${NEW_AMI_ID}" == "None" || -z "${NEW_AMI_ID}" ]] && _err "Failed to discover AMI"

NEW_AZ=$(aws ec2 describe-subnets --region "${AWS_REGION}" --subnet-ids "${NEW_SUBNET_ID}" --query "Subnets[0].AvailabilityZone" --output text 2>/dev/null || echo "${AWS_REGION}e")
NEW_REGION=$(aws configure --region "${AWS_REGION}" get region 2>/dev/null || echo "${AWS_REGION}")

printf 'AWS_SUBNET_ID=%s\n' "${NEW_SUBNET_ID}"
printf 'AWS_SECURITY_GROUP_ID=%s\n' "${NEW_SECURITY_GROUP_IDS}"
printf 'AWS_SECURITY_GROUP_IDS=["%s"]\n' "${NEW_SECURITY_GROUP_IDS}"
printf 'AWS_AMI_ID=%s\n' "${NEW_AMI_ID}"
printf 'AWS_AZ=%s\n' "${NEW_AZ}"
printf 'AWS_REGION=%s\n' "${NEW_REGION}"
