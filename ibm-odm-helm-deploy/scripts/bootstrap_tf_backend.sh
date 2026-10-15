#!/usr/bin/env bash
# Source from an authenticated AWS Shell Script task: source scripts/bootstrap_tf_backend.sh
set -Eeuo pipefail
: "${AWS_REGION:?AWS_REGION is required}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
[[ "$ACCOUNT_ID" =~ ^[0-9]{12}$ ]] || { echo 'Invalid AWS account identity' >&2; exit 1; }
TF_STATE_BUCKET="ibm-odm-dev-tfstate-${ACCOUNT_ID}-${AWS_REGION}"
export TF_STATE_BUCKET
# Check ownership rather than just existence; S3 names are global.
if aws s3api head-bucket --bucket "$TF_STATE_BUCKET" --expected-bucket-owner "$ACCOUNT_ID" >/dev/null 2>&1; then
  echo "Using existing owned Terraform state bucket: $TF_STATE_BUCKET"
else
  # Distinguish a missing bucket from inaccessible/foreign buckets.
  if aws s3api head-bucket --bucket "$TF_STATE_BUCKET" >/dev/null 2>&1; then
    echo "State bucket exists but is not owned by expected AWS account; refusing" >&2; exit 1
  fi
  if aws s3api get-bucket-location --bucket "$TF_STATE_BUCKET" >/dev/null 2>&1; then
    echo "State bucket accessible but owner validation failed; refusing" >&2; exit 1
  fi
  echo "Creating Terraform state bucket: $TF_STATE_BUCKET"
  aws s3api create-bucket --bucket "$TF_STATE_BUCKET" --region "$AWS_REGION" \
    --create-bucket-configuration "LocationConstraint=$AWS_REGION"
  aws s3api wait bucket-exists --bucket "$TF_STATE_BUCKET"
fi
# Fail closed on any security configuration error. Reconcile existing buckets too.
aws s3api put-public-access-block --bucket "$TF_STATE_BUCKET" --expected-bucket-owner "$ACCOUNT_ID" \
  --public-access-block-configuration 'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
aws s3api put-bucket-versioning --bucket "$TF_STATE_BUCKET" --expected-bucket-owner "$ACCOUNT_ID" \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$TF_STATE_BUCKET" --expected-bucket-owner "$ACCOUNT_ID" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api get-public-access-block --bucket "$TF_STATE_BUCKET" --expected-bucket-owner "$ACCOUNT_ID" >/dev/null
[[ "$(aws s3api get-bucket-versioning --bucket "$TF_STATE_BUCKET" --expected-bucket-owner "$ACCOUNT_ID" --query Status --output text)" == Enabled ]] || exit 1
[[ "$(aws s3api get-bucket-encryption --bucket "$TF_STATE_BUCKET" --expected-bucket-owner "$ACCOUNT_ID" --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' --output text)" == AES256 ]] || exit 1
[[ "$(aws s3api get-bucket-location --bucket "$TF_STATE_BUCKET" --expected-bucket-owner "$ACCOUNT_ID" --query LocationConstraint --output text)" == "$AWS_REGION" ]] || { echo 'Unexpected bucket region' >&2; exit 1; }
echo "Terraform state backend secured: $TF_STATE_BUCKET ($AWS_REGION)"
