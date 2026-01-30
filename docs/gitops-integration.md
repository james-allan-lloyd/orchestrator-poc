# GitOps Integration Guide

This guide demonstrates how the Team Promise integrates with Gitea as a Git State Store to provide a complete GitOps workflow.

## Overview

When a Team resource is created, Kratix:
1. Executes the Team Promise workflow
2. Generates Backstage-compatible YAML
3. Automatically commits the generated IaC to the Gitea repository
4. Makes it available for downstream GitOps tools

## Accessing Gitea

### Web Interface

1. Port-forward to access Gitea locally:
   ```bash
   kubectl port-forward -n gitea svc/gitea-http 8443:443
   ```

2. Open https://localhost:8443 in your browser
   - Username: `gitea_admin`
   - Password: `r8sA8CPHD9!bt6d`

### Repository Location

- Repository URL: https://localhost:8443/gitea_admin/kratix
- Generated team files are stored in the repository root

## Git Repository Structure Options

Kratix supports different filepath modes for organizing files in the Git repository to match GitOps tool requirements:

### AggregatedYAML Mode (Current Configuration)
All team resources are consolidated into a single YAML file:
```
kratix/
└── teams/
    └── backstage-teams.yaml       # All Backstage Group definitions
```

### Nested Mode (Default)
Each resource creates its own directory structure:
```
kratix/
├── teams/
│   ├── team-{id}/
│   │   └── backstage-team-{id}.yaml
│   └── team-{another-id}/
│       └── backstage-team-{another-id}.yaml
```

### Flat Mode
Files are written directly to the specified path:
```
kratix/
└── backstage-catalog/
    ├── backstage-team-{id}.yaml
    ├── backstage-team-{another-id}.yaml
    └── backstage-team-{third-id}.yaml
```

## GitOps Tool Compatibility

- **AggregatedYAML**: Best for tools that prefer single manifest files
- **Nested**: Good for tools that handle directory structures well  
- **Flat**: Optimal for Backstage catalog discovery and simple GitOps tools

## Configuring Repository Structure

To change the file organization mode, update the Destination configuration:

### For AggregatedYAML (Single File)
```yaml
apiVersion: platform.kratix.io/v1alpha1
kind: Destination
metadata:
  name: gitea-destination
spec:
  path: teams
  filepath:
    mode: aggregatedYAML
    filename: backstage-teams.yaml
  stateStoreRef:
    kind: GitStateStore
    name: default
```

### For Flat Structure (Individual Files)
```yaml
apiVersion: platform.kratix.io/v1alpha1
kind: Destination
metadata:
  name: gitea-destination-flat
spec:
  path: backstage-catalog
  filepath:
    mode: none
  stateStoreRef:
    kind: GitStateStore
    name: default
```

**Note**: The `filepath.mode` is immutable once set. To change modes, you must delete and recreate the Destination.

## Example Workflow

1. Create a team resource:
   ```bash
   kubectl apply -f promises/team-promise/example-resource.yaml
   ```

2. Check team status:
   ```bash
   kubectl get teams
   ```

3. View generated files in Gitea:
   - Navigate to https://localhost:8443/gitea_admin/kratix
   - Browse the repository for generated team files

## GitOps Consumption

The generated YAML files in Gitea can be consumed by:

- **ArgoCD**: Configure ArgoCD to watch the Gitea repository
- **Flux**: Set up Flux to sync from the Gitea repository  
- **Custom GitOps tools**: Use git webhooks or polling to detect changes
- **Backstage**: Configure Backstage to read catalog entries from the repository

## Integration Benefits

- **Version Control**: All generated IaC is versioned in Git
- **Auditability**: Complete history of infrastructure changes
- **GitOps Compatibility**: Standard Git repository for downstream tools
- **Multi-tenancy**: Separate directories for different teams/resources
- **Security**: Git-based access controls and authentication