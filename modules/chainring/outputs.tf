output "lambda_function_arn" {
  description = "ARN of the chainring Lambda function"
  value       = aws_lambda_function.chainring_lambda.arn
}

output "lambda_function_name" {
  description = "Name of the chainring Lambda function"
  value       = aws_lambda_function.chainring_lambda.function_name
}

output "lambda_function_url" {
  description = "URL of the chainring Lambda function"
  value       = aws_lambda_function_url.chainring.function_url
}

output "lambda_role_arn" {
  description = "ARN of the IAM role for the chainring Lambda"
  value       = aws_iam_role.chainring_lambda_role.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.chainring_lambda_logs.name
}

output "users_table_name" {
  description = "Name of the DynamoDB users table"
  value       = aws_dynamodb_table.users.name
}

output "users_table_arn" {
  description = "ARN of the DynamoDB users table"
  value       = aws_dynamodb_table.users.arn
}

