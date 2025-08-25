variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "lambda_package_path" {
  description = "Path to the Lambda deployment package for auth function"
  type        = string
  default     = "../../../artifacts/drivetrain/auth-lambda.zip"
}

variable "auth_verify_lambda_package_path" {
  description = "Path to the Lambda deployment package for auth verify function"
  type        = string
  default     = "../../../artifacts/drivetrain/auth-verify-lambda.zip"
}

variable "users_table_name" {
  description = "Name of the DynamoDB users table"
  type        = string
}

variable "users_table_arn" {
  description = "ARN of the DynamoDB users table"
  type        = string
}

variable "frontend_url" {
  description = "Frontend URL for OAuth redirects"
  type        = string
}

variable "api_domain" {
  description = "API domain name (e.g., api.ridelines.xyz or dev.api.ridelines.xyz)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}