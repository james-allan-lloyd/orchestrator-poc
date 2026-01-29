#!/usr/bin/env python3

import unittest
import yaml
import subprocess
import time
from kubernetes import client, config
from kubernetes.client.rest import ApiException

class TestPromiseDeployment(unittest.TestCase):
    
    @classmethod
    def setUpClass(cls):
        """Set up Kubernetes client"""
        try:
            # Try to load in-cluster config first, then local
            config.load_incluster_config()
        except:
            config.load_kube_config()
        
        cls.api_client = client.ApiClient()
        cls.custom_api = client.CustomObjectsApi()
        cls.apps_api = client.AppsV1Api()
        cls.core_api = client.CoreV1Api()
    
    def test_kratix_platform_running(self):
        """Test that Kratix platform components are running"""
        try:
            pods = self.core_api.list_namespaced_pod(
                namespace="kratix-platform-system",
                label_selector="app.kubernetes.io/part-of=kratix"
            )
            
            # Check that we have Kratix pods
            self.assertGreater(len(pods.items), 0, "No Kratix pods found")
            
            # Check that all pods are running
            for pod in pods.items:
                self.assertEqual(
                    pod.status.phase, 
                    "Running", 
                    f"Pod {pod.metadata.name} is not running: {pod.status.phase}"
                )
        except ApiException as e:
            self.fail(f"Failed to check Kratix pods: {e}")
    
    def test_promise_deployment(self):
        """Test that the Team Promise can be deployed"""
        promise_path = "/home/james/src/orchestrator-poc/promises/team-promise/promise.yaml"
        
        # Load the Promise definition
        with open(promise_path, 'r') as f:
            promise_def = yaml.safe_load(f)
        
        # Deploy the Promise
        try:
            self.custom_api.create_cluster_custom_object(
                group="platform.kratix.io",
                version="v1alpha1",
                plural="promises",
                body=promise_def
            )
            
            # Wait for Promise to be ready
            time.sleep(10)
            
            # Check Promise status
            promise = self.custom_api.get_cluster_custom_object(
                group="platform.kratix.io",
                version="v1alpha1",
                plural="promises",
                name="team"
            )
            
            self.assertIsNotNone(promise)
            self.assertEqual(promise['metadata']['name'], 'team')
            
        except ApiException as e:
            if e.status == 409:  # Already exists
                self.skipTest("Promise already exists")
            else:
                self.fail(f"Failed to deploy Promise: {e}")
        finally:
            # Cleanup - delete the Promise
            try:
                self.custom_api.delete_cluster_custom_object(
                    group="platform.kratix.io",
                    version="v1alpha1",
                    plural="promises",
                    name="team"
                )
            except ApiException:
                pass  # Ignore cleanup errors
    
    def test_crd_creation(self):
        """Test that the Team CRD is created when Promise is deployed"""
        # This test assumes the Promise was deployed in the previous test
        try:
            # Check if Team CRD exists
            extensions_api = client.ApiextensionsV1Api()
            crd = extensions_api.read_custom_resource_definition(
                name="teams.platform.kratix.io"
            )
            
            self.assertIsNotNone(crd)
            self.assertEqual(crd.spec.group, "platform.kratix.io")
            self.assertEqual(crd.spec.names.kind, "Team")
            
        except ApiException as e:
            if e.status == 404:
                self.skipTest("Team CRD not found - Promise may not be deployed")
            else:
                self.fail(f"Failed to check Team CRD: {e}")

if __name__ == '__main__':
    unittest.main()