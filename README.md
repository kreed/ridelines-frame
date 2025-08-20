# Ridelines Frame

The infrastructure orchestration layer that powers the Ridelines GPS activity visualization ecosystem. Frame provides centralized infrastructure management, package deployment, and environment orchestration using Infrastructure as Code principles.

## Overview

Ridelines Frame is the foundational component that ties together the entire Ridelines ecosystem. It manages the deployment of frontend and backend components from GitHub Container Registry packages, provides environment separation (dev/prod), and handles all AWS infrastructure provisioning using OpenTofu/Terraform.

### Key Features

- **🏗️ Infrastructure as Code**: Complete AWS infrastructure using OpenTofu/Terraform
- **📦 Package Management**: Automated deployment from GitHub Container Registry
- **🔄 Version Control**: Centralized version tracking with automated updates
- **🌍 Multi-Environment**: Separated dev and prod environments with different policies
- **⚡ Automated Deployment**: GitHub Actions integration for CI/CD
- **🔒 Security-First**: IAM roles, OIDC authentication, and principle of least privilege
- **📊 Observability**: CloudWatch integration and infrastructure monitoring

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Ridelines Frame                         │
├─────────────────┬───────────────────┬───────────────────────────┤
│   Development   │    Production     │       Components          │
│   Environment   │   Environment     │                           │
├─────────────────┼───────────────────┼───────────────────────────┤
│ ┌─────────────┐ │ ┌─────────────┐   │ ┌─────────────────────────┐ │
│ │ Auto-Deploy │ │ │Manual Deploy│   │ │      Hub Package        │ │
│ │ Latest Pkgs │ │ │ PR Approval │   │ │   (SvelteKit Static)    │ │
│ └─────────────┘ │ └─────────────┘   │ └─────────────────────────┘ │
│ ┌─────────────┐ │ ┌─────────────┐   │ ┌─────────────────────────┐ │
│ │S3 + CF + R53│ │ │S3 + CF + R53│   │ │   Drivetrain Package    │ │
│ │   AWS Infra │ │ │   AWS Infra │   │ │  (Rust Lambda + Layer)  │ │
│ └─────────────┘ │ └─────────────┘   │ └─────────────────────────┘ │
└─────────────────┴───────────────────┴───────────────────────────┘
```

### Core Modules

#### **Website Module** (`modules/website/`)
- **Purpose**: Static website hosting with global CDN
- **Components**: S3 buckets, CloudFront distribution, ACM certificates
- **Features**: Dual-bucket architecture for website assets and activity data

#### **Drivetrain Lambda Module** (`modules/drivetrain-lambda/`)
- **Purpose**: Serverless GPS data processing infrastructure
- **Components**: Lambda function, execution role, Tippecanoe layer
- **Features**: High-memory configuration, custom runtime support

#### **Athlete State Module** (`modules/athlete-state/`)
- **Purpose**: User data and synchronization state management
- **Components**: S3 bucket with versioning and lifecycle policies
- **Features**: Secure storage for activity indexes and processing state

#### **DNS Module** (`modules/dns/`)
- **Purpose**: Domain management and SSL certificates
- **Components**: Route53 hosted zone, ACM certificates, validation records
- **Features**: Automated certificate validation and renewal

## Technology Stack

- **Infrastructure as Code**: OpenTofu (Terraform) 1.8+
- **Cloud Platform**: AWS (S3, CloudFront, Lambda, Route53, ACM, Secrets Manager)
- **Package Registry**: GitHub Container Registry
- **CI/CD**: GitHub Actions with OIDC authentication
- **Version Management**: YAML-based version tracking with automated PRs
- **Security**: IAM roles, VPC isolation, encrypted storage

## Getting Started

### Prerequisites

- **OpenTofu CLI**: 1.8+ for infrastructure management
- **AWS CLI**: Configured with appropriate permissions
- **GitHub CLI**: For package management (optional)
- **Git**: For version control

### Project Structure

```
frame/
├── .github/workflows/          # Deployment automation
│   ├── deploy-dev.yml         # Development environment deployment
│   ├── deploy-prod.yml        # Production environment deployment
│   └── version-updater.yml    # Automated version management
├── environments/              # Environment-specific configurations
│   ├── dev/                  # Development environment
│   │   ├── main.tf           # Dev infrastructure configuration
│   │   ├── variables.tf      # Dev-specific variables
│   │   ├── backend.tf        # Terraform state configuration
│   │   ├── terraform.tfvars  # Environment values
│   │   └── outputs.tf        # Dev environment outputs
│   └── prod/                 # Production environment
│       ├── main.tf           # Prod infrastructure configuration
│       ├── variables.tf      # Prod-specific variables
│       ├── backend.tf        # Terraform state configuration
│       ├── terraform.tfvars  # Environment values
│       └── outputs.tf        # Prod environment outputs
├── modules/                  # Reusable infrastructure modules
│   ├── website/              # Static website hosting
│   │   ├── main.tf          # S3 + CloudFront + CDN setup
│   │   ├── variables.tf     # Module inputs
│   │   └── outputs.tf       # Module outputs
│   ├── drivetrain-lambda/    # Lambda function infrastructure
│   │   ├── main.tf          # Lambda + IAM + layer setup
│   │   ├── variables.tf     # Module inputs
│   │   └── outputs.tf       # Module outputs
│   ├── athlete-state/        # User data storage
│   │   ├── main.tf          # S3 bucket with policies
│   │   ├── variables.tf     # Module inputs
│   │   └── outputs.tf       # Module outputs
│   └── dns/                  # Domain and certificate management
│       ├── main.tf          # Route53 + ACM setup
│       ├── variables.tf     # Module inputs
│       ├── outputs.tf       # Module outputs
│       └── versions.tf      # Provider requirements
├── scripts/                  # Package management utilities
│   └── download-packages.sh # Package download automation
├── artifacts/                # Downloaded package artifacts (gitignored)
└── versions.yml             # Package version tracking
```

### Initial Setup

1. **Configure AWS credentials**:
   ```bash
   aws configure
   # or use environment variables / IAM roles
   ```

2. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/ridelines.git
   cd ridelines/frame
   ```

