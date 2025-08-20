output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.ridelines_drivetrain.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.ridelines_drivetrain.arn
}

output "lambda_function_url" {
  description = "Lambda function URL (if enabled)"
  value       = var.enable_function_url ? aws_lambda_function_url.ridelines_drivetrain_url[0].function_url : null
}

output "secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret for Intervals API key"
  value       = aws_secretsmanager_secret.intervals_api_key.arn
}