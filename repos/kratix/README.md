# Kratix GitOps Repository

This repository contains infrastructure-as-code managed by the Kratix platform. Team resources created through Kratix Promises generate Terraform configurations that are automatically applied via Gitea Actions.

## Structure

- **terraform/**: Contains Terraform configurations for team organizations
  - `provider.tf`: Terraform provider configuration (Gitea)
  - `variables.tf`: Variable definitions
  - `org-*.tf`: Team-specific organization configurations
- **.gitea/workflows/**: Gitea Actions workflows
  - `deploy-organizations.yml`: Automatically deploys infrastructure changes

## How It Works

1. **Team Creation**: When a Team resource is created in Kratix, the Team Promise generates:
   - Backstage team definition
   - Terraform configuration for Gitea organization
   
2. **GitOps Workflow**: The generated files are committed to this repository via GitStateStore

3. **Automated Deployment**: The `deploy-organizations.yml` workflow triggers on changes and applies Terraform configurations

## Team Promise Integration

Teams are created using the Team Promise with specifications like:

```yaml
apiVersion: platform.kratix.io/v1alpha1
kind: Team
metadata:
  name: team-alpha
spec:
  id: alpha
  name: Team Alpha
  email: alpha@company.com
```

This generates corresponding Terraform configuration in `terraform/org-alpha.tf` and Backstage definition in `backstage-team-alpha.yaml`.

## Workflow Environment

The deployment workflow uses:
- **GITEA_ADMIN_TOKEN**: Repository secret for Gitea API access
- **Terraform Backend**: Local state management within the workflow
- **Provider Configuration**: Connects to internal Gitea instance

## Manual Operations

To manually apply changes:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Set required environment variables:
```bash
export TF_VAR_gitea_admin_token="your-token"
export TF_VAR_gitea_base_url="http://gitea-http.gitea.svc.cluster.local:3000"
```