3. **Initialize development environment**:
   ```bash
   cd environments/dev
   tofu init
   tofu plan
   tofu apply
   ```

## Package Management

Frame operates on a package-based deployment model where component repositories publish their build artifacts to GitHub Container Registry.

### Published Packages

| Package | Source | Description |
|---------|--------|-------------|
| `ghcr.io/ridelines/hub` | `hub/` repository | SvelteKit static site build |
| `ghcr.io/ridelines/drivetrain-lambda` | `drivetrain/` repository | Rust Lambda deployment package |
| `ghcr.io/ridelines/drivetrain-tippecanoe-layer` | `drivetrain/` repository | Tippecanoe Lambda layer |

### Version Management

Package versions are tracked in `versions.yml`:

```yaml
# Package versions for deployment
packages:
  hub:
    version: "v1.2.3"
    registry: "ghcr.io/ridelines/hub"
    type: "static-site"
    
  drivetrain-lambda:
    version: "v2.1.0" 
    registry: "ghcr.io/ridelines/drivetrain-lambda"
    type: "lambda-function"
    
  drivetrain-tippecanoe-layer:
    version: "v2.1.0"
    registry: "ghcr.io/ridelines/drivetrain-tippecanoe-layer"
    type: "lambda-layer"
```

### Automated Version Updates

The version updater workflow automatically:

1. **Monitors** component repositories for new releases
2. **Creates** consolidated PRs with version updates
3. **Triggers** development deployment on merge
4. **Requires** manual approval for production deployment

## Environment Configuration

### Development Environment

- **Auto-deployment**: Triggered when `versions.yml` changes
- **Domain**: `dev.yourdomain.com`
- **Purpose**: Testing and integration
- **Resource sizing**: Smaller instances for cost optimization

