output "lambda_function_name" {
  description = "Name of the users Lambda function"
  value       = aws_lambda_function.users_lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the users Lambda function"
  value       = aws_lambda_function.users_lambda.arn
}

output "users_table_name" {
  description = "Name of the users DynamoDB table"
  value       = aws_dynamodb_table.users.name
}

output "users_table_arn" {
  description = "ARN of the users DynamoDB table"
  value       = aws_dynamodb_table.users.arn
}