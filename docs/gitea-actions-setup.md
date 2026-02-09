# Gitea Actions Runner Setup Guide

This guide walks you through setting up an enhanced Gitea installation with Actions enabled and persistent storage, plus a Gitea Actions runner for executing CI/CD workflows, including our Terraform organization creation pipeline.

## Prerequisites

- Kind cluster running
- Docker installed and running on host machine
- kubectl configured to access the cluster
- Port 8080 available (used by Kind ingress for HTTP access to Gitea)
- openssl available for generating random secrets

## Configuration

All Gitea scripts use centralized configuration via `scripts/gitea-config.sh`. In development mode (default), Gitea is accessible at `http://localhost:8080` via Kind ingress — no port-forwarding required.

The centralized configuration handles:

- URL generation (`http://localhost:8080` for local access)
- SSL certificate verification flags
- Git SSL settings for repository operations
- Curl command SSL options

## Enhanced Gitea Installation

Our enhanced Gitea setup includes:

- **Actions enabled** (unlike the default Kratix installation)
- **Persistent storage** (5GB PVC instead of in-memory)
- **Secure random credentials** (generated automatically)
- **Environment variable configuration** (no hardcoded secrets)

### Deploy Gitea

The recommended approach is to use the automated build:

```bash
# Full automated setup (all 6 stages)
./scripts/build-poc.sh

# Or run only the Gitea stage:
./scripts/03-setup-gitea.sh
```

Stage 3 (`03-setup-gitea.sh`) will:

1. Generate secure random credentials and tokens
2. Deploy Gitea via Helm with Actions enabled
3. Set up and register the Actions runner
4. Create a test repository for validation
5. Wait for the deployment to be ready

### Key Differences from Standard Installation

| Feature         | Standard Kratix Install     | Enhanced Install                        |
| --------------- | --------------------------- | --------------------------------------- |
| Actions         | Disabled                    | **Enabled**                             |
| Storage         | In-memory (lost on restart) | **Postgres with 5GB Persistent Volume** |
| Credentials     | Hardcoded                   | **Randomly generated**                  |
| Configuration   | ConfigMap                   | **Environment variables**               |
| Security Tokens | Hardcoded                   | **Randomly generated per deployment**   |

## Step-by-Step Setup

### Automated (Recommended)

The `03-setup-gitea.sh` script handles credential generation, Helm install, runner registration, and test repo creation in one step:

```bash
./scripts/03-setup-gitea.sh
```

### Manual Setup (Fallback)

If you need to set up the runner separately:

#### 1. Get Registration Token

The `setup-gitea-runner.sh` script automatically obtains a registration token
via the Gitea API using the existing admin credentials. No manual token
creation is needed.

If automatic token creation fails, you can create one manually:

1. Open `http://localhost:8080` in your browser
2. Login with Gitea admin credentials:

   ```bash
   kubectl get secret gitea-credentials -o jsonpath='{.data.username}' | base64 -d
   kubectl get secret gitea-credentials -o jsonpath='{.data.password}' | base64 -d
   ```

3. Navigate to **Admin Panel** → **Actions** → **Runners**
4. Click **"Create registration token"** and copy the token

#### 2. Setup the Runner

```bash
./scripts/setup-gitea-runner.sh
```

The script will:

- Detect the available container runtime (Podman or Docker)
- Obtain or reuse a registration token via the Gitea API
- Start the runner container with the appropriate socket mount
- Register the runner with Gitea
- Display status and useful commands

## Runner Configuration Details

### Container Setup

The runner container is configured with:

- **Image**: `gitea/act_runner:latest`
- **Network**: Host networking for Gitea connectivity
- **Volumes**:
  - Container runtime socket (Podman or Docker) mounted as `/var/run/docker.sock`
  - Runner config from `runner-config/config.yaml`
  - Persistent data volume for runner state
- **Environment**:
  - `GITEA_INSTANCE_URL`: Set from `gitea-config.sh` (default: `http://localhost:8080`)
  - `GITEA_RUNNER_REGISTRATION_TOKEN`: Obtained automatically via Gitea API
  - `GITEA_RUNNER_NAME`: gitea-runner-local

### Container Runtime Detection

The setup script detects the available container runtime:

- **Podman** (default on Fedora/RHEL): Uses the Podman socket at `/run/user/<uid>/podman/podman.sock`
- **Docker** (CI environments, Ubuntu): Uses the Docker socket at `/var/run/docker.sock`

The script automatically selects the correct socket path based on what's available.

## Testing the Setup

### 1. Check Runner Status

```bash
# View runner logs
docker logs -f gitea-actions-runner

# Check if runner is registered in Gitea
# Visit: http://localhost:8080/admin/actions/runners
```

### 2. Trigger Test Workflow

1. Visit the test repository: `http://localhost:8080/gitea_admin/actions-test`
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

1. **Check Gitea accessibility**:

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

### Load Balancing / Rootless Kind

If you're running Kind with rootless Podman, port mappings and ingress may not work out of the box. This can cause Gitea to be unreachable at `http://localhost:8080` even though the cluster is running. See the [Kind rootless guide](https://kind.sigs.k8s.io/docs/user/rootless/) for the required cgroup delegation, socket, and networking setup.

### Common Issues

| Issue                    | Solution                                                                                                     |
| ------------------------ | ------------------------------------------------------------------------------------------------------------ |
| "Runner not found"       | Re-register with new token                                                                                   |
| Docker permission denied | Use privileged mode                                                                                          |
| Network timeout          | Verify Kind cluster and ingress are running                                                                  |
| SSL certificate error    | Check `GITEA_SSL_SECURE_MODE` in gitea-config.sh                                                            |
| Port 8080 not reachable  | With rootless Podman, see [Kind rootless guide](https://kind.sigs.k8s.io/docs/user/rootless/) for networking |

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

To tear down the entire POC environment (cluster, runner, and all resources):

```bash
./scripts/cleanup-poc.sh
```

To stop and remove only the runner:

```bash
# Stop runner
docker stop gitea-actions-runner

# Remove container
docker rm gitea-actions-runner

# Remove data volume (optional)
docker volume rm gitea-runner-data
```

