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

- Docker (or Podman with Docker compatibility)
- Kind
- kubectl
- Git
- Helm
- SSH client
- OpenSSL (for certificate generation)

> **Rootless Podman / Kind:** If you're running Kind with rootless Podman, you may hit issues with port mappings and load balancing. See the [Kind rootless guide](https://kind.sigs.k8s.io/docs/user/rootless/) for the required setup steps.

### Quick Start - Automated 6-Stage Build

For a complete automated setup, run:

```bash
./scripts/build-poc.sh
```

This runs all 6 stages in sequence with proper verification at each step.

### Manual Stage-by-Stage Setup

#### Stage 1: Cluster Preparation

```bash
./scripts/01-setup-cluster.sh
```

- Creates Kind cluster with ingress controller
- Configures port mappings for SSH (30222) and HTTP (80/443)
- Installs NGINX ingress controller

#### Stage 2: Kratix Installation

```bash
./scripts/02-install-kratix.sh
```

- Installs Kratix platform components
- Applies UID 65534 patch for Git operations
- Removes default BucketStateStore destination

#### Stage 3: Gitea + Actions Runner

```bash
./scripts/03-setup-gitea.sh
```

- Deploys Gitea via Helm with PostgreSQL and SSH
- Generates secure credentials and tokens
- Sets up and registers Actions runner
- Creates test repository for validation

#### Stage 4: SSH Git Destination

```bash
./scripts/04-configure-ssh-gitea.sh
```

- Generates SSH keys for Kratix GitStateStore authentication
- Configures SSH Kratix GitStateStore with proper authentication
- Verifies SSH connectivity and readiness

#### Stage 5: Kratix Repository + Pipeline

```bash
./scripts/05-setup-kratix-repo.sh
```

- Sets up kratix repository for infrastructure code
- Configures Terraform pipeline and secrets
- Enables Actions for automated workflows

#### Stage 6: Promise Installation + Testing

```bash
./scripts/06-test-teams.sh
```

- Installs Team Promise
- Tests team creation, update, and deletion lifecycle
- Verifies GitOps workflow and Terraform execution

### Verification

After each stage, verify the setup:

- **Stage 1**: `kubectl get nodes` and `kubectl get pods -n ingress-nginx`
- **Stage 2**: `kubectl get pods -n kratix-platform-system`
- **Stage 3**: Visit `http://localhost:8080` and check runner with `docker ps`
- **Stage 4**: `kubectl get gitstatestore` should show "Ready"
- **Stage 5**: Check repository at `http://localhost:8080/gitea_admin/kratix`
- **Stage 6**: `kubectl get teams` and verify files in git repository

## Project Structure

```
├── promises/              # Kratix Promise definitions
│   └── team-promise/      # Team provisioning Promise
│       ├── promise.yaml   # Promise definition with email validation
│       ├── example-resource.yaml
│       └── workflows/
│           └── resource/configure/team-configure/python/scripts/
│               ├── configure.py           # Main configure script
│               └── terraform_templates/   # Terraform templates
├── manifests/             # Kubernetes manifests
│   ├── kind-cluster-config.yaml     # Kind cluster with ingress + port mappings
│   ├── gitea-helm-values.yaml       # Gitea Helm chart values
│   ├── gitea-ssh-statestore.yaml    # SSH GitStateStore configuration
│   ├── gitea-https-statestore.yaml  # HTTPS GitStateStore configuration (not used by default)
│   ├── git-destination.yaml         # Nested filepath Destination (not used by default)
│   └── git-destination-flat.yaml    # Flat filepath Destination
├── scripts/               # Setup and utility scripts
│   ├── build-poc.sh                 # Automated 6-stage build
│   ├── cleanup-poc.sh               # Full teardown
│   ├── 01-setup-cluster.sh          # Stage 1: Kind cluster + ingress
│   ├── 02-install-kratix.sh         # Stage 2: Kratix platform
│   ├── 03-setup-gitea.sh            # Stage 3: Gitea + Actions runner
│   ├── 04-configure-ssh-gitea.sh    # Stage 4: SSH Git destination
│   ├── 05-setup-kratix-repo.sh      # Stage 5: Kratix repo + pipeline
│   ├── 06-test-teams.sh             # Stage 6: Promise install + testing
│   ├── gitea-config.sh              # Centralized Gitea configuration
│   ├── setup-gitea-runner.sh        # Actions runner setup
│   ├── run-tests.sh                 # Unit test runner
│   └── run-contract-tests.sh        # Contract test runner
├── tests/                 # Comprehensive test suite
│   ├── unit/              # Unit tests for configure scripts
│   ├── contract/          # API and format validation tests
│   ├── integration/       # Integration tests
│   └── e2e/               # End-to-end workflow tests
├── docs/                  # Documentation
│   ├── gitops-integration.md    # GitOps workflow guide
│   ├── gitea-actions-setup.md   # Actions runner setup guide
│   └── tutorial.md              # Team Promise tutorial
└── repos/
    ├── test-actions/     # Test repository for Actions validation
    │   ├── .gitea/workflows/
    │   └── README.md
    └── kratix/           # Base IaC repository for the platform
        ├── .gitea/workflows/
        │   └── deploy-organizations.yml
        ├── terraform/
        └── README.md
```

