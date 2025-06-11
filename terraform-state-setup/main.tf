# Terraform Configuration for State Management Resources
# This configuration creates the necessary AWS resources for storing Terraform state remotely.

provider "aws" {
  region = "us-east-1"  # Adjust to your preferred region
}

# S3 Bucket for Terraform State Storage
resource "aws_s3_bucket" "terraform_state" {
  bucket = "mvshub-terraform-state"  # Replace with your desired bucket name

  # Enable versioning to keep historical state files for recovery
  versioning {
    enabled = true
  }

  # Enable server-side encryption for security
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "Terraform State Bucket"
    Environment = "All"
    Purpose     = "Terraform State Storage"
  }
}

# S3 Bucket Policy for Access Control
resource "aws_s3_bucket_policy" "terraform_state_policy" {
  bucket = aws_s3_bucket.terraform_state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"  # Restrict to your AWS account
        }
        Action    = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource  = "${aws_s3_bucket.terraform_state.arn}/state/*"
      }
    ]
  })
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# DynamoDB Table for Terraform State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "mvshub-terraform-locks"  # Replace with your desired table name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform Lock Table"
    Environment = "All"
    Purpose     = "Terraform State Locking"
  }
}

# Output the S3 Bucket Name
output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

# Output the DynamoDB Table Name
output "lock_table_name" {
  description = "Name of the DynamoDB table for Terraform state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}
