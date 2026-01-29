# Kratix Orchestrator Proof of Concept

A proof of concept demonstrating the use of [Kratix.io](https://kratix.io) Promises to enable platform users to specify custom resources that automatically generate infrastructure as code across multiple Git repositories.

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

### Setup

1. Clone this repository
2. Start local Kind cluster
3. Install Kratix components
4. Configure Promise definitions
5. Set up Git repository connections

## Project Structure

```
├── promises/          # Kratix Promise definitions
├── manifests/         # Raw Kubernetes manifests
├── helm/              # Helm charts (optional)
├── examples/          # Example custom resources
└── docs/              # Additional documentation
```

## Development

This is an active proof of concept. Contributions and feedback are welcome as we explore the capabilities of Kratix for multi-repository infrastructure orchestration.