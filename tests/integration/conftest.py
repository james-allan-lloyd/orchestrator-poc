import pytest
from kubernetes import client, config
from kubernetes.client.rest import ApiException


@pytest.fixture(scope="session")
def k8s_clients():
  """Initialize Kubernetes API clients."""
  try:
    config.load_incluster_config()
  except config.ConfigException:
    config.load_kube_config()

  return {
    "core": client.CoreV1Api(),
    "apps": client.AppsV1Api(),
    "custom": client.CustomObjectsApi(),
    "extensions": client.ApiextensionsV1Api(),
  }
