#!/usr/bin/env python3

import unittest
import yaml
import jsonschema
from jsonschema import validate

class TestBackstageFormat(unittest.TestCase):
    
    def setUp(self):
        """Set up Backstage Group schema for validation"""
        # Backstage Group schema based on official spec
        self.backstage_group_schema = {
            "type": "object",
            "required": ["apiVersion", "kind", "metadata", "spec"],
            "properties": {
                "apiVersion": {
                    "type": "string",
                    "enum": ["backstage.io/v1alpha1"]
                },
                "kind": {
                    "type": "string",
                    "enum": ["Group"]
                },
                "metadata": {
                    "type": "object",
                    "required": ["name"],
                    "properties": {
                        "name": {
                            "type": "string",
                            "pattern": "^[a-zA-Z0-9_-]+$"
                        },
                        "description": {
                            "type": "string"
                        },
                        "annotations": {
                            "type": "object"
                        },
                        "labels": {
                            "type": "object"
                        }
                    }
                },
                "spec": {
                    "type": "object",
                    "required": ["type"],
                    "properties": {
                        "type": {
                            "type": "string",
                            "enum": ["team", "business-unit", "product-area", "department"]
                        },
                        "displayName": {
                            "type": "string"
                        },
                        "description": {
                            "type": "string"
                        },
                        "parent": {
                            "type": "string"
                        },
                        "children": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            }
                        },
                        "members": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            }
                        }
                    }
                }
            }
        }
        
        # Load expected output from fixtures
        fixture_path = "/home/james/src/orchestrator-poc/tests/unit/fixtures/expected_backstage_output.yaml"
        with open(fixture_path, 'r') as f:
            self.expected_output = yaml.safe_load(f)
    
    def test_expected_output_valid_backstage_format(self):
        """Test that our expected output is valid Backstage Group format"""
        try:
            validate(instance=self.expected_output, schema=self.backstage_group_schema)
        except jsonschema.ValidationError as e:
            self.fail(f"Expected output is not valid Backstage format: {e}")
    
    def test_required_fields_present(self):
        """Test that all required Backstage fields are present"""
        self.assertIn('apiVersion', self.expected_output)
        self.assertIn('kind', self.expected_output)
        self.assertIn('metadata', self.expected_output)
        self.assertIn('spec', self.expected_output)
        
        # Check metadata requirements
        self.assertIn('name', self.expected_output['metadata'])
        
        # Check spec requirements
        self.assertIn('type', self.expected_output['spec'])
    
    def test_api_version_correct(self):
        """Test that apiVersion is correct for Backstage"""
        self.assertEqual(
            self.expected_output['apiVersion'], 
            'backstage.io/v1alpha1'
        )
    
    def test_kind_is_group(self):
        """Test that kind is Group for team entities"""
        self.assertEqual(self.expected_output['kind'], 'Group')
    
    def test_spec_type_is_team(self):
        """Test that spec.type is 'team' for team groups"""
        self.assertEqual(self.expected_output['spec']['type'], 'team')
    
    def test_name_format_valid(self):
        """Test that the name follows Backstage naming conventions"""
        name = self.expected_output['metadata']['name']
        
        # Should be lowercase with hyphens/underscores
        self.assertRegex(name, r'^[a-zA-Z0-9_-]+$')
        
        # Should not contain spaces
        self.assertNotIn(' ', name)
    
    def test_display_name_human_readable(self):
        """Test that displayName is human-readable"""
        if 'displayName' in self.expected_output['spec']:
            display_name = self.expected_output['spec']['displayName']
            
            # Should not be empty
            self.assertTrue(len(display_name) > 0)
            
            # Can contain spaces and be human-readable
            self.assertIsInstance(display_name, str)
    
    def test_children_array_format(self):
        """Test that children field is properly formatted array"""
        if 'children' in self.expected_output['spec']:
            children = self.expected_output['spec']['children']
            self.assertIsInstance(children, list)
    
    def test_missing_required_fields_validation(self):
        """Test that Backstage format validation catches missing required fields"""
        # Test missing apiVersion
        invalid_output = self.expected_output.copy()
        del invalid_output['apiVersion']
        
        with self.assertRaises(jsonschema.ValidationError):
            validate(instance=invalid_output, schema=self.backstage_group_schema)
        
        # Test missing kind
        invalid_output = self.expected_output.copy()
        del invalid_output['kind']
        
        with self.assertRaises(jsonschema.ValidationError):
            validate(instance=invalid_output, schema=self.backstage_group_schema)
    
    def test_invalid_api_version(self):
        """Test that invalid apiVersion is rejected"""
        invalid_output = self.expected_output.copy()
        invalid_output['apiVersion'] = 'invalid.io/v1alpha1'
        
        with self.assertRaises(jsonschema.ValidationError):
            validate(instance=invalid_output, schema=self.backstage_group_schema)
    
    def test_invalid_group_type(self):
        """Test that invalid group type is rejected"""
        invalid_output = self.expected_output.copy()
        invalid_output['spec']['type'] = 'invalid-type'
        
        with self.assertRaises(jsonschema.ValidationError):
            validate(instance=invalid_output, schema=self.backstage_group_schema)

if __name__ == '__main__':
    unittest.main()