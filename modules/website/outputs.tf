output "website_bucket_name" {
  description = "Name of the S3 bucket for website assets"
  value       = aws_s3_bucket.website.bucket
}

output "activities_bucket_name" {
  description = "Name of the S3 bucket for activities data"
  value       = aws_s3_bucket.activities.bucket
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.main.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_key_pair_id" {
  description = "CloudFront key pair ID for signed URLs"
  value       = aws_cloudfront_public_key.activities.id
  sensitive   = true
}

output "cloudfront_private_key" {
  description = "CloudFront private key for signed URLs"
  value       = tls_private_key.cloudfront_signing.private_key_pem
  sensitive   = true
}

output "rum_app_monitor_id" {
  description = "CloudWatch RUM app monitor ID"
  value       = aws_rum_app_monitor.main.app_monitor_id
}

output "rum_app_monitor_name" {
  description = "CloudWatch RUM app monitor name"
  value       = aws_rum_app_monitor.main.name
}

