# Data sources for AWS information
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# IAM Role for Lambda Functions
resource "aws_iam_role" "lambda_shared_role" {
  name = "mvshub-lambda-shared-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = merge(
    var.project_tags,
    {
      Name = "MVSHub Lambda Shared Role"
    }
  )
}

# IAM Policy for Lambda to invoke other Lambda functions
resource "aws_iam_role_policy" "lambda_invoke_policy" {
  name = "lambda-invoke-policy"
  role = aws_iam_role.lambda_shared_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          "arn:aws:lambda:*:${data.aws_caller_identity.current.account_id}:function:*"
        ]
      }
    ]
  })
}

# Attach AWS Lambda Basic Execution Role
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_shared_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# S3 Buckets for Lambda Artifacts
resource "aws_s3_bucket" "lambda_artifacts" {
  for_each = var.s3_buckets
  
  bucket = each.value
  force_destroy = true

  tags = merge(
    var.project_tags,
    {
      Name = "Lambda Artifacts - ${each.key}"
      Environment = each.key == "dummy_lambda" ? "all" : each.key
    }
  )
}

# Dummy Lambda for initial setup (to be replaced with real deployment logic)
data "archive_file" "dummy_lambda" {
  type        = "zip"
  source_dir  = "modules/lambda/dummy"
  output_path = "modules/lambda/dummy/dummy_lambda.zip"
}

resource "aws_s3_object" "lambda_dummy" {
  bucket = aws_s3_bucket.lambda_artifacts["dummy_lambda"].id
  key    = "dummy_lambda.zip"
  source = data.archive_file.dummy_lambda.output_path
  etag   = filemd5(data.archive_file.dummy_lambda.output_path)

  tags = merge(
    var.project_tags,
    {
      Name = "Dummy Lambda Artifact"
    }
  )
}

# Dynamic Lambda Modules for each Function and Environment
# This reduces code duplication by creating Lambda resources for each function across all environments
module "lambda_functions" {
  for_each = {
    for pair in setproduct(keys(var.lambda_functions), keys(local.environments)) : "${pair[0]}-${pair[1]}" => {
      function_name = pair[0]
      env           = pair[1]
    }
  }
  
  source        = "./modules/lambda"
  source_dir    = var.lambda_functions[each.value.function_name].source_dir
  function_name = each.value.function_name
  environment   = each.value.env
  s3_bucket     = aws_s3_bucket.lambda_artifacts["dummy_lambda"].id
  memory_size   = local.environments[each.value.env].lambda_config.memory_size
  timeout       = local.environments[each.value.env].lambda_config.timeout
  handler       = var.lambda_functions[each.value.function_name].handler
  runtime       = var.lambda_functions[each.value.function_name].runtime
  environment_variables = local.environments[each.value.env].lambda_config.environment_variables
  tags          = merge(
    local.environments[each.value.env].tags,
    {
      Author = var.lambda_functions[each.value.function_name].authors[each.value.env]
    }
  )
  role_arn      = aws_iam_role.lambda_shared_role.arn
  layers        = var.lambda_functions[each.value.function_name].layers
  source_code_hash = "dummy-hash"  # TODO: Replace with actual hash from deployment process
}

# DynamoDB Table for Lambda Deployments Tracking
resource "aws_dynamodb_table" "lambda_deployments" {
  name           = "lambda-deployments"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "deployment_id"
  range_key      = "environment"

  attribute {
    name = "deployment_id"
    type = "S"
  }

  attribute {
    name = "function_name"
    type = "S"
  }

  attribute {
    name = "environment"
    type = "S"
  }

  global_secondary_index {
    name               = "function_env_index"
    hash_key           = "function_name"
    range_key          = "environment"
    projection_type    = "ALL"
  }

  tags = merge(
    var.project_tags,
    {
      Name        = "Lambda Deployments Tracking"
      Environment = "all"
    }
  )
}

# API Gateway for Lambda Functions
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "lambda-feature-api"
  protocol_type = "HTTP"
  description   = "API Gateway for feature testing"

  tags = merge(
    var.project_tags,
    {
      Name = "Lambda Feature API"
    }
  )
}

# API Gateway Stages for each Environment
resource "aws_apigatewayv2_stage" "base_stages" {
  for_each = local.environments

  api_id      = aws_apigatewayv2_api.lambda_api.id
  name        = each.key
  auto_deploy = true

  tags = merge(
    each.value.tags,
    {
      Name = "Base ${each.key} stage"
    }
  )
}
