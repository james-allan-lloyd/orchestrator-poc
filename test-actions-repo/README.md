# Gitea Actions Test Repository

This repository is used to test Gitea Actions runner functionality.

## Test Workflow

The test workflow (`.gitea/workflows/test-runner.yml`) includes:

1. **Basic Functionality Test**
   - Checkout code
   - Test basic commands and file operations
   - Verify Docker availability
   - Check environment variables

2. **Terraform Tools Test**
   - Setup Terraform
   - Create and run a simple Terraform configuration
   - Test terraform init, plan, and apply

3. **Organization Workflow Simulation**
   - Simulate the organization creation workflow
   - Create mock Terraform files similar to team promise output
   - Verify file structure

## Usage

1. Push code to trigger the workflow
2. Or manually trigger via "Actions" tab in Gitea
3. Monitor workflow execution in Gitea UI

## Runner Setup

The runner is configured to:
- Run outside Kind cluster using Docker
- Connect to Gitea via port-forward (localhost:8443)
- Execute workflows with Docker-in-Docker capability# Test Tue 03 Feb 2026 10:32:57 CET