```bash
cd environments/dev
tofu plan
tofu apply
```

### Production Environment

- **Manual deployment**: Requires PR approval process
- **Domain**: `yourdomain.com`
- **Purpose**: Live application serving users
- **Resource sizing**: Production-optimized configurations

```bash
cd environments/prod
tofu plan
tofu apply
```

## Infrastructure Components

### Website Infrastructure (S3 + CloudFront)

```hcl
module "website" {
  source = "../../modules/website"
  
  project_name = var.project_name
  environment  = local.environment
  domain_name  = var.domain_name
  
  # Hub package configuration
  hub_package_path = "./artifacts/hub"
  
  # S3 and CloudFront settings
  cloudfront_price_class = var.cloudfront_price_class
  enable_logging        = var.enable_cloudfront_logging
  
  tags = local.common_tags
}
```

### Lambda Infrastructure

```hcl
module "drivetrain_lambda" {
  source = "../../modules/drivetrain-lambda"
  
  project_name = var.project_name
  environment  = local.environment
  
  # Package paths
  lambda_package_path       = "./artifacts/lambda.zip"
  tippecanoe_layer_package_path = "./artifacts/layer.zip"
  
  # S3 bucket references
  activities_bucket_name    = module.website.activities_bucket_name
  athlete_state_bucket_name = module.athlete_state.bucket_name
  
  # CloudFront integration
  cloudfront_distribution_id = module.website.cloudfront_distribution_id
  
  tags = local.common_tags
}
```

## Deployment Workflows

### Development Deployment

Triggered automatically when:
- `versions.yml` is updated (new package versions)
- Infrastructure code changes in `main` branch

```yaml
name: Deploy Development
on:
  push:
    branches: [main]
    paths: ['versions.yml', 'environments/dev/**', 'modules/**']
```

### Production Deployment

Requires manual approval:
1. Create PR with changes
2. Review and approve
3. Merge triggers production deployment

```yaml
name: Deploy Production
on:
  pull_request:
    types: [closed]
    branches: [main]
```

### Package Download

Before deployment, packages are automatically downloaded:

```bash
#!/bin/bash
# Download packages based on versions.yml

# Download hub static site
gh run download --repo ridelines/hub --name hub-build

# Download lambda packages  
gh run download --repo ridelines/drivetrain --name lambda-package
gh run download --repo ridelines/drivetrain --name tippecanoe-layer
```

## Configuration Variables

### Environment Variables

Each environment supports these configuration options:

| Variable | Description | Default | Environment |
|----------|-------------|---------|-------------|
| `project_name` | Project identifier | `ridelines` | Both |
| `environment` | Environment name | `dev`/`prod` | Both |
| `domain_name` | Primary domain | - | Both |
| `aws_region` | AWS region | `us-west-2` | Both |
| `cloudfront_price_class` | CloudFront pricing tier | `PriceClass_100` | Both |
| `enable_cloudfront_logging` | Access logging | `true` | Both |
| `enable_lambda_function_url` | Lambda function URL | `false` | Both |

### Cross-Account Configuration

For production environments using separate AWS accounts:

```hcl
# Remote state for dev environment name servers
data "terraform_remote_state" "dev" {
  backend = "s3"
  config = {
    bucket = "tofu-052941644876" 
    key    = "ridelines-frame/terraform.tfstate"
    region = "us-west-2"
  }
}

# DNS delegation to dev subdomain
resource "aws_route53_record" "dev_delegation" {
  zone_id = module.dns.hosted_zone_id
  name    = "dev.${var.domain_name}"
  type    = "NS"
  ttl     = 300
  records = data.terraform_remote_state.dev.outputs.name_servers
}
```

## Monitoring & Observability

### CloudWatch Integration

Frame provisions comprehensive monitoring:

