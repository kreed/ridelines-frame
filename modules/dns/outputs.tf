output "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Route 53 name servers"
  value       = aws_route53_zone.main.name_servers
}