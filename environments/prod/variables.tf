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

variable "enable_lambda_function_url" {
  description = "Enable Lambda function URL"
  type        = bool
  default     = false
}

