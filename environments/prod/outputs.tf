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