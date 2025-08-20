output "bucket_name" {
  description = "Name of the S3 bucket for GeoJSON storage"
  value       = aws_s3_bucket.geojson_storage.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket for GeoJSON storage"
  value       = aws_s3_bucket.geojson_storage.arn
}