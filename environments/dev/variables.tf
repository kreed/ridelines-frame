# Variables for development environment

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ridelines"
}

variable "aws_region" {
  description = "AWS region for development environment"
  type        = string
  default     = "us-west-2"
}

variable "domain_name" {
  description = "Domain name for development environment"
  type        = string
  default     = "dev.ridelines.xyz"
}

variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "enable_cloudfront_logging" {
  description = "Enable CloudFront logging"
  type        = bool
  default     = false
}

variable "github_repository" {
  description = "GitHub repository in the format 'owner/repo'"
  type        = string
  default     = "kreed/ridelines-frame"
}

variable "clerk_secret_key" {
  description = "Clerk secret key for authentication and OAuth token retrieval"
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


