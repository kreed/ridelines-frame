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
  default     = "../../../artifacts/lambda/lambda-package.zip"
}

variable "deploy_lambda" {
  description = "Whether to deploy the Lambda function (set false until code is ready)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}