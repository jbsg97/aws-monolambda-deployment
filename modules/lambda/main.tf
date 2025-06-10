locals {
  dummy_key = "dummy/lambda.zip"
  lambda_s3_key = "${var.function_name}/${var.source_code_hash}/function.zip"
}

# Create the actual Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.source_dir  # Add this variable to your variables.tf
  output_path = "${path.module}/files/${var.function_name}.zip"
}

resource "aws_s3_object" "lambda_dummy" {
  bucket = var.s3_bucket
  key    = local.dummy_key
  source = "${path.module}/dummy/dummy.zip"

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_s3_object" "lambda_package" {
  bucket = var.s3_bucket
  key    = local.lambda_s3_key
  source = data.archive_file.lambda_zip.output_path
  etag   = filemd5(data.archive_file.lambda_zip.output_path)
}

resource "aws_lambda_function" "lambda" {
  function_name = "${var.function_name}_${var.environment}"
  memory_size   = var.memory_size
  timeout       = var.timeout
  s3_bucket     = var.s3_bucket
  s3_key        = local.lambda_s3_key
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
  depends_on = [
    aws_s3_object.lambda_dummy,
    aws_s3_object.lambda_package  # Add dependency on the actual package
  ]
}

resource "aws_lambda_alias" "feature_alias" {
  name             = "${var.environment}-${var.feature_name}"
  description      = "Alias for feature testing"
  function_name    = aws_lambda_function.lambda.function_name
  function_version = aws_lambda_function.lambda.version

  count = var.feature_name != "" ? 1 : 0
}