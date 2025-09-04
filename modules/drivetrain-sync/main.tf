# SQS Queue for sync requests
resource "aws_sqs_queue" "sync_requests" {
  name                       = "ridelines-sync-requests"
  visibility_timeout_seconds = 900    # 15 minutes (Lambda timeout is 600s/10min)
  message_retention_seconds  = 259200 # 3 days
  receive_wait_time_seconds  = 0      # Short polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.sync_requests_dlq.arn
    maxReceiveCount     = 3
  })

  tags = var.tags
}

# Dead Letter Queue for failed sync requests
resource "aws_sqs_queue" "sync_requests_dlq" {
  name                      = "ridelines-sync-requests-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = var.tags
}

# S3 bucket for storing athlete GeoJSON data (sync module owns this)
resource "aws_s3_bucket" "geojson_storage" {
  bucket = "${var.project_name}-${var.environment}-geojson-${random_id.bucket_suffix.hex}"
  tags   = var.tags
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "geojson_storage" {
  bucket = aws_s3_bucket.geojson_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "geojson_storage" {
  bucket = aws_s3_bucket.geojson_storage.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "geojson_storage" {
  bucket                  = aws_s3_bucket.geojson_storage.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "geojson_storage" {
  bucket = aws_s3_bucket.geojson_storage.id
  rule {
    id     = "manage_geojson"
    status = "Enabled"
    filter {
      prefix = ""
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# CloudWatch log group for sync Lambda function
resource "aws_cloudwatch_log_group" "sync_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-sync"
  retention_in_days = 14
  tags              = var.tags
}

# IAM role for sync Lambda execution
resource "aws_iam_role" "sync_lambda_role" {
  name = "${var.project_name}-${var.environment}-sync-lambda-role"

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
resource "aws_iam_role_policy_attachment" "sync_lambda_basic_execution" {
  role       = aws_iam_role.sync_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy for SQS access
resource "aws_iam_role_policy" "sync_lambda_sqs" {
  name = "${var.project_name}-${var.environment}-sync-sqs"
  role = aws_iam_role.sync_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [
          aws_sqs_queue.sync_requests.arn
        ]
      }
    ]
  })
}

# IAM policy for S3 access (geojson storage bucket - owned by sync module)
resource "aws_iam_role_policy" "sync_lambda_s3_geojson" {
  name = "${var.project_name}-${var.environment}-sync-s3-geojson"
  role = aws_iam_role.sync_lambda_role.id

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
          aws_s3_bucket.geojson_storage.arn,
          "${aws_s3_bucket.geojson_storage.arn}/*"
        ]
      }
    ]
  })
}

# IAM policy for S3 access (activities bucket) - sync owns this bucket
resource "aws_iam_role_policy" "sync_lambda_s3_activities" {
  name = "${var.project_name}-${var.environment}-sync-s3-activities"
  role = aws_iam_role.sync_lambda_role.id

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

# IAM policy for cross-module access to users table (read user access tokens)
resource "aws_iam_role_policy" "sync_lambda_users_table" {
  name = "${var.project_name}-${var.environment}-sync-users-table"
  role = aws_iam_role.sync_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          var.users_table_arn
        ]
      }
    ]
  })
}

# Tippecanoe Lambda layer
resource "aws_lambda_layer_version" "tippecanoe" {
  filename            = var.tippecanoe_layer_package_path
  layer_name          = "${var.project_name}-${var.environment}-tippecanoe"
  compatible_runtimes = ["provided.al2023"]
  source_code_hash    = filebase64sha256(var.tippecanoe_layer_package_path)
}

# Sync Lambda function
resource "aws_lambda_function" "sync_lambda" {
  filename         = var.lambda_package_path
  function_name    = "${var.project_name}-${var.environment}-sync"
  role             = aws_iam_role.sync_lambda_role.arn
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  timeout          = 600
  memory_size      = 2048
  source_code_hash = filebase64sha256(var.lambda_package_path)

  layers = [aws_lambda_layer_version.tippecanoe.arn]

  environment {
    variables = {
      S3_BUCKET            = aws_s3_bucket.geojson_storage.bucket
      ACTIVITIES_S3_BUCKET = var.activities_bucket_name
      USERS_TABLE_NAME     = var.users_table_name
      CLERK_SECRET_KEY     = var.clerk_secret_key
      RUST_LOG             = "info"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.sync_lambda_basic_execution,
    aws_cloudwatch_log_group.sync_lambda_logs,
  ]

  tags = var.tags
}

# SQS Lambda trigger
resource "aws_lambda_event_source_mapping" "sync_sqs" {
  event_source_arn = aws_sqs_queue.sync_requests.arn
  function_name    = aws_lambda_function.sync_lambda.arn
  batch_size       = 1 # Process one sync request at a time
}

