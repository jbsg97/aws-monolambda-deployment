locals {
  dummy_key = "dummy_lambda.zip"
}

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
  environment {
    variables = merge(var.environment_variables, {
      ENVIRONMENT = var.environment
    })
  }
  tags = merge(var.tags, {
    Environment = var.environment
  })
  layers = var.layers
  lifecycle {
    ignore_changes = [
      s3_key,
      source_code_hash
    ]
  }
  publish = true  # Enable versioning
}

resource "aws_lambda_alias" "feature_alias" {
  name             = "${var.environment}-${var.feature_name}"
  description      = "Alias for feature testing"
  function_name    = aws_lambda_function.lambda.function_name
  function_version = aws_lambda_function.lambda.version

  count = var.feature_name != "" ? 1 : 0
}