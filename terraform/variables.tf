# Lambda Configuration Variables
variable "lambda_functions" {
  description = "Map of Lambda functions with their configurations"
  type = map(object({
    source_dir = string
    handler    = string
    runtime    = string
    layers     = list(string)
    authors    = map(string)
  }))
  default = {
    "lambda-a" = {
      source_dir = "../lambdas/lambda-a"
      handler    = "lambda_function.lambda_handler"
      runtime    = "python3.12"
      layers     = ["arn:aws:lambda:us-east-1:017000801446:layer:AWSLambdaPowertoolsPythonV2:78"]
      authors    = {
        dev  = "Will Smith"
        qa   = "Will Smith"
        prod = "Will Smith"
      }
    }
    "lambda-b" = {
      source_dir = "../lambdas/lambda-b"
      handler    = "lambda_function.lambda_handler"
      runtime    = "python3.12"
      layers     = []
      authors    = {
        dev  = "John Doe"
        qa   = "John Doe"
        prod = "John Doe"
      }
    }
    "lambda-c" = {
      source_dir = "../lambdas/lambda-c"
      handler    = "lambda_function.lambda_handler"
      runtime    = "python3.12"
      layers     = ["arn:aws:lambda:us-east-1:017000801446:layer:AWSLambdaPowertoolsPythonV2:78"]
      authors    = {
        dev  = "Juan Perez"
        qa   = "Juan Perez"
        prod = "Juan Perez"
      }
    }
    "lambda-d" = {
      source_dir = "../lambdas/payments/lambda-d"
      handler    = "lambda_function.lambda_handler"
      runtime    = "python3.12"
      layers     = ["arn:aws:lambda:us-east-1:017000801446:layer:AWSLambdaPowertoolsPythonV2:78"]
      authors    = {
        dev  = "Juan Perez"
        qa   = "Juan Perez"
        prod = "Juan Perez"
      }
    }
    "lambda-e" = {
      source_dir = "../lambdas/payments/lambda-e"
      handler    = "lambda_function.lambda_handler"
      runtime    = "python3.12"
      layers     = ["arn:aws:lambda:us-east-1:017000801446:layer:AWSLambdaPowertoolsPythonV2:78"]
      authors    = {
        dev  = "Miguel Perez"
        qa   = "Miguel Perez"
        prod = "Miguel Perez"
      }
    }
  }
}

variable "s3_buckets" {
  description = "Map of S3 bucket names for Lambda artifacts by environment"
  type        = map(string)
  default = {
    dev  = "mvshub-lambda-artifacts-dev"
    qa   = "mvshub-lambda-artifacts-qa"
    prod = "mvshub-lambda-artifacts-prod"
    dummy_lambda = "dummy-code-for-aws-lambda"
  }
}

# Project-wide Tags
variable "project_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "MVSHUB"
    ManagedBy   = "Terraform"
  }
}
