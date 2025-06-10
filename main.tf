data "aws_region" "current" {}

data "archive_file" "lambda_a_dev" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/lambda-a"
  output_path = "${path.module}/.terraform/archive_files/lambda_a_dev.zip"
}

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

  tags = {
    Name = "MVSHub Lambda Shared Role"
    Project = "MVSHUB"
    ManagedBy = "Terraform"
  }
}

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

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_shared_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_s3_bucket" "lambda_artifacts" {
  for_each = {
    dev  = "mvshub-lambda-artifacts-dev"
    qa   = "mvshub-lambda-artifacts-qa"
    prod = "mvshub-lambda-artifacts-prod"
  }
  
  bucket = each.value
  force_destroy = true
}

module "lambda_a_dev" {
  source        = "./modules/lambda"
  source_dir = "./lambdas/lambda-a"
  function_name = "lambda-a"
  environment   = "dev"
  s3_bucket     = aws_s3_bucket.lambda_artifacts["dev"].id
  memory_size   = local.environments.dev.lambda_config.memory_size
  timeout       = local.environments.dev.lambda_config.timeout
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  environment_variables = {
    db_mvshub = "1233213"
    db_pass = "dsadw232"
  }
  tags          = merge(local.environments.dev.tags, {
    Autor       = "Will Smith"   
  })
  role_arn = aws_iam_role.lambda_shared_role.arn
  layers = ["arn:aws:lambda:us-east-1:017000801446:layer:AWSLambdaPowertoolsPythonV2:78"]
  source_code_hash = data.archive_file.lambda_a_dev.output_base64sha256
  depends_on = [aws_s3_bucket.lambda_artifacts]
}

module "lambda_a_qa" {
  source        = "./modules/lambda"
  source_dir = "./lambdas/lambda-a"
  function_name = "lambda-a"
  environment   = "qa"
  s3_bucket     = aws_s3_bucket.lambda_artifacts["qa"].id
  memory_size   = local.environments.qa.lambda_config.memory_size
  timeout       = local.environments.qa.lambda_config.timeout
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  environment_variables = {
    db_mvshub = "1233213"
    db_pass = "dsadw232"
  }
  tags          = merge(local.environments.qa.tags, {
    Autor       = "Will Smith" 
  })
  role_arn = aws_iam_role.lambda_shared_role.arn
  layers = ["arn:aws:lambda:us-east-1:017000801446:layer:AWSLambdaPowertoolsPythonV2:78"]
  source_code_hash = "dummy-hash"
  depends_on = [aws_s3_bucket.lambda_artifacts]
}

module "lambda_a_prod" {
  source        = "./modules/lambda"
  source_dir = "./lambdas/lambda-a"
  function_name = "lambda-a"
  environment   = "prod"
  s3_bucket     = aws_s3_bucket.lambda_artifacts["prod"].id
  memory_size   = local.environments.prod.lambda_config.memory_size
  timeout       = local.environments.prod.lambda_config.timeout
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  environment_variables = {
    db_mvshub = "1233213"
    db_pass = "dsadw232"
  }
  tags          = merge(local.environments.prod.tags, {
    Autor       = "Will Smith"  
  })
  role_arn = aws_iam_role.lambda_shared_role.arn
  layers = ["arn:aws:lambda:us-east-1:017000801446:layer:AWSLambdaPowertoolsPythonV2:78"]
  source_code_hash = "dummy-hash"
  depends_on = [aws_s3_bucket.lambda_artifacts]
}

module "lambda_b_dev" {
  source        = "./modules/lambda"
  source_dir = "./lambdas/lambda-b"
  function_name = "lambda-b"
  environment   = "dev"
  s3_bucket     = aws_s3_bucket.lambda_artifacts["dev"].id
  memory_size   = local.environments.dev.lambda_config.memory_size
  timeout       = local.environments.dev.lambda_config.timeout
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  environment_variables = {
    db_cache = "weqee"
    db_pass = "fasfd"
  }
  tags          = merge(local.environments.dev.tags, {
    Autor       = "John Doe"  
  })
  role_arn = aws_iam_role.lambda_shared_role.arn
  source_code_hash = "dummy-hash"
  depends_on = [aws_s3_bucket.lambda_artifacts]
}

