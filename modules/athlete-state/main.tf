# S3 bucket for storing athlete GeoJSON data
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