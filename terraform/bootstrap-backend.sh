#!/usr/bin/env bash
# Création du bucket S3 (state) et la table DynamoDB (verrou) nécessaires
# au backend distant Terraform. À lancer UNE SEULE FOIS, avant le premier
# `terraform init`. Nécessite AWS CLI configuré (aws configure).
set -euo pipefail

REGION="${AWS_REGION:-eu-west-1}"
BUCKET="devops-app-deploy-tfstate"
TABLE="devops-app-deploy-tf-locks"

echo "Creating S3 bucket for Terraform state: ${BUCKET}"
aws s3api create-bucket \
  --bucket "${BUCKET}" \
  --region "${REGION}" \
  --create-bucket-configuration LocationConstraint="${REGION}"

aws s3api put-bucket-versioning \
  --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "${BUCKET}" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "Creating DynamoDB table for state locking: ${TABLE}"
aws dynamodb create-table \
  --table-name "${TABLE}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${REGION}"

echo "Done. Uncomment the S3 backend block in versions.tf, then run:"
echo "  terraform init"
