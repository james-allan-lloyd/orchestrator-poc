# Team Promise Tutorial

This tutorial demonstrates how to use the Team Promise to create team resources and generate Backstage catalog entries.

## Prerequisites

- Kind cluster with Kratix installed (see [README Setup section](../README.md#getting-started))
- Docker or Podman for building container images
- `kubectl` configured to access the cluster
- Go installed (for Kratix CLI)
- Python virtual environment for testing (see [README Development section](../README.md#development))

### Quick Start

For a fully working environment with Gitea, SSH, and Actions already configured, run the automated build first:

```bash
./scripts/build-poc.sh
```

This runs stages 1-5 and sets up everything you need. You can then skip ahead to [Using the Team Promise](#using-the-team-promise) below.

## Setup Instructions

### 1. Install Kratix CLI

If not already installed:

```bash
go install github.com/syntasso/kratix-cli/cmd/kratix@latest
```

### 2. Build the Team Promise Container

Build the container image with the Python configure script:

```bash
cd promises/team-promise/workflows/resource/configure/team-configure/python
docker build -t localhost/team-configure:latest .
```

### 3. Load Container into Kind Cluster

Load the built image into your Kind cluster:

```bash
kind load docker-image localhost/team-configure:latest --name kratix-poc
```

### 4. Deploy the Team Promise

Apply the Promise definition to your cluster:

```bash
kubectl apply -f promises/team-promise/promise.yaml
```

Verify the Promise is available:

```bash
kubectl get promises
```

Expected output:

```
NAME   STATUS      KIND   API VERSION                   VERSION
team   Available   Team   platform.kratix.io/v1alpha1   v0.0.1
```

## Using the Team Promise

### Step 1: Verify Setup

Check that Kratix is running and the Team Promise is deployed:

```bash
# Check Kratix platform status
kubectl get pods -n kratix-platform-system

# Verify Team Promise is available
kubectl get promises

# Check that the Team CRD is installed
kubectl get crd teams.platform.kratix.io
```

## Step 2: Create a Team Resource

Create a team resource by applying the following YAML:

```bash
# Create a simple team resource
cat << EOF | kubectl apply -f -
apiVersion: platform.kratix.io/v1alpha1
kind: Team
metadata:
  name: my-team
  namespace: default
spec:
  id: team-alpha
  name: Team Alpha
EOF
```

## Step 3: Monitor Team Processing

Check the status of your team resource:

```bash
# Check team status
kubectl get teams

# Get detailed information about the team
kubectl get team my-team -o yaml
```

The team should show status "Reconciled" when processing is complete:

```
NAME      MESSAGE              STATUS
my-team   Resource requested   Reconciled
```

## Step 4: View the Generated Work Resource

Kratix creates a Work resource containing the generated Backstage YAML:

```bash
# List all Work resources
kubectl get works

# Get details of the team-related work
kubectl get work -l kratix.io/resource-name=my-team -o yaml
```

## Step 5: Extract the Generated Backstage YAML

Decode the generated Backstage catalog entry:

```bash
# Get the work resource name (replace with actual name from previous command)
WORK_NAME=$(kubectl get work -l kratix.io/resource-name=my-team -o jsonpath='{.items[0].metadata.name}')

# Decode and view the generated Backstage YAML
kubectl get work $WORK_NAME -o jsonpath='{.spec.workloadGroups[0].workloads[0].content}' | base64 -d | gunzip
```

Expected output:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  description: Team Team Alpha
  name: team-alpha
spec:
  children: []
  displayName: Team Alpha
  type: team
```

## Step 6: Clean Up (Optional)

Remove the team resource when done:

```bash
kubectl delete team my-team
```

## Troubleshooting

### Team Status is "Pending"

If your team remains in "Pending" status:

```bash
# Check for workflow pods
kubectl get pods -A | grep team

# Check Promise container logs (replace pod name)
kubectl logs <team-workflow-pod> -c python

# Check for errors in the workflow
kubectl describe team my-team
```

### No Work Resources Created

If no Work resources appear:

```bash
# Check if Promise is correctly deployed
kubectl get promise team -o yaml

# Look for any failed jobs
kubectl get jobs | grep team

# Check Kratix controller logs
kubectl logs -n kratix-platform-system deployment/kratix-platform-controller-manager
```

### Container Image Issues

If you see ImagePullBackOff errors:

```bash
# Check the Promise configuration
kubectl get promise team -o jsonpath='{.spec.workflows.resource.configure[0].spec.containers[0].image}'

# Ensure the image is loaded in Kind
docker exec -it kratix-poc-control-plane crictl images | grep team-configure

# Rebuild and reload if necessary
docker build -t localhost/team-configure:latest .
kind load docker-image localhost/team-configure:latest --name kratix-poc
```

### Workflow Execution Errors

If the workflow fails:

```bash
# Get workflow pod name
POD_NAME=$(kubectl get pods -A | grep team | grep -v Running | awk '{print $2}')

# Check all container logs in the workflow pod
kubectl logs $POD_NAME -c python
kubectl logs $POD_NAME -c reader
kubectl logs $POD_NAME -c work-writer

# Check pod events
kubectl describe pod $POD_NAME
```

### General Debugging Commands

```bash
# Check all Kratix-related resources
kubectl get all -A | grep kratix

# View Promise details
kubectl describe promise team

# Check CRD installation
kubectl get crd teams.platform.kratix.io

# View all teams across namespaces
kubectl get teams -A

# Check for any stuck resources
kubectl get teams,works,jobs | grep team
```

## Understanding the Generated Output

The Team Promise generates a Backstage Group definition with:

- **apiVersion**: `backstage.io/v1alpha1` - Standard Backstage format
- **kind**: `Group` - Backstage entity type for teams
- **metadata.name**: Uses the team `id` from the request
- **metadata.description**: Auto-generated description
- **spec.type**: Always set to `team`
- **spec.displayName**: Uses the human-readable `name` from the request
- **spec.children**: Empty array, ready for sub-teams

This YAML can be committed to a Backstage catalog repository to register the team in your developer portal.

## Next Steps

1. **Integrate with GitOps**: Configure Kratix destinations to automatically commit generated YAML to your Backstage catalog repository
2. **Extend the Promise**: Add more team properties like contact information, tags, or parent/child relationships
3. **Add Validation**: Enhance the CRD schema with validation rules for team IDs and names
4. **Multiple Outputs**: Generate additional resources like namespaces, RBAC, or monitoring configurations alongside the Backstage entry

