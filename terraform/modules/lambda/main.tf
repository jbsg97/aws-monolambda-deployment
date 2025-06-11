# Local variables for module configuration
locals {
  dummy_key = "dummy_lambda.zip"  # Used for initial deployment, replaced by GitHub Action
}

# AWS Lambda Function Resource
# This resource creates a Lambda function with configurable settings.
# The lifecycle block ignores changes to s3_key and source_code_hash as they are updated externally by a GitHub Action.
resource "aws_lambda_function" "lambda" {
  function_name = "${var.function_name}_${var.environment}"
  memory_size   = var.memory_size
  timeout       = var.timeout
  s3_bucket     = var.s3_bucket
  s3_key        = local.dummy_key
  handler       = var.handler
  runtime       = var.runtime
  role          = var.role_arn
  source_code_hash = var.source_code_hash

  # Environment variables for the Lambda function
  environment {
    variables = merge(var.environment_variables, {
      ENVIRONMENT = var.environment
    })
  }

  # Tags for resource identification and management
  tags = merge(var.tags, {
    Environment = var.environment
  })

  # Lambda layers for additional dependencies
  layers = var.layers

  # VPC configuration for Lambda if specified
  dynamic "vpc_config" {
    for_each = var.vpc_subnet_ids != null && var.vpc_security_group_ids != null ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  # Dead Letter Queue configuration for error handling if specified
  dynamic "dead_letter_config" {
    for_each = var.dead_letter_queue_arn != null ? [1] : []
    content {
      target_arn = var.dead_letter_queue_arn
    }
  }

  # Tracing configuration for AWS X-Ray if enabled
  dynamic "tracing_config" {
    for_each = var.tracing_enabled ? [1] : []
    content {
      mode = "Active"
    }
  }

  # Lifecycle policy to ignore changes managed externally
  lifecycle {
    ignore_changes = [
      s3_key,
      source_code_hash
    ]
  }

  # Enable versioning for Lambda function updates and rollbacks
  publish = true
}

# AWS Lambda Alias for Feature Testing
# This resource is conditionally created if a feature_name is provided.
resource "aws_lambda_alias" "feature_alias" {
  count            = var.feature_name != "" ? 1 : 0
  name             = "${var.environment}-${var.feature_name}"
  description      = "Alias for feature testing"
  function_name    = aws_lambda_function.lambda.function_name
  function_version = aws_lambda_function.lambda.version
}

# AWS Lambda Provisioned Concurrency Configuration
# This is conditionally created if provisioned_concurrency is greater than 0.
resource "aws_lambda_provisioned_concurrency_config" "provisioned_concurrency" {
  count                             = var.provisioned_concurrency > 0 ? 1 : 0
  function_name                     = aws_lambda_function.lambda.function_name
  qualifier                         = aws_lambda_function.lambda.version
  provisioned_concurrent_executions = var.provisioned_concurrency
}
