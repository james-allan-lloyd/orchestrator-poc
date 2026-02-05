# Gitea Actions Runner Setup Guide

This guide walks you through setting up an enhanced Gitea installation with Actions enabled and persistent storage, plus a Gitea Actions runner for executing CI/CD workflows, including our Terraform organization creation pipeline.

## Prerequisites

- Kind cluster running
- Docker installed and running on host machine
- kubectl configured to access the cluster
- Port 8443 available for port forwarding
- openssl available for generating random secrets

## SSL/TLS Configuration

All Gitea scripts now use centralized SSL configuration via `scripts/gitea-config.sh`. This allows easy switching between secure and insecure modes:

- **Development mode** (default): Uses self-signed certificates with SSL verification disabled
- **Production mode**: Uses proper SSL certificates with full verification

To switch to production mode:
```bash
# Edit scripts/gitea-config.sh and change:
export GITEA_SSL_SECURE_MODE="true"
```

The centralized configuration handles:
- URL generation (localhost:8443 for port-forwarding)
- SSL certificate verification flags
- Git SSL settings for repository operations
- Curl command SSL options

## Enhanced Gitea Installation

Our enhanced Gitea setup includes:
- **Actions enabled** (unlike the default Kratix installation)
- **Persistent storage** (5GB PVC instead of in-memory)
- **Secure random credentials** (generated automatically)
- **Environment variable configuration** (no hardcoded secrets)

### Deploy Enhanced Gitea

```bash
./scripts/deploy-gitea-enhanced.sh
```

This script will:
1. Generate secure random credentials and tokens
2. Remove any existing Gitea installation
3. Deploy the enhanced version with Actions enabled
4. Wait for the deployment to be ready
5. Display connection information and credentials

### Key Differences from Standard Installation

| Feature | Standard Kratix Install | Enhanced Install |
|---------|------------------------|------------------|
| Actions | Disabled | **Enabled** |
| Storage | In-memory (lost on restart) | **5GB Persistent Volume** |
| Credentials | Hardcoded | **Randomly generated** |
| Configuration | ConfigMap | **Environment variables** |
| Security Tokens | Hardcoded | **Randomly generated per deployment** |

## Step-by-Step Setup

### 1. Get Registration Token

The runner needs a registration token from Gitea. You have two options:

#### Option A: Manual Token Creation (Recommended)

1. Start port forward to Gitea:
   ```bash
   kubectl port-forward -n gitea svc/gitea-http 8443:443
   ```

2. Open https://localhost:8443 in your browser
3. Login with Gitea admin credentials:
   ```bash
   # Get credentials
   kubectl get secret gitea-credentials -o jsonpath='{.data.username}' | base64 -d
   kubectl get secret gitea-credentials -o jsonpath='{.data.password}' | base64 -d
   ```

4. Navigate to **Admin Panel** → **Actions** → **Runners**
5. Click **"Create registration token"**
6. Copy the generated token

#### Option B: API Token Creation (if supported)

Some Gitea versions support API token creation. The setup script will attempt this automatically.

### 2. Setup the Runner

1. Export the registration token:
   ```bash
   export GITEA_RUNNER_REGISTRATION_TOKEN='your_token_here'
   ```

2. Run the setup script:
   ```bash
   ./scripts/setup-gitea-runner.sh
   ```

The script will:
- Set up port forwarding to Gitea
- Start the runner container (trying non-privileged first, falling back to privileged if needed)
- Register the runner with Gitea
- Display status and useful commands

### 3. Create Test Repository

Create a test repository to verify the runner works:

```bash
./scripts/create-test-repo.sh
```

This creates a repository with test workflows that verify:
- Basic runner functionality
- Docker availability
- Terraform tools
- Organization creation simulation

## Runner Configuration Details

### Container Setup

The runner container is configured with:
- **Image**: `gitea/act_runner:latest`
- **Network**: Host networking for Gitea connectivity
- **Volumes**: 
  - Docker socket for container spawning
  - Persistent data volume for runner state
- **Environment**:
  - `GITEA_INSTANCE_URL`: https://localhost:8443 (port-forwarded)
  - `GITEA_RUNNER_REGISTRATION_TOKEN`: From Gitea admin panel
  - `GITEA_RUNNER_NAME`: gitea-runner-local

### Privilege Modes

The script attempts two modes:

1. **Non-privileged mode** (preferred):
   - Uses Docker socket sharing
   - Adds host.docker.internal mapping
   - More secure but may not work in all environments

2. **Privileged mode** (fallback):
   - Full container privileges
   - Required for some Docker-in-Docker scenarios
   - Less secure but more compatible

## Testing the Setup

### 1. Check Runner Status

```bash
# View runner logs
docker logs -f gitea-actions-runner

# Check if runner is registered in Gitea
# Visit: https://localhost:8443/admin/actions/runners
```

### 2. Trigger Test Workflow

1. Visit the test repository: https://localhost:8443/gitea_admin/actions-test
2. Go to **Actions** tab
3. Either:
   - Push a commit to trigger the workflow
   - Click **"Run workflow"** to manually trigger

### 3. Monitor Execution

Watch the workflow execution in the Gitea UI to verify:
- Runner picks up jobs
- Docker commands work
- Terraform tools are available
- File operations succeed

## Troubleshooting

### Runner Not Connecting

1. **Check port forwarding**:
   ```bash
   # Test connection (SSL options handled by central config)
   source scripts/gitea-config.sh
   gitea_curl "$(gitea_local_url)"
   ```

2. **Verify registration token**:
   - Ensure token is not expired
   - Generate a new token if needed

3. **Check runner logs**:
   ```bash
   docker logs gitea-actions-runner
   ```

### Workflow Failures

1. **Docker permission issues**:
   - Try restarting runner in privileged mode
   - Check Docker socket permissions

2. **Network connectivity**:
   - Ensure host networking is working
   - Verify DNS resolution

### Common Issues

| Issue | Solution |
|-------|----------|
| "Runner not found" | Re-register with new token |
| Docker permission denied | Use privileged mode |
| Network timeout | Check port forwarding |
| SSL certificate error | Verify -k flag in curl commands |

## Integration with Organization Workflow

Once the runner is working, it can execute our organization creation pipeline:

1. **Team Promise** generates Terraform files in Git repository
2. **Gitea Actions** detects changes to `terraform/` directory  
3. **Runner** executes the `deploy-organizations.yml` workflow
4. **Terraform** creates organizations in Gitea via provider

The complete GitOps flow:
```
Team Resource → Kratix → Git → Gitea Actions → Runner → Terraform → Gitea Org
```

## Cleanup

To stop and remove the runner:

```bash
# Stop runner
docker stop gitea-actions-runner

# Remove container
docker rm gitea-actions-runner

# Remove data volume (optional)
docker volume rm gitea-runner-data

# Stop port forward
# Kill the port-forward process shown in setup output
```