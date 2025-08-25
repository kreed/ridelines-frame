variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "lambda_package_path" {
  description = "Path to the Lambda deployment package for users function"
  type        = string
  default     = "../../../artifacts/drivetrain/user-lambda.zip"
}

variable "frontend_url" {
  description = "Frontend URL for PMTiles URL generation"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}