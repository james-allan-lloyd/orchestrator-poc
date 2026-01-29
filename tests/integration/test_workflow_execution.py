#!/usr/bin/env python3

import unittest
import yaml
import time
import tempfile
import docker
from kubernetes import client, config
from kubernetes.client.rest import ApiException

class TestWorkflowExecution(unittest.TestCase):
    
    @classmethod
    def setUpClass(cls):
        """Set up Kubernetes and Docker clients"""
        try:
            config.load_incluster_config()
        except:
            config.load_kube_config()
        
        cls.custom_api = client.CustomObjectsApi()
        cls.core_api = client.CoreV1Api()
        cls.docker_client = docker.from_env()
    
    def test_container_build(self):
        """Test that the team-configure container can be built"""
        dockerfile_path = "/home/james/src/orchestrator-poc/promises/team-promise/workflows/resource/configure/team-configure/python"
        
        try:
            # Build the Docker image
            image, logs = self.docker_client.images.build(
                path=dockerfile_path,
                tag="team-configure:test",
                rm=True
            )
            
            self.assertIsNotNone(image)
            self.assertIn("team-configure:test", image.tags)
            
            # Cleanup
            self.docker_client.images.remove(image.id, force=True)
            
        except docker.errors.BuildError as e:
            self.fail(f"Failed to build container: {e}")
    
    def test_container_execution(self):
        """Test that the configure container executes successfully"""
        dockerfile_path = "/home/james/src/orchestrator-poc/promises/team-promise/workflows/resource/configure/team-configure/python"
        
        # Create test input
        test_team = {
            'apiVersion': 'platform.kratix.io/v1alpha1',
            'kind': 'Team',
            'metadata': {
                'name': 'test-team-workflow',
                'namespace': 'default'
            },
            'spec': {
                'id': 'team-workflow-test',
                'name': 'Workflow Test Team'
            }
        }
        
        try:
            # Build the image
            image, _ = self.docker_client.images.build(
                path=dockerfile_path,
                tag="team-configure:workflow-test",
                rm=True
            )
            
            # Create temporary input file
            with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
                yaml.dump(test_team, f)
                input_file = f.name
            
            # Create temporary output directory
            with tempfile.TemporaryDirectory() as output_dir:
                # Run the container
                container = self.docker_client.containers.run(
                    image="team-configure:workflow-test",
                    volumes={
                        input_file: {'bind': '/kratix/input/object.yaml', 'mode': 'ro'},
                        output_dir: {'bind': '/kratix/output', 'mode': 'rw'}
                    },
                    detach=True,
                    remove=True
                )
                
                # Wait for completion
                result = container.wait()
                logs = container.logs().decode('utf-8')
                
                # Check exit code
                self.assertEqual(result['StatusCode'], 0, f"Container failed with logs: {logs}")
                
                # Check output file was created
                import os
                output_files = os.listdir(output_dir)
                self.assertGreater(len(output_files), 0, "No output files generated")
                
                # Validate output content
                backstage_file = None
                for file in output_files:
                    if file.startswith('backstage-team-'):
                        backstage_file = os.path.join(output_dir, file)
                        break
                
                self.assertIsNotNone(backstage_file, "Backstage team file not found")
                
                with open(backstage_file, 'r') as f:
                    backstage_output = yaml.safe_load(f)
                
                # Validate Backstage format
                self.assertEqual(backstage_output['apiVersion'], 'backstage.io/v1alpha1')
                self.assertEqual(backstage_output['kind'], 'Group')
                self.assertEqual(backstage_output['metadata']['name'], 'team-workflow-test')
                self.assertEqual(backstage_output['spec']['displayName'], 'Workflow Test Team')
            
            # Cleanup
            self.docker_client.images.remove(image.id, force=True)
            os.unlink(input_file)
            
        except Exception as e:
            self.fail(f"Container execution test failed: {e}")

if __name__ == '__main__':
    unittest.main()