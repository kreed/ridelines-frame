# Outputs for dev environment

output "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID for dev environment"
  value       = module.dns.hosted_zone_id
}

output "name_servers" {
  description = "Route 53 name servers for dev environment"
  value       = module.dns.name_servers
}