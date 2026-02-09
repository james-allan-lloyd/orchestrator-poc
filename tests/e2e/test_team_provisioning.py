"""End-to-end tests for Team Promise lifecycle.

These tests go beyond integration tests by verifying the full lifecycle as an
ordered sequence: create -> reconcile -> verify Work outputs -> update ->
verify update -> delete -> verify cleanup.

Prerequisites: A running Kind cluster with Kratix installed and the Team Promise
deployed (run ./scripts/run-e2e-tests.sh which handles this).
"""

import base64
import gzip
import time
from typing import Any

import pytest
import yaml
from kubernetes.client.rest import ApiException


KRATIX_GROUP = "platform.kratix.io"
KRATIX_VERSION = "v1alpha1"


# -- helpers ------------------------------------------------------------------

def _wait_for_work(
  k8s_clients: dict[str, Any],
  team_name: str,
  timeout: int = 120,
  previous_resource_version: str | None = None,
) -> dict[str, Any]:
  """Poll until a Work resource exists for the given team, or timeout.

  If *previous_resource_version* is given, keep polling until the Work's
  resourceVersion differs (i.e. the controller has re-reconciled).
  """
  custom = k8s_clients["custom"]
  deadline = time.time() + timeout

  while time.time() < deadline:
    works = custom.list_cluster_custom_object(
      group=KRATIX_GROUP,
      version=KRATIX_VERSION,
      plural="works",
      label_selector=f"kratix.io/resource-name={team_name}",
    )
    items = works.get("items", [])
    if items:
      work = items[0]
      rv = work.get("metadata", {}).get("resourceVersion")
      if previous_resource_version is None or rv != previous_resource_version:
        return work
    time.sleep(5)

  if previous_resource_version is not None:
    pytest.fail(
      f"Work for team '{team_name}' was not updated within {timeout}s"
    )
  pytest.fail(f"No Work resource found for team '{team_name}' within {timeout}s")


def _wait_for_work_gone(
  k8s_clients: dict[str, Any],
  team_name: str,
  timeout: int = 120,
) -> None:
  """Poll until no Work resources exist for the given team."""
  custom = k8s_clients["custom"]
  deadline = time.time() + timeout

  while time.time() < deadline:
    works = custom.list_cluster_custom_object(
      group=KRATIX_GROUP,
      version=KRATIX_VERSION,
      plural="works",
      label_selector=f"kratix.io/resource-name={team_name}",
    )
    if not works.get("items"):
      return
    time.sleep(5)

  pytest.fail(f"Work resource for team '{team_name}' still exists after {timeout}s")


def _wait_for_status(
  k8s_clients: dict[str, Any],
  team_name: str,
  timeout: int = 120,
) -> dict[str, Any]:
  """Poll until the Team resource has a status message."""
  custom = k8s_clients["custom"]
  deadline = time.time() + timeout

  while time.time() < deadline:
    team = custom.get_namespaced_custom_object(
      group=KRATIX_GROUP,
      version=KRATIX_VERSION,
      namespace="default",
      plural="teams",
      name=team_name,
    )
    if team.get("status", {}).get("message"):
      return team
    time.sleep(5)

  return team


def _decode_workload(workload: dict[str, Any]) -> str:
  """Decode a Kratix workload content (base64 + gzip)."""
  raw = base64.b64decode(workload["content"])
  return gzip.decompress(raw).decode("utf-8")


def _extract_workloads(work: dict[str, Any]) -> dict[str, str]:
  """Return a {filepath: decoded_content} mapping from a Work resource."""
  result: dict[str, str] = {}
  for group in work.get("spec", {}).get("workloadGroups", []):
    for wl in group.get("workloads", []):
      result[wl["filepath"]] = _decode_workload(wl)
  return result


def _create_team(
  k8s_clients: dict[str, Any],
  name: str,
  spec: dict[str, Any],
) -> dict[str, Any]:
  """Create a Team custom resource and return the body."""
  body = {
    "apiVersion": f"{KRATIX_GROUP}/{KRATIX_VERSION}",
    "kind": "Team",
    "metadata": {"name": name, "namespace": "default"},
    "spec": spec,
  }
  k8s_clients["custom"].create_namespaced_custom_object(
    group=KRATIX_GROUP,
    version=KRATIX_VERSION,
    namespace="default",
    plural="teams",
    body=body,
  )
  return body


def _delete_team(k8s_clients: dict[str, Any], name: str) -> None:
  """Delete a Team custom resource, ignoring 404."""
  try:
    k8s_clients["custom"].delete_namespaced_custom_object(
      group=KRATIX_GROUP,
      version=KRATIX_VERSION,
      namespace="default",
      plural="teams",
      name=name,
    )
  except ApiException as e:
    if e.status != 404:
      raise


def _cleanup_team(k8s_clients: dict[str, Any], name: str) -> None:
  """Delete team and wait for its Work to disappear."""
  _delete_team(k8s_clients, name)
  try:
    _wait_for_work_gone(k8s_clients, name, timeout=60)
  except Exception:
    pass  # best-effort cleanup


# -- tests --------------------------------------------------------------------

