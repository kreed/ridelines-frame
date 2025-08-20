# CloudWatch log group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}"
  retention_in_days = 14
  tags              = var.tags
}

# AWS Secrets Manager secret for Intervals API key
resource "aws_secretsmanager_secret" "intervals_api_key" {
  name        = "${var.project_name}-${var.environment}-intervals-api-key"
  description = "API key for intervals.icu"
  tags        = var.tags
}

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-${var.environment}-lambda-role"

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
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy for S3 access (athlete state bucket)
resource "aws_iam_role_policy" "lambda_s3_athlete_state" {
  name = "${var.project_name}-${var.environment}-s3-athlete-state"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.athlete_state_bucket_arn,
          "${var.athlete_state_bucket_arn}/*"
        ]
      }
    ]
  })
}

# IAM policy for S3 access (activities bucket)
resource "aws_iam_role_policy" "lambda_s3_activities" {
  name = "${var.project_name}-${var.environment}-s3-activities"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "${var.activities_bucket_arn}/*"
        ]
      }
    ]
  })
}

# IAM policy for Secrets Manager access
resource "aws_iam_role_policy" "lambda_secrets" {
  name = "${var.project_name}-${var.environment}-secrets"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.intervals_api_key.arn
        ]
      }
    ]
  })
}

# IAM policy for CloudFront invalidation
resource "aws_iam_role_policy" "lambda_cloudfront" {
  name = "${var.project_name}-${var.environment}-cloudfront"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetDistribution"
        ]
        Resource = [
          var.cloudfront_distribution_arn
        ]
      }
    ]
  })
}

# Lambda function
resource "aws_lambda_function" "ridelines_drivetrain" {
  filename         = var.lambda_package_path
  function_name    = "${var.project_name}-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  timeout          = 600
  memory_size      = 2048
  source_code_hash = filebase64sha256(var.lambda_package_path)

  layers = var.tippecanoe_layer_arn != "" ? [var.tippecanoe_layer_arn] : []

  environment {
    variables = {
      SECRETS_MANAGER_SECRET_ARN = aws_secretsmanager_secret.intervals_api_key.arn
      S3_BUCKET                  = var.athlete_state_bucket_name
      ACTIVITIES_S3_BUCKET       = var.activities_bucket_name
      CLOUDFRONT_DISTRIBUTION_ID = var.cloudfront_distribution_id
      RUST_LOG                   = "info"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_cloudwatch_log_group.lambda_logs,
  ]

  tags = var.tags
}

# Lambda function URL (optional)
resource "aws_lambda_function_url" "ridelines_drivetrain_url" {
  count              = var.enable_function_url ? 1 : 0
  function_name      = aws_lambda_function.ridelines_drivetrain.function_name
  authorization_type = "NONE"
}