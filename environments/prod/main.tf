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

# Website module (CloudFront + S3 buckets + ACM certificate)
module "website" {
  source = "../../modules/website"

  project_name   = var.project_name
  environment    = local.environment
  domain_name    = var.domain_name
  hosted_zone_id = module.dns.hosted_zone_id
  price_class    = var.cloudfront_price_class
  enable_logging = var.enable_cloudfront_logging
  tags           = local.common_tags
}

# Athlete state module (GeoJSON S3 bucket)
module "athlete_state" {
  source = "../../modules/athlete-state"

  project_name = var.project_name
  environment  = local.environment
  tags         = local.common_tags
}

# Drivetrain Lambda module
module "drivetrain_lambda" {
  source = "../../modules/drivetrain-lambda"

  project_name                = var.project_name
  environment                 = local.environment
  athlete_state_bucket_name   = module.athlete_state.bucket_name
  athlete_state_bucket_arn    = module.athlete_state.bucket_arn
  activities_bucket_name      = module.website.activities_bucket_name
  activities_bucket_arn       = "arn:aws:s3:::${module.website.activities_bucket_name}"
  cloudfront_distribution_id  = module.website.cloudfront_distribution_id
  cloudfront_distribution_arn = module.website.cloudfront_distribution_arn
  enable_function_url         = var.enable_lambda_function_url
  tags                        = local.common_tags
}