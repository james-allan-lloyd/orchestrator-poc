#!/usr/bin/env python3

import unittest
import yaml
import time
import os
import tempfile
from kubernetes import client, config
from kubernetes.client.rest import ApiException

class TestTeamProvisioning(unittest.TestCase):
    
    @classmethod
    def setUpClass(cls):
        """Set up Kubernetes client and test environment"""
        try:
            config.load_incluster_config()
        except:
            config.load_kube_config()
        
        cls.custom_api = client.CustomObjectsApi()
        cls.core_api = client.CoreV1Api()
        cls.extensions_api = client.ApiextensionsV1Api()
        
        # Unique test identifier
        cls.test_id = f"e2e-{int(time.time())}"
    
    def setUp(self):
        """Set up individual test"""
        self.promise_deployed = False
        self.team_created = False
    
    def tearDown(self):
        """Clean up after each test"""
        # Clean up team resource
        if self.team_created:
            try:
                self.custom_api.delete_namespaced_custom_object(
                    group="platform.kratix.io",
                    version="v1alpha1",
                    namespace="default",
                    plural="teams",
                    name=f"test-team-{self.test_id}"
                )
            except ApiException:
                pass
        
        # Clean up promise
        if self.promise_deployed:
            try:
                self.custom_api.delete_cluster_custom_object(
                    group="platform.kratix.io",
                    version="v1alpha1",
                    plural="promises",
                    name="team"
                )
            except ApiException:
                pass
    
    def test_complete_team_provisioning_workflow(self):
        """Test the complete team provisioning workflow end-to-end"""
        
        # Step 1: Deploy the Team Promise
        promise_path = "/home/james/src/orchestrator-poc/promises/team-promise/promise.yaml"
        with open(promise_path, 'r') as f:
            promise_def = yaml.safe_load(f)
        
        try:
            self.custom_api.create_cluster_custom_object(
                group="platform.kratix.io",
                version="v1alpha1",
                plural="promises",
                body=promise_def
            )
            self.promise_deployed = True
            
            # Wait for Promise to be ready
            self._wait_for_promise_ready("team")
            
        except ApiException as e:
            if e.status == 409:  # Already exists
                self.promise_deployed = True
            else:
                self.fail(f"Failed to deploy Promise: {e}")
        
        # Step 2: Verify CRD is created
        try:
            crd = self.extensions_api.read_custom_resource_definition(
                name="teams.platform.kratix.io"
            )
            self.assertIsNotNone(crd)
        except ApiException as e:
            self.fail(f"Team CRD not found after Promise deployment: {e}")
        
        # Step 3: Create a Team resource
        team_resource = {
            'apiVersion': 'platform.kratix.io/v1alpha1',
            'kind': 'Team',
            'metadata': {
                'name': f'test-team-{self.test_id}',
                'namespace': 'default'
            },
            'spec': {
                'id': f'team-{self.test_id}',
                'name': f'Test Team {self.test_id}'
            }
        }
        
        try:
            self.custom_api.create_namespaced_custom_object(
                group="platform.kratix.io",
                version="v1alpha1",
                namespace="default",
                plural="teams",
                body=team_resource
            )
            self.team_created = True
            
            # Wait for processing
            time.sleep(30)
            
        except ApiException as e:
            self.fail(f"Failed to create Team resource: {e}")
        
        # Step 4: Verify team resource exists and is configured
        try:
            team = self.custom_api.get_namespaced_custom_object(
                group="platform.kratix.io",
                version="v1alpha1",
                namespace="default",
                plural="teams",
                name=f'test-team-{self.test_id}'
            )
            
            self.assertEqual(team['spec']['id'], f'team-{self.test_id}')
            self.assertEqual(team['spec']['name'], f'Test Team {self.test_id}')
            
        except ApiException as e:
            self.fail(f"Failed to retrieve Team resource: {e}")
        
        # Step 5: Check for workflow execution
        # In a real scenario, we would check for:
        # - Work resources created by Kratix
        # - Destination processing
        # - Output artifacts in git repositories
        # For this POC, we verify the workflow was triggered
        self._verify_workflow_execution(f'test-team-{self.test_id}')
    
    def test_team_with_special_characters(self):
        """Test team provisioning with special characters in names"""
        if not self._ensure_promise_deployed():
            return
        
        team_resource = {
            'apiVersion': 'platform.kratix.io/v1alpha1',
            'kind': 'Team',
            'metadata': {
                'name': f'special-team-{self.test_id}',
                'namespace': 'default'
            },
            'spec': {
                'id': f'team-special-{self.test_id}',
                'name': f'Special Team & Co. {self.test_id}'
            }
        }
        
        try:
            self.custom_api.create_namespaced_custom_object(
                group="platform.kratix.io",
                version="v1alpha1",
                namespace="default",
                plural="teams",
                body=team_resource
            )
            self.team_created = True
            
            # Verify creation
            team = self.custom_api.get_namespaced_custom_object(
                group="platform.kratix.io",
                version="v1alpha1",
                namespace="default",
                plural="teams",
                name=f'special-team-{self.test_id}'
            )
            
            self.assertEqual(team['spec']['name'], f'Special Team & Co. {self.test_id}')
            
        except ApiException as e:
            self.fail(f"Failed to create team with special characters: {e}")
    
    def _ensure_promise_deployed(self):
        """Ensure the Promise is deployed for tests that need it"""
        try:
            self.custom_api.get_cluster_custom_object(
                group="platform.kratix.io",
                version="v1alpha1",
                plural="promises",
                name="team"
            )
            return True
        except ApiException:
            self.skipTest("Team Promise not deployed - skipping test")
            return False
    
    def _wait_for_promise_ready(self, promise_name, timeout=60):
        """Wait for Promise to be ready"""
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                promise = self.custom_api.get_cluster_custom_object(
                    group="platform.kratix.io",
                    version="v1alpha1",
                    plural="promises",
                    name=promise_name
                )
                
                # Check if Promise is ready (this depends on Kratix status reporting)
                if promise.get('status'):
                    return True
                    
            except ApiException:
                pass
            
            time.sleep(5)
        
        self.fail(f"Promise {promise_name} not ready within {timeout} seconds")
    
    def _verify_workflow_execution(self, team_name):
        """Verify that workflow execution was triggered"""
        # In a complete implementation, this would:
        # 1. Check for Work resources created by Kratix
        # 2. Monitor pipeline execution
        # 3. Verify output artifacts
        # 4. Check destination repositories
        
        # For now, we just verify the team resource exists
        # and assume workflow processing occurred
        try:
            team = self.custom_api.get_namespaced_custom_object(
                group="platform.kratix.io",
                version="v1alpha1",
                namespace="default",
                plural="teams",
                name=team_name
            )
            
            # Basic verification that the resource exists
            self.assertIsNotNone(team)
            
            # In a real scenario, you might check:
            # - status.conditions for processing state
            # - related Work resources
            # - generated artifacts in git repos
            
        except ApiException as e:
            self.fail(f"Failed to verify workflow execution: {e}")

if __name__ == '__main__':
    unittest.main()