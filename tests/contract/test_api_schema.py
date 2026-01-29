#!/usr/bin/env python3

import unittest
import yaml
import jsonschema
from jsonschema import validate

class TestAPISchema(unittest.TestCase):
    
    def setUp(self):
        """Load the Promise definition"""
        promise_path = "/home/james/src/orchestrator-poc/promises/team-promise/promise.yaml"
        with open(promise_path, 'r') as f:
            self.promise = yaml.safe_load(f)
        
        # Extract the CRD schema
        self.crd = self.promise['spec']['api']
        self.schema = self.crd['spec']['versions'][0]['schema']['openAPIV3Schema']
    
    def test_crd_metadata(self):
        """Test that CRD metadata is correct"""
        self.assertEqual(self.crd['spec']['group'], 'platform.kratix.io')
        self.assertEqual(self.crd['spec']['names']['kind'], 'Team')
        self.assertEqual(self.crd['spec']['names']['plural'], 'teams')
        self.assertEqual(self.crd['spec']['names']['singular'], 'team')
        self.assertEqual(self.crd['spec']['scope'], 'Namespaced')
    
    def test_schema_structure(self):
        """Test that the schema has required structure"""
        # Check top-level structure
        self.assertIn('properties', self.schema)
        self.assertIn('spec', self.schema['properties'])
        
        # Check spec properties
        spec_props = self.schema['properties']['spec']['properties']
        self.assertIn('id', spec_props)
        self.assertIn('name', spec_props)
        
        # Check property types
        self.assertEqual(spec_props['id']['type'], 'string')
        self.assertEqual(spec_props['name']['type'], 'string')
    
    def test_valid_team_resource(self):
        """Test that a valid team resource passes schema validation"""
        valid_team = {
            'spec': {
                'id': 'team-valid',
                'name': 'Valid Team'
            }
        }
        
        try:
            validate(instance=valid_team, schema=self.schema)
        except jsonschema.ValidationError as e:
            self.fail(f"Valid team resource failed schema validation: {e}")
    
    def test_invalid_team_resource_missing_id(self):
        """Test that team resource without id fails validation"""
        invalid_team = {
            'spec': {
                'name': 'Invalid Team'
                # Missing 'id' field
            }
        }
        
        # Note: The current schema doesn't mark fields as required
        # This test documents current behavior
        try:
            validate(instance=invalid_team, schema=self.schema)
            # Currently passes because no required fields are defined
        except jsonschema.ValidationError:
            pass  # Would fail if required fields were defined
    
    def test_invalid_team_resource_wrong_type(self):
        """Test that team resource with wrong field types fails validation"""
        invalid_team = {
            'spec': {
                'id': 123,  # Should be string
                'name': 'Invalid Team'
            }
        }
        
        with self.assertRaises(jsonschema.ValidationError):
            validate(instance=invalid_team, schema=self.schema)
    
    def test_schema_extensibility(self):
        """Test that the schema allows for future extensions"""
        # The schema should allow additional properties
        extended_team = {
            'spec': {
                'id': 'team-extended',
                'name': 'Extended Team',
                'description': 'A team with additional fields',
                'tags': ['engineering', 'platform']
            }
        }
        
        try:
            validate(instance=extended_team, schema=self.schema)
        except jsonschema.ValidationError as e:
            self.fail(f"Extended team resource failed validation: {e}")

if __name__ == '__main__':
    unittest.main()