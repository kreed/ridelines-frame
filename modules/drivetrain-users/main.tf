# CloudWatch log group for users Lambda function
resource "aws_cloudwatch_log_group" "users_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-users"
  retention_in_days = 14
  tags              = var.tags
}

# DynamoDB table for user management
resource "aws_dynamodb_table" "users" {
  name         = "${var.project_name}-${var.environment}-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  # Global Secondary Index for intervals.icu athlete ID lookups
  global_secondary_index {
    name     = "intervals-athlete-index"
    hash_key = "intervals_athlete_id"

    projection_type = "ALL"
  }

  attribute {
    name = "intervals_athlete_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(var.tags, {
    Description = "User profile and sync status storage"
  })
}

# IAM role for users Lambda execution
resource "aws_iam_role" "users_lambda_role" {
  name = "${var.project_name}-${var.environment}-users-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "users_lambda_basic_execution" {
  role       = aws_iam_role.users_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy for DynamoDB access (users table)
resource "aws_iam_role_policy" "users_lambda_dynamodb" {
  name = "${var.project_name}-${var.environment}-users-dynamodb"
  role = aws_iam_role.users_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.users.arn,
          "${aws_dynamodb_table.users.arn}/index/*"
        ]
      }
    ]
  })
}

# Users Lambda function
resource "aws_lambda_function" "users_lambda" {
  filename         = var.lambda_package_path
  function_name    = "${var.project_name}-${var.environment}-users"
  role             = aws_iam_role.users_lambda_role.arn
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  timeout          = 30
  memory_size      = 512
  source_code_hash = filebase64sha256(var.lambda_package_path)

  environment {
    variables = {
      USERS_TABLE_NAME = aws_dynamodb_table.users.name
      RUST_LOG         = "info"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.users_lambda_basic_execution,
    aws_cloudwatch_log_group.users_lambda_logs,
  ]

  tags = var.tags
}

