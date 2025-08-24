output "lambda_function_name" {
  description = "Name of the auth Lambda function"
  value       = var.deploy_lambda ? aws_lambda_function.auth_lambda[0].function_name : null
}

output "lambda_function_arn" {
  description = "ARN of the auth Lambda function"
  value       = var.deploy_lambda ? aws_lambda_function.auth_lambda[0].arn : null
}

output "oauth_state_table_name" {
  description = "Name of the OAuth state DynamoDB table"
  value       = aws_dynamodb_table.oauth_state.name
}

output "oauth_state_table_arn" {
  description = "ARN of the OAuth state DynamoDB table"
  value       = aws_dynamodb_table.oauth_state.arn
}

output "jwt_signing_key_arn" {
  description = "ARN of the KMS key for JWT signing"
  value       = aws_kms_key.jwt_signing_key.arn
}

output "jwt_signing_key_alias" {
  description = "Alias of the KMS key for JWT signing"
  value       = aws_kms_alias.jwt_signing_key_alias.name
}

output "oauth_credentials_secret_arn" {
  description = "ARN of the OAuth credentials secret"
  value       = aws_secretsmanager_secret.oauth_credentials.arn
}