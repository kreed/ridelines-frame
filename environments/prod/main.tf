# Production environment configuration for Ridelines Frame

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.9"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

# Local values for production environment
locals {
  environment = "prod"

  common_tags = {
    Project     = var.project_name
    Environment = "prod"
    ManagedBy   = "terraform"
  }

}

# DNS module
module "dns" {
  source = "../../modules/dns"

  domain_name = var.domain_name
  tags        = local.common_tags
}

# Remote state data source for dev environment
data "terraform_remote_state" "dev" {
  backend = "s3"
  config = {
    bucket = "tofu-052941644876"
    key    = "ridelines-frame/terraform.tfstate"
    region = "us-west-2"
  }
}

# NS record for dev subdomain delegation
resource "aws_route53_record" "dev_delegation" {
  zone_id = module.dns.hosted_zone_id
  name    = "dev.${var.domain_name}"
  type    = "NS"
  ttl     = 300
  records = data.terraform_remote_state.dev.outputs.name_servers
}

# CNAME record for Clerk authentication
resource "aws_route53_record" "clerk" {
  zone_id = module.dns.hosted_zone_id
  name    = "clerk.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = ["frontend-api.clerk.services"]
}

# CNAME record for Clerk accounts
resource "aws_route53_record" "clerk_accounts" {
  zone_id = module.dns.hosted_zone_id
  name    = "accounts.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = ["accounts.clerk.services"]
}

# CNAME record for Clerk mail
resource "aws_route53_record" "clerk_mail" {
  zone_id = module.dns.hosted_zone_id
  name    = "clkmail.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = ["mail.161qk4s98918.clerk.services"]
}

# CNAME records for Clerk DKIM keys
resource "aws_route53_record" "clerk_dkim1" {
  zone_id = module.dns.hosted_zone_id
  name    = "clk._domainkey.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = ["dkim1.161qk4s98918.clerk.services"]
}

resource "aws_route53_record" "clerk_dkim2" {
  zone_id = module.dns.hosted_zone_id
  name    = "clk2._domainkey.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = ["dkim2.161qk4s98918.clerk.services"]
}

# Website module (CloudFront + S3 buckets + ACM certificate)
module "website" {
  source = "../../modules/website"

  project_name         = var.project_name
  environment          = local.environment
  domain_name          = var.domain_name
  hosted_zone_id       = module.dns.hosted_zone_id
  price_class          = var.cloudfront_price_class
  enable_logging       = var.enable_cloudfront_logging
  chainring_lambda_url = module.chainring.lambda_function_url
  tags                 = local.common_tags
}

# Chainring API module (new tRPC backend that owns the users table)
module "chainring" {
  source = "../../modules/chainring"

  project_name                = var.project_name
  environment                 = local.environment
  clerk_secret_key            = var.clerk_secret_key
  clerk_publishable_key       = var.clerk_publishable_key
  clerk_jwt_key               = var.clerk_jwt_key
  domain_name                 = var.domain_name
  allowed_origins             = ["https://${var.domain_name}"]
  cloudfront_distribution_arn = module.website.cloudfront_distribution_arn
  cloudfront_key_pair_id      = module.website.cloudfront_key_pair_id
  cloudfront_private_key      = module.website.cloudfront_private_key
  sync_queue_arn              = module.drivetrain_sync.sync_queue_arn
  tags                        = local.common_tags
}

# Sync module (existing activity sync functionality)
module "drivetrain_sync" {
  source = "../../modules/drivetrain-sync"

  project_name                = var.project_name
  environment                 = local.environment
  activities_bucket_name      = module.website.activities_bucket_name
  activities_bucket_arn       = "arn:aws:s3:::${module.website.activities_bucket_name}"
  cloudfront_distribution_id  = module.website.cloudfront_distribution_id
  cloudfront_distribution_arn = module.website.cloudfront_distribution_arn
  users_table_name            = module.chainring.users_table_name
  users_table_arn             = module.chainring.users_table_arn
  sync_status_table_name      = module.chainring.sync_status_table_name
  sync_status_table_arn       = module.chainring.sync_status_table_arn
  clerk_secret_key            = var.clerk_secret_key
  tags                        = local.common_tags
}

# GitHub Actions IAM module
module "github_actions" {
  source = "../../modules/github-actions-iam"

  project_name      = var.project_name
  environment       = local.environment
  github_repository = var.github_repository
  tags              = local.common_tags
}
