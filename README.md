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
- yq (for YAML processing)
- wget (for downloading binaries)

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

5. Set up Enhanced Git State Store with Actions enabled:

   ```bash
   # Deploy enhanced Gitea with Actions enabled and persistent storage
   ./scripts/deploy-gitea-enhanced.sh

   # Configure Git State Store
   kubectl apply -f manifests/gitstatestore.yaml

   # Remove default BucketStateStore destination and add Git destination
   kubectl delete destination worker-1 --ignore-not-found=true
   kubectl apply -f manifests/git-destination.yaml

   # Verify Git State Store is ready
   kubectl get gitstatestore
   ```

   **Note**: The enhanced Gitea installation includes:

   - **Actions enabled** (for CI/CD workflows)
   - **5GB persistent storage** (data survives restarts)
   - **Randomly generated secure credentials** (no hardcoded secrets)
   - **Environment-based configuration** (following Gitea best practices)
   - **Centralized SSL configuration** (via `scripts/gitea-config.sh`) for easy dev/production switching

6. Configure Promise definitions

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
│   ├── gitstatestore.yaml            # Git State Store configuration
│   └── gitea-install-enhanced.yaml   # Enhanced Gitea with Actions
├── scripts/               # Setup and utility scripts
│   ├── generate-gitea-credentials.sh # Enhanced credential generation
│   ├── deploy-gitea-enhanced.sh      # Deploy enhanced Gitea
│   ├── setup-gitea-runner.sh         # Actions runner setup
│   ├── get-runner-token.sh           # Get registration token
│   ├── create-test-repo.sh           # Create test repository
│   ├── run-tests.sh                  # Unit test runner
│   └── run-contract-tests.sh         # Contract test runner
├── tests/                 # Comprehensive test suite
│   ├── unit/              # Unit tests for configure scripts
│   ├── contract/          # API and format validation tests
│   ├── integration/       # Integration tests
│   └── e2e/               # End-to-end workflow tests
├── docs/                  # Documentation
│   ├── gitops-integration.md    # GitOps workflow guide
│   └── gitea-actions-setup.md   # Actions runner setup guide
├── .gitea/workflows/      # Gitea Actions workflows
│   └── deploy-organizations.yml # Organization deployment workflow
└── repos/
    ├── test-actions/     # Test repository for Actions validation
    │   ├── .gitea/workflows/
    │   └── README.md
    └── kratix/           # Base IaC repository for the platform
        ├── .gitea/workflows/
    │   │   └── deploy-organizations.yml # Organization deployment workflow
        └── README.md
```

## Promises

### Team Promise

The Team Promise provides "Team provisioning as a service" functionality with automatic organization creation:

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

Test the complete CI/CD pipeline with the enhanced Gitea setup:

```bash
# Deploy enhanced Gitea with Actions enabled
./scripts/deploy-gitea-enhanced.sh

# Set up Actions runner
./scripts/get-runner-token.sh
./scripts/setup-gitea-runner.sh

# Create test repository to validate runner functionality
./scripts/create-test-repo.sh
```

The test repository includes workflows that validate:

- Basic runner functionality and environment
- Docker/container execution capabilities
- Terraform tools availability
- Organization creation workflow simulation

This is an active proof of concept. Contributions and feedback are welcome as
we explore the capabilities of Kratix for multi-repository infrastructure
orchestration.
