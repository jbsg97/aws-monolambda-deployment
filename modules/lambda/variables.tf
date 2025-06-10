variable "function_name" {
  type = string
}

variable "s3_bucket" {
  description = "S3 bucket for Lambda artifacts"
  type        = string
}

variable "s3_key" {
  description = "S3 key for Lambda function code"
  type        = string
  default     = null
}

variable "handler" {
  type = string
}

variable "runtime" {
  type    = string
  default = "python3.9"
}

variable "source_code_hash" {
  type        = string
  description = "Used to trigger updates when code changes"
  default     = "dummy-hash"
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "layers" {
  type    = list(string)
  default = []
}

variable "environment" {
  description = "Deployment environment (dev/qa/prod)"
  type        = string
}

variable "memory_size" {
  description = "Lambda function memory size"
  type        = number
  default     = 128
}

variable "timeout" {
  description = "Lambda function timeout"
  type        = number
  default     = 30
}

variable "developer_last_updated" {
  description = "Developer who last updated this Lambda"
  type        = string
  default     = "unknown"
}

variable "feature_name" {
  description = "Name of feature branch (if any)"
  type        = string
  default     = ""
}

variable "team_name" {
  description = "Name of team working on feature"
  type        = string
  default     = ""
}

variable "role_arn" {
  description = "ARN of the Lambda execution role"
  type        = string
}

variable "source_dir" {
  description = "Local path to Lambda function source code"
  type        = string
}