@pytest.mark.e2e
class TestTeamLifecycle:
  """Full create -> verify -> update -> verify -> delete -> verify cycle."""

  TEAM_NAME = "e2e-lifecycle"
  TEAM_ID = "team-lifecycle"

  def test_team_lifecycle(self, k8s_clients):
    """Full lifecycle: create, verify outputs, update, verify, delete, verify."""
    # Ensure clean slate
    _cleanup_team(k8s_clients, self.TEAM_NAME)

    try:
      # -- Step 1: Create -------------------------------------------------
      _create_team(k8s_clients, self.TEAM_NAME, {
        "id": self.TEAM_ID,
        "name": "Lifecycle Team",
        "email": "lifecycle@test.com",
      })

      # -- Step 2: Wait for reconciliation --------------------------------
      _wait_for_status(k8s_clients, self.TEAM_NAME)

      # -- Step 3: Verify Work resource and decoded contents --------------
      work = _wait_for_work(k8s_clients, self.TEAM_NAME)
      files = _extract_workloads(work)

      # Backstage YAML
      backstage_path = f"backstage-team-{self.TEAM_ID}.yaml"
      assert backstage_path in files, (
        f"Missing {backstage_path} in Work. Files: {list(files.keys())}"
      )
      backstage = yaml.safe_load(files[backstage_path])
      assert backstage["kind"] == "Group"
      assert backstage["metadata"]["name"] == self.TEAM_ID
      assert backstage["spec"]["displayName"] == "Lifecycle Team"
      assert (
        backstage["metadata"]["annotations"]["contact.email"]
        == "lifecycle@test.com"
      )

      # Terraform file
      tf_path = f"terraform/org-{self.TEAM_ID}.tf"
      assert tf_path in files, (
        f"Missing {tf_path} in Work. Files: {list(files.keys())}"
      )
      tf_content = files[tf_path]
      assert self.TEAM_ID in tf_content
      assert "Lifecycle Team" in tf_content

      # -- Step 4: Update the team ----------------------------------------
      # Capture current Work resourceVersion so we can detect re-reconciliation
      work_rv = work.get("metadata", {}).get("resourceVersion")

      team = k8s_clients["custom"].get_namespaced_custom_object(
        group=KRATIX_GROUP,
        version=KRATIX_VERSION,
        namespace="default",
        plural="teams",
        name=self.TEAM_NAME,
      )
      team["spec"]["name"] = "Updated Lifecycle Team"
      team["spec"]["email"] = "updated@test.com"

      k8s_clients["custom"].replace_namespaced_custom_object(
        group=KRATIX_GROUP,
        version=KRATIX_VERSION,
        namespace="default",
        plural="teams",
        name=self.TEAM_NAME,
        body=team,
      )

      # -- Step 5: Wait for re-reconciliation -----------------------------
      _wait_for_status(k8s_clients, self.TEAM_NAME)

      # -- Step 6: Verify Work reflects the update ------------------------
      work = _wait_for_work(
        k8s_clients, self.TEAM_NAME,
        previous_resource_version=work_rv,
      )
      files = _extract_workloads(work)

      backstage = yaml.safe_load(files[backstage_path])
      assert backstage["spec"]["displayName"] == "Updated Lifecycle Team"
      assert (
        backstage["metadata"]["annotations"]["contact.email"]
        == "updated@test.com"
      )

      tf_content = files[tf_path]
      assert "Updated Lifecycle Team" in tf_content

      # -- Step 7: Delete the team ----------------------------------------
      _delete_team(k8s_clients, self.TEAM_NAME)

      # -- Step 8: Verify Work is cleaned up ------------------------------
      _wait_for_work_gone(k8s_clients, self.TEAM_NAME)

    finally:
      # Best-effort cleanup in case a step failed
      _cleanup_team(k8s_clients, self.TEAM_NAME)


@pytest.mark.e2e
class TestTeamEmailDefault:
  """Verify the default email behaviour when email is omitted."""

  TEAM_NAME = "e2e-email-default"
  TEAM_ID = "team-email-default"

  def test_team_with_email_default(self, k8s_clients):
    """Creating a team without email should use <id>@example.com."""
    _cleanup_team(k8s_clients, self.TEAM_NAME)

    try:
      _create_team(k8s_clients, self.TEAM_NAME, {
        "id": self.TEAM_ID,
        "name": "Email Default Team",
        # no email field
      })

      _wait_for_status(k8s_clients, self.TEAM_NAME)

      work = _wait_for_work(k8s_clients, self.TEAM_NAME)
      files = _extract_workloads(work)

      backstage_path = f"backstage-team-{self.TEAM_ID}.yaml"
      assert backstage_path in files

      backstage = yaml.safe_load(files[backstage_path])
      expected_email = f"{self.TEAM_ID}@example.com"
      assert (
        backstage["metadata"]["annotations"]["contact.email"]
        == expected_email
      ), (
        f"Expected default email '{expected_email}', "
        f"got '{backstage['metadata']['annotations']['contact.email']}'"
      )

    finally:
      _cleanup_team(k8s_clients, self.TEAM_NAME)
