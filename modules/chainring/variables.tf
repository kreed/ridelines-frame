variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
}

variable "lambda_package_path" {
  description = "Path to the chainring Lambda function zip package"
  type        = string
  default     = "../../../artifacts/chainring/chainring.zip"
}

variable "clerk_secret_key" {
  description = "Clerk secret key for backend authentication"
  type        = string
  sensitive   = true
}

variable "clerk_publishable_key" {
  description = "Clerk publishable key"
  type        = string
}

variable "clerk_jwt_key" {
  description = "Clerk JWT public key for verification"
  type        = string
}

variable "allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["https://ridelines.xyz"]
}

variable "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution that will invoke this function"
  type        = string
}

variable "cloudfront_key_pair_id" {
  description = "CloudFront key pair ID for signed URLs"
  type        = string
  sensitive   = true
}

variable "cloudfront_private_key" {
  description = "CloudFront private key (PEM) for signed URLs"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "log_level" {
  description = "Log level for Lambda function (DEBUG, INFO, WARN, ERROR)"
  type        = string
  default     = ""
}
