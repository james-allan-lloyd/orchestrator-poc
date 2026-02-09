"""Integration tests for Kratix platform and Team Promise deployment.

These tests verify that:
- Kratix platform components are running
- The Team Promise is deployed and available
- The Team CRD is created correctly

Prerequisites: A running Kind cluster with Kratix installed and the Team Promise
deployed (run ./scripts/run-integration-tests.sh which handles this).
"""

import pytest
from kubernetes.client.rest import ApiException


class TestKratixPlatform:
  """Tests for Kratix platform health."""

  def test_kratix_pods_running(self, k8s_clients):
    """Kratix platform pods should be running."""
    pods = k8s_clients["core"].list_namespaced_pod(
      namespace="kratix-platform-system",
    )

    running = [p for p in pods.items if p.status.phase == "Running"]
    assert len(running) > 0, "No running Kratix pods found"

  def test_kratix_controller_ready(self, k8s_clients):
    """Kratix controller manager deployment should be available."""
    deploy = k8s_clients["apps"].read_namespaced_deployment(
      name="kratix-platform-controller-manager",
      namespace="kratix-platform-system",
    )

    available = deploy.status.available_replicas or 0
    assert available >= 1, (
      f"Controller manager not available: "
      f"{available}/{deploy.spec.replicas} replicas"
    )


class TestTeamPromise:
  """Tests for Team Promise deployment."""

  def test_promise_exists(self, k8s_clients):
    """Team Promise should be deployed."""
    promise = k8s_clients["custom"].get_cluster_custom_object(
      group="platform.kratix.io",
      version="v1alpha1",
      plural="promises",
      name="team",
    )

    assert promise["metadata"]["name"] == "team"

  def test_promise_available(self, k8s_clients):
    """Team Promise should have Available status."""
    promise = k8s_clients["custom"].get_cluster_custom_object(
      group="platform.kratix.io",
      version="v1alpha1",
      plural="promises",
      name="team",
    )

    status = promise.get("status", {})
    conditions = status.get("conditions", [])
    available = [
      c for c in conditions
      if c.get("type") == "Available" and c.get("status") == "True"
    ]
    assert len(available) > 0, (
      f"Promise not Available. Conditions: {conditions}"
    )

  def test_team_crd_exists(self, k8s_clients):
    """Team CRD should be created by the Promise."""
    crd = k8s_clients["extensions"].read_custom_resource_definition(
      name="teams.platform.kratix.io",
    )

    assert crd.spec.group == "platform.kratix.io"
    assert crd.spec.names.kind == "Team"
    assert crd.spec.names.plural == "teams"

  def test_team_crd_has_expected_fields(self, k8s_clients):
    """Team CRD should have id, name, and email fields."""
    crd = k8s_clients["extensions"].read_custom_resource_definition(
      name="teams.platform.kratix.io",
    )

    version = crd.spec.versions[0]
    properties = (
      version.schema.open_apiv3_schema
      .properties["spec"]
      .properties
    )

    assert "id" in properties, "CRD missing 'id' field"
    assert "name" in properties, "CRD missing 'name' field"
    assert "email" in properties, "CRD missing 'email' field"
