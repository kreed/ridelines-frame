variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
}

variable "domain_name" {
  description = "API domain name (api.ridelines.xyz or dev.api.ridelines.xyz)"
  type        = string
}

# ACM certificate will be created within this module

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS record"
  type        = string
}

variable "auth_lambda_arn" {
  description = "ARN of the auth Lambda function"
  type        = string
}

variable "auth_lambda_function_name" {
  description = "Name of the auth Lambda function"
  type        = string
}

variable "user_lambda_arn" {
  description = "ARN of the user Lambda function"
  type        = string
}

variable "user_lambda_function_name" {
  description = "Name of the user Lambda function"
  type        = string
}

variable "jwt_kms_key_arn" {
  description = "ARN of the KMS key used for JWT signing/verification"
  type        = string
}

variable "frontend_origin" {
  description = "Frontend origin URL for CORS configuration"
  type        = string
}

variable "auth_verify_lambda_arn" {
  description = "ARN of the auth verify Lambda function"
  type        = string
}

variable "auth_verify_lambda_role_arn" {
  description = "ARN of the auth verify Lambda execution role"
  type        = string
}

variable "openapi_spec_path" {
  description = "Path to the OpenAPI specification file"
  type        = string
  default     = "ridelines-api.yaml"
}