- **Lambda Metrics**: Execution duration, memory usage, error rates
- **CloudFront Metrics**: Cache hit ratio, origin response times
- **S3 Metrics**: Request metrics and storage analytics
- **Custom Metrics**: Application-specific metrics from Lambda

### Infrastructure Monitoring

```hcl
# CloudWatch log groups for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.ridelines_drivetrain.function_name}"
  retention_in_days = 14
  tags              = var.tags
}

# CloudFront monitoring
resource "aws_cloudwatch_distribution" "monitoring" {
  distribution_id = aws_cloudfront_distribution.website.id
  enabled         = true
}
```

## Security

### IAM Roles & Policies

Frame implements security best practices:

- **Principle of Least Privilege**: Minimal required permissions
- **Cross-Service Roles**: Lambda execution role with specific S3/CloudFront access
- **OIDC Authentication**: GitHub Actions authenticate via OpenID Connect
- **Resource-Based Policies**: S3 bucket policies for CloudFront access

### Example IAM Configuration

```hcl
# Lambda execution role
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-${var.environment}-lambda-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}
```

### Secrets Management

- **API Keys**: Stored in AWS Secrets Manager
- **No Hardcoded Secrets**: All sensitive data via AWS services
- **Environment Isolation**: Separate secrets per environment

## Troubleshooting

### Common Issues

1. **Package Download Failures**
   ```bash
   # Check GitHub CLI authentication
   gh auth status
   
   # Re-authenticate if needed
   gh auth login
   ```

2. **Terraform State Issues**
   ```bash
   # Refresh state
   tofu refresh
   
   # Check state file
   tofu state list
   ```

3. **DNS Propagation**
   ```bash
   # Check DNS resolution
   dig yourdomain.com
   
   # Check certificate status
   aws acm list-certificates --region us-east-1
   ```

### Debug Mode

Enable verbose logging:

```bash
# Terraform debugging
export TF_LOG=DEBUG
tofu plan

# AWS CLI debugging  
export AWS_CLI_DEBUG=1
aws s3 ls
```

### State Management

```bash
# Import existing resources
tofu import aws_s3_bucket.example bucket-name

# Move resources between states
tofu state mv aws_instance.foo aws_instance.bar

# Remove from state without destroying
tofu state rm aws_instance.foo
```

## Contributing

### Development Guidelines

1. **Module Design**: Keep modules focused and reusable
2. **Variable Naming**: Use descriptive names with proper types
3. **Documentation**: Add descriptions for all variables and outputs
4. **Testing**: Test infrastructure changes in dev environment first
5. **Security**: Follow AWS security best practices

### Making Changes

1. **Fork** the repository
2. **Create** feature branch: `git checkout -b feature/infrastructure-improvement`
3. **Test** in development environment
4. **Document** changes in PR description
5. **Request** review from infrastructure team
6. **Deploy** to production after approval

### Code Style

- **Terraform Style**: Use `terraform fmt` for formatting
- **Variable Organization**: Group related variables together
- **Resource Naming**: Use consistent naming conventions
- **Comments**: Explain complex logic and configurations

## Cost Optimization

### Development Environment

- **Smaller Instances**: Reduced CloudFront price class
- **Shorter Retention**: Reduced log retention periods
- **Lifecycle Policies**: Automatic cleanup of old data

### Production Environment

- **Right-Sizing**: Appropriate resource allocation
- **Monitoring**: CloudWatch cost analytics
- **Reserved Capacity**: Consider reserved instances for predictable workloads

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

## Links

- [Backend (Drivetrain)](https://github.com/kreed/ridelines-drivetrain/)
- [Frontend (Hub)](https://github.com/kreed/ridelines-hub/)
- **Frontend (Hub)**: [Hub Documentation](https://github.com/kreed/ridelines-hub/)
- **Backend (Drivetrain)**: [Drivetrain Documentation](https://github.com/kreed/ridelines-drivetrain/)
- **OpenTofu Documentation**: [OpenTofu.org](https://opentofu.org/)
- **AWS Provider**: [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)