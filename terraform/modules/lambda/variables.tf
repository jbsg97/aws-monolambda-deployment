# Core Lambda Function Configuration
variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "s3_bucket" {
  description = "S3 bucket for Lambda artifacts"
  type        = string
}

variable "s3_key" {
  description = "S3 key for Lambda function code (optional, managed externally if not set)"
  type        = string
  default     = null
}

variable "handler" {
  description = "Entry point for the Lambda function (e.g., file.function)"
  type        = string
}

variable "runtime" {
  description = "Runtime environment for the Lambda function"
  type        = string
  default     = "python3.9"
}

variable "source_code_hash" {
  description = "Hash of the source code, used to trigger updates when code changes (managed externally)"
  type        = string
  default     = "dummy-hash"
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to the Lambda function"
  type        = map(string)
  default     = {}
}

variable "layers" {
  description = "List of Lambda layer ARNs to attach to the function"
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Deployment environment (dev/qa/prod)"
  type        = string
}

variable "memory_size" {
  description = "Lambda function memory size in MB (must be between 128 and 10240)"
  type        = number
  default     = 128
  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "Memory size must be between 128 and 10240 MB."
  }
}

variable "timeout" {
  description = "Lambda function timeout in seconds (must be between 1 and 900)"
  type        = number
  default     = 30
  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "Timeout must be between 1 and 900 seconds."
  }
}

variable "role_arn" {
  description = "ARN of the Lambda execution role"
  type        = string
}

variable "source_dir" {
  description = "Local path to Lambda function source code (for reference, not used in deployment)"
  type        = string
}

# Feature Testing Configuration
variable "feature_name" {
  description = "Name of feature branch for alias creation (if any)"
  type        = string
  default     = ""
}

# Advanced Lambda Configurations
variable "vpc_subnet_ids" {
  description = "List of subnet IDs for VPC configuration (optional)"
  type        = list(string)
  default     = null
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs for VPC configuration (optional)"
  type        = list(string)
  default     = null
}

variable "dead_letter_queue_arn" {
  description = "ARN of the Dead Letter Queue for error handling (optional)"
  type        = string
  default     = null
}

variable "tracing_enabled" {
  description = "Enable AWS X-Ray tracing for the Lambda function"
  type        = bool
  default     = false
}

variable "provisioned_concurrency" {
  description = "Number of provisioned concurrency instances (0 to disable)"
  type        = number
  default     = 0
  validation {
    condition     = var.provisioned_concurrency >= 0
    error_message = "Provisioned concurrency must be 0 or greater."
  }
}
