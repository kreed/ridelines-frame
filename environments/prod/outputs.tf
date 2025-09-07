# Outputs for prod environment

output "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID for prod environment"
  value       = module.dns.hosted_zone_id
}

output "name_servers" {
  description = "Route 53 name servers for prod environment"
  value       = module.dns.name_servers
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role for prod environment"
  value       = module.github_actions.github_actions_role_arn
}

output "website_bucket_name" {
  description = "Name of the S3 bucket for website assets"
  value       = module.website.website_bucket_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.website.cloudfront_distribution_id
}

output "rum_app_monitor_id" {
  description = "CloudWatch RUM app monitor ID"
  value       = module.website.rum_app_monitor_id
}

