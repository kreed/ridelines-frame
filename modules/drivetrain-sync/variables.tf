variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "lambda_package_path" {
  description = "Path to the Lambda deployment package"
  type        = string
  default     = "../../../artifacts/drivetrain/lambda.zip"
}

variable "tippecanoe_layer_package_path" {
  description = "Path to the tippecanoe Lambda layer package"
  type        = string
  default     = "../../../artifacts/drivetrain/layer.zip"
}

variable "activities_bucket_name" {
  description = "Name of the S3 bucket for activities data"
  type        = string
}

variable "activities_bucket_arn" {
  description = "ARN of the S3 bucket for activities data"
  type        = string
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  type        = string
}

variable "enable_function_url" {
  description = "Enable Lambda function URL"
  type        = bool
  default     = false
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