# Data sources for current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# CloudWatch log group for auth Lambda function
resource "aws_cloudwatch_log_group" "auth_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-auth"
  retention_in_days = 14
  tags              = var.tags
}

# DynamoDB table for OAuth state management (CSRF protection)
resource "aws_dynamodb_table" "oauth_state" {
  name         = "${var.project_name}-${var.environment}-oauth-state"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "state"

  attribute {
    name = "state"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(var.tags, {
    Description = "OAuth state storage for CSRF protection"
  })
}

# KMS key for JWT signing (RSA_2048)
resource "aws_kms_key" "jwt_signing_key" {
  description              = "RSA key for JWT signing in ${var.project_name} ${var.environment}"
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "RSA_2048"

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-policy-jwt-signing"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda functions to use the key for signing"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "kms:Sign",
          "kms:Verify",
          "kms:GetPublicKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "lambda.${data.aws_region.current.id}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Description = "JWT signing key for OAuth authentication"
  })
}

# KMS key alias for easier reference
resource "aws_kms_alias" "jwt_signing_key_alias" {
  name          = "alias/${var.project_name}-${var.environment}-jwt"
  target_key_id = aws_kms_key.jwt_signing_key.key_id
}

# Secrets Manager secret for OAuth credentials
resource "aws_secretsmanager_secret" "oauth_credentials" {
  name        = "${var.project_name}-${var.environment}-oauth-credentials"
  description = "OAuth client credentials for intervals.icu integration"

  tags = merge(var.tags, {
    Description = "OAuth client ID and secret for intervals.icu"
  })
}

# Initial secret version with empty structure (to be populated manually)
resource "aws_secretsmanager_secret_version" "oauth_credentials" {
  secret_id = aws_secretsmanager_secret.oauth_credentials.id
  secret_string = jsonencode({
    client_id     = ""
    client_secret = ""
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# IAM role for auth Lambda execution
resource "aws_iam_role" "auth_lambda_role" {
  name = "${var.project_name}-${var.environment}-auth-lambda-role"

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
resource "aws_iam_role_policy_attachment" "auth_lambda_basic_execution" {
  role       = aws_iam_role.auth_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy for DynamoDB access (OAuth state table)
resource "aws_iam_role_policy" "auth_lambda_dynamodb" {
  name = "${var.project_name}-${var.environment}-auth-dynamodb"
  role = aws_iam_role.auth_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          aws_dynamodb_table.oauth_state.arn
        ]
      }
    ]
  })
}

# IAM policy for KMS access (JWT signing)
resource "aws_iam_role_policy" "auth_lambda_kms" {
  name = "${var.project_name}-${var.environment}-auth-kms"
  role = aws_iam_role.auth_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Sign",
          "kms:Verify",
          "kms:GetPublicKey",
          "kms:DescribeKey"
        ]
        Resource = [
          aws_kms_key.jwt_signing_key.arn
        ]
      }
    ]
  })
}

# IAM policy for Secrets Manager access (OAuth credentials)
resource "aws_iam_role_policy" "auth_lambda_secrets" {
  name = "${var.project_name}-${var.environment}-auth-secrets"
  role = aws_iam_role.auth_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.oauth_credentials.arn
        ]
      }
    ]
  })
}

# IAM policy for cross-module access to users table
resource "aws_iam_role_policy" "auth_lambda_users_table" {
  name = "${var.project_name}-${var.environment}-auth-users-table"
  role = aws_iam_role.auth_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          var.users_table_arn
        ]
      }
    ]
  })
}

# Auth Lambda function
resource "aws_lambda_function" "auth_lambda" {
  filename         = var.lambda_package_path
  function_name    = "${var.project_name}-${var.environment}-auth"
  role             = aws_iam_role.auth_lambda_role.arn
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  timeout          = 30
  memory_size      = 512
  source_code_hash = filebase64sha256(var.lambda_package_path)

  environment {
    variables = {
      OAUTH_STATE_TABLE_NAME      = aws_dynamodb_table.oauth_state.name
      JWT_SIGNING_KEY_ARN         = aws_kms_key.jwt_signing_key.arn
      OAUTH_CREDENTIALS_SECRET_ARN = aws_secretsmanager_secret.oauth_credentials.arn
      USERS_TABLE_NAME            = var.users_table_name
      RUST_LOG                    = "info"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.auth_lambda_basic_execution,
    aws_cloudwatch_log_group.auth_lambda_logs,
  ]

  tags = var.tags
}

