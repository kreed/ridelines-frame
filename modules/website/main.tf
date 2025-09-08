# AWS provider for us-east-1 (required for CloudFront certificates)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = var.tags
  }
}

# Locals for resource naming
locals {
  website_bucket_name    = "${var.project_name}-${var.environment}-static-assets"
  activities_bucket_name = "${var.project_name}-${var.environment}-activities"

  # Extract domain from Lambda function URL
  chainring_origin_domain = regex("^https?://([^/]+)", var.chainring_lambda_url)[0]
}

# ACM Certificate for CloudFront (must be in us-east-1)
resource "aws_acm_certificate" "main" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

# Certificate validation
resource "aws_acm_certificate_validation" "main" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

# Route53 records for certificate validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.hosted_zone_id
}

# S3 bucket for website assets
resource "aws_s3_bucket" "website" {
  bucket = local.website_bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "static_assets" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_lifecycle_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  rule {
    id     = "cleanup_incomplete_uploads"
    status = "Enabled"
    filter {
      prefix = ""
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# S3 bucket for activities data
resource "aws_s3_bucket" "activities" {
  bucket = local.activities_bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "activities" {
  bucket = aws_s3_bucket.activities.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "activities" {
  bucket = aws_s3_bucket.activities.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "activities" {
  bucket                  = aws_s3_bucket.activities.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "activities" {
  bucket = aws_s3_bucket.activities.id
  rule {
    id     = "manage_pmtiles"
    status = "Enabled"
    filter {
      prefix = "activities/"
    }
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# S3 bucket for CloudFront logs (conditional)
resource "aws_s3_bucket" "logs" {
  count  = var.enable_logging ? 1 : 0
  bucket = "${var.domain_name}-logs"
  tags   = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count  = var.enable_logging ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_acl" "logs" {
  count  = var.enable_logging ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id
  acl    = "log-delivery-write"

  depends_on = [aws_s3_bucket_ownership_controls.logs]
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  count  = var.enable_logging ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count                   = var.enable_logging ? 1 : 0
  bucket                  = aws_s3_bucket.logs[0].id
  block_public_acls       = false
  block_public_policy     = true
  ignore_public_acls      = false
  restrict_public_buckets = true
}

# Data source for current AWS region
data "aws_region" "current" {}

# Data sources for CloudFront managed policies
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_response_headers_policy" "cors_and_security_headers" {
  name = "Managed-CORS-with-preflight-and-SecurityHeadersPolicy"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host_header" {
  name = "Managed-AllViewerExceptHostHeader"
}


# Generate RSA private key for CloudFront signing
resource "tls_private_key" "cloudfront_signing" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# CloudFront public key for signed URLs
resource "aws_cloudfront_public_key" "activities" {
  name        = "${var.project_name}-${var.environment}-activities-key"
  comment     = "Public key for activities signed URLs"
  encoded_key = tls_private_key.cloudfront_signing.public_key_pem
}

# CloudFront key group for signed URLs
resource "aws_cloudfront_key_group" "activities" {
  name    = "${var.project_name}-${var.environment}-activities-key-group"
  comment = "Key group for activities signed URLs"
  items   = [aws_cloudfront_public_key.activities.id]
}

# CloudFront Function for URL rewriting
resource "aws_cloudfront_function" "url_rewrite" {
  name    = "${var.project_name}-${var.environment}-url-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "Rewrite URLs to add .html extension"
  publish = true
  code    = <<-EOT
    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      
      // Handle root path
      if (uri === '/') {
        request.uri = '/index.html';
        return request;
      }
      
      // Remove trailing slashes
      uri = uri.replace(/\/+$/, '');
      
      // Get the last segment of the path
      var segments = uri.split('/');
      var lastSegment = segments[segments.length - 1];
      
      // Check if the last segment has a file extension (contains dot after last slash)
      if (!lastSegment.includes('.')) {
        // Add .html extension
        request.uri = uri + '.html';
      }
      
      return request;
    }
  EOT
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${var.domain_name}-website-oac"
  description                       = "OAC for ${var.domain_name} website"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "activities" {
  name                              = "${var.domain_name}-activities-oac"
  description                       = "OAC for ${var.domain_name} activities"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Function for auth validation and path rewriting
resource "aws_cloudfront_function" "auth_rewrite" {
  name    = "${var.project_name}-${var.environment}-auth-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "Validates auth header and rewrites /trpc paths"
  publish = true
  code    = file("${path.module}/cloudfront-auth-function.js")
}

# Origin Access Control for Chainring Lambda
resource "aws_cloudfront_origin_access_control" "chainring" {
  name                              = "${var.project_name}-${var.environment}-chainring-oac"
  description                       = "OAC for Chainring Lambda Function URL"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  # Website origin
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
    origin_id                = "S3-${aws_s3_bucket.website.bucket}"
  }

  # Activities origin
  origin {
    domain_name              = aws_s3_bucket.activities.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.activities.id
    origin_id                = "S3-${aws_s3_bucket.activities.bucket}"
  }

  # Chainring Lambda origin with IAM auth
  origin {
    domain_name              = local.chainring_origin_domain
    origin_id                = "Lambda-Chainring"
    origin_access_control_id = aws_cloudfront_origin_access_control.chainring.id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }


  enabled         = true
  is_ipv6_enabled = true
  aliases         = [var.domain_name]
  price_class     = var.price_class

  # Default behavior for website (no caching for root)
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.website.bucket}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.cors_and_security_headers.id

    # Function to rewrite URLs to add .html extension
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.url_rewrite.arn
    }
  }

  # Behavior for immutable assets (enable caching)
  ordered_cache_behavior {
    path_pattern           = "/_app/immutable/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.website.bucket}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.cors_and_security_headers.id
  }

  # Behavior for activities data (with presigned URL requirement)
  ordered_cache_behavior {
    path_pattern           = "/activities/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.activities.bucket}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.cors_and_security_headers.id

    # Require signed URLs for access
    trusted_key_groups = [aws_cloudfront_key_group.activities.id]
  }

  # Behavior for tRPC API calls to Chainring Lambda
  ordered_cache_behavior {
    path_pattern           = "/trpc/*"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "Lambda-Chainring"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    # No caching for API calls
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host_header.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.cors_and_security_headers.id

    # Attach CloudFront Function for auth validation and path rewriting
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.auth_rewrite.arn
    }
  }


  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.main.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }


  dynamic "logging_config" {
    for_each = var.enable_logging ? [1] : []
    content {
      include_cookies = false
      bucket          = aws_s3_bucket.logs[0].bucket_domain_name
      prefix          = "cloudfront/"
    }
  }

  tags = var.tags
}

# CloudFront Monitoring Subscription for additional metrics
resource "aws_cloudfront_monitoring_subscription" "main" {
  distribution_id = aws_cloudfront_distribution.main.id

  monitoring_subscription {
    # Enable additional CloudWatch metrics
    # Provides real-time metrics with 1-minute granularity
    # Includes: Cache hit rate, Origin latency, Error rate by status code
    # Cost: ~$0.01 per million requests
    realtime_metrics_subscription_config {
      realtime_metrics_subscription_status = "Enabled"
    }
  }
}

# CloudWatch RUM App Monitor (without Cognito)
resource "aws_rum_app_monitor" "main" {
  name   = "${var.project_name}-${var.environment}"
  domain = var.domain_name

  app_monitor_configuration {
    allow_cookies       = true
    enable_xray         = false
    session_sample_rate = 1.0
    telemetries         = ["errors", "performance", "http"]
  }

  # Custom endpoint configuration
  custom_events {
    status = "ENABLED"
  }

  tags = var.tags
}

# RUM App Monitor Resource Policy for public access
# Note: This needs to be applied via AWS CLI as Terraform doesn't have a native resource for RUM policies yet
# https://github.com/hashicorp/terraform-provider-aws/issues/42257
resource "null_resource" "rum_resource_policy" {
  depends_on = [aws_rum_app_monitor.main]

  provisioner "local-exec" {
    command = <<-EOT
      aws rum put-resource-policy \
        --name ${aws_rum_app_monitor.main.name} \
        --policy-document '{
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Principal": "*",
              "Action": "rum:PutRumEvents",
              "Resource": "${aws_rum_app_monitor.main.arn}"
            }
          ]
        }' \
        --region ${data.aws_region.current.id}
    EOT
  }

  # Trigger replacement if app monitor changes
  triggers = {
    app_monitor_arn = aws_rum_app_monitor.main.arn
  }
}

# Route53 A record for the domain
resource "aws_route53_record" "main" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 AAAA record for IPv6
resource "aws_route53_record" "main_ipv6" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

# S3 bucket policies for CloudFront access
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      },
      {
        Sid    = "AllowCloudFrontListBucket"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.website.arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "activities" {
  bucket = aws_s3_bucket.activities.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipalActivities"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.activities.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })
}