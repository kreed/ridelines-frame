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