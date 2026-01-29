# Kratix Orchestrator Proof of Concept

A proof of concept demonstrating the use of [Kratix.io](https://kratix.io)
Promises to enable platform users to specify custom resources that
automatically generate infrastructure as code across multiple Git repositories.

## Overview

This POC explores how Kratix Promises can be used to:

- Allow platform users to define custom resources
- Automatically generate infrastructure as code from these resources
- Distribute the generated code across multiple Git repositories
- Manage infrastructure using Kubernetes-native approaches

## Technology Stack

- **Kratix.io**: Platform orchestration and Promise management
- **Kind**: Local Kubernetes cluster for development and testing
- **Raw Kubernetes Manifests**: Primary approach for infrastructure definition
- **Helm**: Alternative packaging option where appropriate
- **Git**: Multiple repositories for infrastructure as code distribution

## Architecture

The POC implements a workflow where:

1. Platform users create custom resource definitions through Kratix Promises
2. Kratix processes these resources and generates appropriate infrastructure code
3. Generated code is automatically committed to designated Git repositories
4. Infrastructure changes are applied through standard GitOps workflows

## Getting Started

### Prerequisites

- Docker
- Kind
- kubectl
- Git
- Go (for Kratix CLI)

### Setup

1. Clone this repository
2. Start local Kind cluster:

   ```bash
   kind create cluster --name kratix-poc
   ```

3. Install Kratix components:

   ```bash
   kubectl apply -f https://github.com/syntasso/kratix/releases/download/latest/kratix-quick-start-installer.yaml

   # Watch the installation (optional)
   kubectl logs -f job/kratix-quick-start-installer -n kratix-platform-system

   # Verify installation
   kubectl get pods -n kratix-platform-system
   ```

4. Install Kratix CLI:

   ```bash
   go install github.com/syntasso/kratix-cli/cmd/kratix@latest
   ```

5. Configure Promise definitions
6. Set up Git repository connections

## Project Structure

```
├── promises/              # Kratix Promise definitions
│   └── team-promise/      # Team provisioning Promise
│       ├── promise.yaml
│       ├── example-resource.yaml
│       └── workflows/
├── manifests/             # Raw Kubernetes manifests
├── helm/                  # Helm charts (optional)
├── examples/              # Example custom resources
└── docs/                  # Additional documentation
```

## Promises

### Team Promise

The Team Promise provides "Team provisioning as a service" functionality:

- Creates team resources with unique ID and descriptive name
- Generates Backstage-compatible team definitions
- Uses Python-based configure workflow
- Outputs team definitions to designated repositories

Example usage:

```yaml
apiVersion: platform.kratix.io/v1alpha1
kind: Team
metadata:
  name: example-team
spec:
  id: team-a
  name: Team A
```

## Development

This is an active proof of concept. Contributions and feedback are welcome as
we explore the capabilities of Kratix for multi-repository infrastructure
orchestration.