## Promises

### Team Promise

The Team Promise provides "Team provisioning as a service" functionality with
automatic organization creation:

- Creates team resources with unique ID, name, and optional email
- Generates Backstage-compatible team definitions
- **Automatically creates Gitea organizations** using Terraform
- **Triggers CI/CD workflows** via Gitea Actions
- Uses Python-based configure workflow with comprehensive validation
- Outputs both Backstage YAML and Terraform IaC to Git repositories

Example usage:

```yaml
apiVersion: platform.kratix.io/v1alpha1
kind: Team
metadata:
  name: example-team
spec:
  id: team-alpha
  name: Team Alpha
  email: alpha@company.com # Optional, defaults to team-alpha@example.com
```

Features:

- **Email validation** with regex patterns at CRD level
- **Smart defaults** for email (uses <team-id@example.com> if not provided)
- **Terraform generation** for Gitea organization creation
- **GitOps workflow** with plan → review → apply process
- **Comprehensive testing** with unit, contract, and integration tests

## Development

### Testing

The project includes automated test scripts that handle virtual environment setup and cleanup automatically:

```bash
# Run unit tests (fastest, tests Promise configure scripts)
./scripts/run-tests.sh

# Run contract tests (API and format validation)
./scripts/run-contract-tests.sh

# Run individual test categories manually (if needed)
cd tests
python -m venv test-env
source test-env/bin/activate
pip install -r requirements.txt

# Unit tests
PYTHONPATH=../promises/team-promise/workflows/resource/configure/team-configure/python/scripts python -m pytest unit/ -v

# Contract tests
python -m pytest contract/ -v

# Cleanup
deactivate
```

**Recommended**: Use the test scripts (`./scripts/run-tests.sh` and `./scripts/run-contract-tests.sh`) as they automatically handle virtual environment setup, dependency installation, and cleanup.

### Test Structure

- `tests/unit/`: Unit tests for Promise configure scripts and Terraform generation
- `tests/contract/`: API and format validation tests for generated outputs
- `tests/integration/`: Integration tests with Kubernetes cluster (planned)
- `tests/e2e/`: End-to-end workflow tests (planned)

### Gitea Actions Testing

Test the complete CI/CD pipeline:

```bash
# Automated: runs all stages including Gitea + runner setup
./scripts/build-poc.sh

# Or manually run individual stages:
./scripts/03-setup-gitea.sh          # Deploy Gitea with Actions enabled
./scripts/04-configure-ssh-gitea.sh  # Configure SSH Git destination
./scripts/05-setup-kratix-repo.sh    # Set up kratix repo + pipeline
```

The test repository includes workflows that validate:

- Basic runner functionality and environment
- Docker/container execution capabilities
- Terraform tools availability
- Organization creation workflow simulation

### Cleanup

To tear down the entire POC environment:

```bash
./scripts/cleanup-poc.sh
```

This removes the Kind cluster, runner containers, and all associated resources.

---

This is an active proof of concept. Contributions and feedback are welcome as
we explore the capabilities of Kratix for multi-repository infrastructure
orchestration.
