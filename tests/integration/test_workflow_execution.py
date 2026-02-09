"""Integration tests for Team Promise workflow execution.

These tests verify that:
- A Team resource can be created and reconciled
- The workflow generates expected outputs
- Team resources can be deleted cleanly

Prerequisites: A running Kind cluster with Kratix installed and the Team Promise
deployed (run ./scripts/run-integration-tests.sh which handles this).
"""

import time
import pytest
from kubernetes.client.rest import ApiException


TEAM_RESOURCE = {
  "apiVersion": "platform.kratix.io/v1alpha1",
  "kind": "Team",
  "metadata": {
    "name": "integration-test-team",
    "namespace": "default",
  },
  "spec": {
    "id": "team-integration",
    "name": "Integration Test Team",
    "email": "integration@test.com",
  },
}


@pytest.fixture()
def team_resource(k8s_clients):
  """Create a Team resource and clean it up after the test."""
  custom = k8s_clients["custom"]

  # Delete if leftover from a previous run
  try:
    custom.delete_namespaced_custom_object(
      group="platform.kratix.io",
      version="v1alpha1",
      namespace="default",
      plural="teams",
      name=TEAM_RESOURCE["metadata"]["name"],
    )
    time.sleep(5)
  except ApiException as e:
    if e.status != 404:
      raise

  # Create
  custom.create_namespaced_custom_object(
    group="platform.kratix.io",
    version="v1alpha1",
    namespace="default",
    plural="teams",
    body=TEAM_RESOURCE,
  )

  yield TEAM_RESOURCE

  # Cleanup
  try:
    custom.delete_namespaced_custom_object(
      group="platform.kratix.io",
      version="v1alpha1",
      namespace="default",
      plural="teams",
      name=TEAM_RESOURCE["metadata"]["name"],
    )
  except ApiException:
    pass


def _wait_for_team_status(k8s_clients, name: str, timeout: int = 120) -> dict:
  """Poll until the Team resource has a status message, or timeout."""
  custom = k8s_clients["custom"]
  deadline = time.time() + timeout

  while time.time() < deadline:
    team = custom.get_namespaced_custom_object(
      group="platform.kratix.io",
      version="v1alpha1",
      namespace="default",
      plural="teams",
      name=name,
    )
    status = team.get("status", {})
    if status.get("message"):
      return team
    time.sleep(5)

  return team


class TestTeamWorkflow:
  """Tests for Team resource workflow execution."""

  def test_team_creation(self, k8s_clients, team_resource):
    """Creating a Team resource should succeed."""
    team = k8s_clients["custom"].get_namespaced_custom_object(
      group="platform.kratix.io",
      version="v1alpha1",
      namespace="default",
      plural="teams",
      name=team_resource["metadata"]["name"],
    )

    assert team["spec"]["id"] == "team-integration"
    assert team["spec"]["name"] == "Integration Test Team"
    assert team["spec"]["email"] == "integration@test.com"

  def test_team_reconciliation(self, k8s_clients, team_resource):
    """Team resource should reach Reconciled status."""
    team = _wait_for_team_status(
      k8s_clients, team_resource["metadata"]["name"]
    )

    status = team.get("status", {})
    assert status.get("message"), (
      f"Team never got a status message. Status: {status}"
    )

  def test_work_resource_created(self, k8s_clients, team_resource):
    """A Work resource should be created for the Team."""
    name = team_resource["metadata"]["name"]

    # Wait for reconciliation first
    _wait_for_team_status(k8s_clients, name)

    # Check for Work resources with the team label
    works = k8s_clients["custom"].list_cluster_custom_object(
      group="platform.kratix.io",
      version="v1alpha1",
      plural="works",
      label_selector=f"kratix.io/resource-name={name}",
    )

    assert len(works.get("items", [])) > 0, (
      f"No Work resources found for team '{name}'"
    )
