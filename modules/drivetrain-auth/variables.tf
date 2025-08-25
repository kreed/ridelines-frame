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

variable "users_table_name" {
  description = "Name of the DynamoDB users table"
  type        = string
}

variable "users_table_arn" {
  description = "ARN of the DynamoDB users table"
  type        = string
}


variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}