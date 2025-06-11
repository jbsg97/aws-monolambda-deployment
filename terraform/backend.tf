# Terraform Backend Configuration for Remote State Management
# This configuration sets up an S3 backend for storing Terraform state files,
# with DynamoDB for state locking to prevent concurrent modifications.

terraform {
  backend "s3" {
    bucket         = "mvshub-terraform-state"  # Replace with your S3 bucket name
    key            = "state/terraform.tfstate"  # Path within the bucket for the state file
    region         = "us-east-1"               # AWS region for the S3 bucket
    dynamodb_table = "mvshub-terraform-locks"  # DynamoDB table for state locking
  }
}
