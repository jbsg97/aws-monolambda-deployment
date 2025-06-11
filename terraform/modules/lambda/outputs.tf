# Outputs for Lambda Function Attributes
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.lambda.arn
}

output "lambda_function_version" {
  description = "Version of the Lambda function"
  value       = aws_lambda_function.lambda.version
}

output "lambda_alias_arn" {
  description = "ARN of the Lambda alias (if created for feature testing)"
  value       = length(aws_lambda_alias.feature_alias) > 0 ? aws_lambda_alias.feature_alias[0].arn : null
}
