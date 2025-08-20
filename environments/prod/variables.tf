# Variables for production environment

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ridelines"
}

variable "aws_region" {
  description = "AWS region for production environment"
  type        = string
  default     = "us-west-2"
}

variable "domain_name" {
  description = "Domain name for production environment"
  type        = string
  default     = "ridelines.xyz"
}

variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_All"
}

variable "enable_cloudfront_logging" {
  description = "Enable CloudFront logging"
  type        = bool
  default     = true
}

variable "lambda_package_path" {
  description = "Path to the Lambda deployment package"
  type        = string
  default     = "../../packages/lambda/bootstrap.zip"
}

variable "tippecanoe_layer_arn" {
  description = "ARN of the tippecanoe Lambda layer"
  type        = string
  default     = ""
}

variable "enable_lambda_function_url" {
  description = "Enable Lambda function URL"
  type        = bool
  default     = false
}

# Package versions (set by deployment automation)
variable "hub_version" {
  description = "Version of the hub package to deploy"
  type        = string
  default     = "sha-placeholder"
}

variable "lambda_version" {
  description = "Version of the lambda package to deploy"
  type        = string
  default     = "sha-placeholder"
}

variable "layer_version" {
  description = "Version of the layer package to deploy"
  type        = string
  default     = "sha-placeholder"
}