module "lambda_b_qa" {
  source        = "./modules/lambda"
  source_dir = "./lambdas/lambda-b"
  function_name = "lambda-b"
  environment   = "qa"
  s3_bucket     = aws_s3_bucket.lambda_artifacts["qa"].id
  memory_size   = local.environments.qa.lambda_config.memory_size
  timeout       = local.environments.qa.lambda_config.timeout
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  environment_variables = {
    db_cache = "weqee"
    db_pass = "fasfd"
  }
  tags          = merge(local.environments.dev.tags, {
    Autor       = "John Doe"  
  })
  role_arn = aws_iam_role.lambda_shared_role.arn
  source_code_hash = "dummy-hash"
  depends_on = [aws_s3_bucket.lambda_artifacts]
}

module "lambda_b_prod" {
  source        = "./modules/lambda"
  source_dir = "./lambdas/lambda-b"
  function_name = "lambda-b"
  environment   = "prod"
  s3_bucket     = aws_s3_bucket.lambda_artifacts["prod"].id
  memory_size   = local.environments.prod.lambda_config.memory_size
  timeout       = local.environments.prod.lambda_config.timeout
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  environment_variables = {
    db_cache = "weqee"
    db_pass = "fasfd"
  }
  tags          = merge(local.environments.prod.tags, {
    Autor       = "John Doe"  
  })
  role_arn = aws_iam_role.lambda_shared_role.arn
  source_code_hash = "dummy-hash"
  depends_on = [aws_s3_bucket.lambda_artifacts]
}

module "lambda_c_dev" {
  source        = "./modules/lambda"
  source_dir = "./lambdas/lambda-c"
  function_name = "lambda-c"
  environment   = "dev"
  s3_bucket     = aws_s3_bucket.lambda_artifacts["dev"].id
  memory_size   = local.environments.dev.lambda_config.memory_size
  timeout       = local.environments.dev.lambda_config.timeout
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  environment_variables = {
    db_mvshub = "1233213"
    db_pass = "dsadw232"
  }
  tags          = merge(local.environments.dev.tags, {
    Autor       = "Juan Perez"  
  })
  role_arn = aws_iam_role.lambda_shared_role.arn
  layers = ["arn:aws:lambda:us-east-1:017000801446:layer:AWSLambdaPowertoolsPythonV2:78"]
  source_code_hash = "dummy-hash"
  depends_on = [aws_s3_bucket.lambda_artifacts]
}

module "lambda_c_qa" {
  source        = "./modules/lambda"
  source_dir = "./lambdas/lambda-c"
  function_name = "lambda-c"
  environment   = "qa"
  s3_bucket     = aws_s3_bucket.lambda_artifacts["qa"].id
  memory_size   = local.environments.qa.lambda_config.memory_size
  timeout       = local.environments.qa.lambda_config.timeout
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  environment_variables = {
    db_mvshub = "1233213"
    db_pass = "dsadw232"
  }
  tags          = merge(local.environments.qa.tags, {
    Autor       = "Juan Perez"  
  })
  role_arn = aws_iam_role.lambda_shared_role.arn
  layers = ["arn:aws:lambda:us-east-1:017000801446:layer:AWSLambdaPowertoolsPythonV2:78"]
  source_code_hash = "dummy-hash"
  depends_on = [aws_s3_bucket.lambda_artifacts]
}

module "lambda_c_prod" {
  source        = "./modules/lambda"
  source_dir = "./lambdas/lambda-c"
  function_name = "lambda-c"
  environment   = "prod"
  s3_bucket     = aws_s3_bucket.lambda_artifacts["prod"].id
  memory_size   = local.environments.prod.lambda_config.memory_size
  timeout       = local.environments.prod.lambda_config.timeout
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  environment_variables = {
    db_mvshub = "1233213"
    db_pass = "dsadw232"
  }
  tags          = merge(local.environments.prod.tags, {
    Autor       = "Juan Perez"  
  })
  role_arn = aws_iam_role.lambda_shared_role.arn
  layers = ["arn:aws:lambda:us-east-1:017000801446:layer:AWSLambdaPowertoolsPythonV2:78"]
  source_code_hash = "dummy-hash"
  depends_on = [aws_s3_bucket.lambda_artifacts]
}

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

  tags = {
    Name        = "Lambda Deployments Tracking"
    Environment = "all"
    ManagedBy   = "Terraform"
  }
}

resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "lambda-feature-api"
  protocol_type = "HTTP"
  description   = "API Gateway for feature testing"
}

resource "aws_apigatewayv2_stage" "base_stages" {
  for_each = {
    dev  = "Development Stage"
    qa   = "QA Stage"
    prod = "Production Stage"
  }

  api_id      = aws_apigatewayv2_api.lambda_api.id
  name        = each.key
  auto_deploy = true

  tags = merge(local.environments[each.key].tags, {
    Name = "Base ${each.key} stage"
  })
}