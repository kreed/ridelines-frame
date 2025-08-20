# Ridelines Frame

The foundational infrastructure project that supports all Ridelines components.

## Overview

Ridelines Frame is the centralized infrastructure management system for the Ridelines ecosystem. It consumes build artifacts from component repositories (hub, drivetrain) as GitHub packages and deploys them to AWS environments.

## Architecture

- **Hub**: SvelteKit frontend published as static site package
- **Drivetrain**: Rust Lambda function + Tippecanoe layer published as separate packages
- **Frame**: Infrastructure-as-code that deploys packages to dev/prod environments

## Package Strategy

### Published Packages
1. `ghcr.io/ridelines/hub` - Static website build artifacts
2. `ghcr.io/ridelines/drivetrain-lambda` - Lambda deployment package
3. `ghcr.io/ridelines/drivetrain-tippecanoe-layer` - Lambda layer with tippecanoe binary

### Version Management
Package versions are tracked in `versions.yml` with automatic updates via GitHub Actions.

## Environments

- **Development**: Persistent environment, auto-deploys latest packages
- **Production**: Stable environment, manual deployment via PR approval

## Deployment Flow

1. Component repositories publish packages to GitHub Container Registry
2. Version updater creates consolidated PR with latest package versions
3. Development environment auto-deploys when versions.yml changes
4. Production deployment requires manual PR approval

## Getting Started

### Prerequisites
- OpenTofu CLI
- AWS CLI configured
- GitHub CLI (for package management)

### Commands
```bash
# Deploy to development (packages auto-downloaded via GitHub Actions)
cd environments/dev && tofu plan && tofu apply

# Deploy to production (after PR approval)
cd environments/prod && tofu plan && tofu apply
```

## Project Structure

```
├── .github/workflows/          # Deployment automation
├── environments/              # Environment-specific configurations
│   ├── dev/                  # Development environment
│   ├── prod/                 # Production environment
│   └── shared/               # Shared resources
├── modules/                  # Reusable infrastructure modules
├── scripts/                  # Package management scripts
└── versions.yml              # Package version tracking
```

## License

MIT License. See [LICENSE](LICENSE) for details.

This project is part of the Ridelines ecosystem for visualizing GPS activity data.