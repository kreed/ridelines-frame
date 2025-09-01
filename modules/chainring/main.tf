# DynamoDB Users Table
resource "aws_dynamodb_table" "users" {
  name         = "${var.project_name}-${var.environment}-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = var.tags
}

# CloudWatch log group for chainring Lambda function
resource "aws_cloudwatch_log_group" "chainring_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-chainring"
  retention_in_days = 14
  tags              = var.tags
}

# IAM role for chainring Lambda execution
resource "aws_iam_role" "chainring_lambda_role" {
  name = "${var.project_name}-${var.environment}-chainring-lambda-role"

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
resource "aws_iam_role_policy_attachment" "chainring_lambda_basic_execution" {
  role       = aws_iam_role.chainring_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy for DynamoDB access to users table
resource "aws_iam_role_policy" "chainring_lambda_dynamodb" {
  name = "${var.project_name}-${var.environment}-chainring-dynamodb"
  role = aws_iam_role.chainring_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          aws_dynamodb_table.users.arn
        ]
      }
    ]
  })
}

# Lambda function URL for chainring (with IAM auth for CloudFront only)
resource "aws_lambda_function_url" "chainring" {
  function_name      = aws_lambda_function.chainring_lambda.function_name
  authorization_type = "AWS_IAM"

  cors {
    allow_credentials = true
    allow_origins     = var.allowed_origins
    allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers     = ["content-type", "authorization", "x-amz-date", "x-amz-security-token"]
    expose_headers    = ["*"]
    max_age           = 86400
  }
}

# Chainring Lambda function
resource "aws_lambda_function" "chainring_lambda" {
  filename         = var.lambda_package_path
  function_name    = "${var.project_name}-${var.environment}-chainring"
  role             = aws_iam_role.chainring_lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  timeout          = 30
  memory_size      = 1024
  source_code_hash = filebase64sha256(var.lambda_package_path)

  environment {
    variables = {
      NODE_ENV              = var.environment
      USERS_TABLE_NAME      = aws_dynamodb_table.users.name
      CLERK_SECRET_KEY      = var.clerk_secret_key
      CLERK_PUBLISHABLE_KEY = var.clerk_publishable_key
      CLERK_JWT_KEY         = var.clerk_jwt_key
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.chainring_lambda_basic_execution,
    aws_cloudwatch_log_group.chainring_lambda_logs,
  ]

  tags = var.tags
}

# Lambda permission for CloudFront to invoke via Function URL
resource "aws_lambda_permission" "chainring_cloudfront" {
  statement_id           = "AllowCloudFrontInvoke"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.chainring_lambda.function_name
  principal              = "cloudfront.amazonaws.com"
  source_arn             = var.cloudfront_distribution_arn
  function_url_auth_type = "AWS_IAM"
}