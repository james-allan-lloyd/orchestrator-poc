#!/usr/bin/env python3

import json
import yaml
import os

def main():
    # Read the team resource from Kratix input
    with open('/kratix/input/object.yaml', 'r') as f:
        team_resource = yaml.safe_load(f)
    
    # Extract team properties
    team_name = team_resource['metadata']['name']
    team_id = team_resource['spec']['id']
    team_display_name = team_resource['spec']['name']
    
    print(f"Configuring team: {team_display_name} (ID: {team_id})")
    
    # Create Backstage team definition
    backstage_team = {
        'apiVersion': 'backstage.io/v1alpha1',
        'kind': 'Group',
        'metadata': {
            'name': team_id,
            'description': f"Team {team_display_name}"
        },
        'spec': {
            'type': 'team',
            'displayName': team_display_name,
            'children': []
        }
    }
    
    # Write Backstage team definition to output
    os.makedirs('/kratix/output', exist_ok=True)
    with open(f'/kratix/output/backstage-team-{team_id}.yaml', 'w') as f:
        yaml.dump(backstage_team, f, default_flow_style=False)
    
    print(f"Generated Backstage team definition for {team_display_name}")

if __name__ == "__main__":
    main()