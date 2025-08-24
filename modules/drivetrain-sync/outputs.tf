output "lambda_function_name" {
  description = "Name of the sync Lambda function"
  value       = aws_lambda_function.sync_lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the sync Lambda function"
  value       = aws_lambda_function.sync_lambda.arn
}

output "tippecanoe_layer_arn" {
  description = "ARN of the Tippecanoe Lambda layer"
  value       = aws_lambda_layer_version.tippecanoe.arn
}

output "geojson_bucket_name" {
  description = "Name of the S3 bucket for GeoJSON storage"
  value       = aws_s3_bucket.geojson_storage.bucket
}

output "geojson_bucket_arn" {
  description = "ARN of the S3 bucket for GeoJSON storage"
  value       = aws_s3_bucket.geojson_storage.arn
}