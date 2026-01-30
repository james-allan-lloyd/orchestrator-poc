#!/usr/bin/env python3

import yaml
from typing import Dict, Any
import kratix_sdk as ks


def main() -> None:
  # Read the team resource from Kratix input
  sdk = ks.KratixSDK()
  team_resource = sdk.read_resource_input()

  # Extract team properties using get_value
  team_name: str = team_resource.get_value("metadata.name")
  team_id: str = team_resource.get_value("spec.id")
  team_display_name: str = team_resource.get_value("spec.name")
  
  # Get email with default constructed from team_id
  default_email: str = f"{team_id}@example.com"
  team_email: str = team_resource.get_value("spec.email", default=default_email)
  
  print(f"Configuring team: {team_display_name} (ID: {team_id}, Email: {team_email})")

  # Create Backstage team definition
  backstage_team: Dict[str, Any] = {
    "apiVersion": "backstage.io/v1alpha1",
    "kind": "Group",
    "metadata": {
      "name": team_id, 
      "description": f"Team {team_display_name}",
      "annotations": {
        "contact.email": team_email
      }
    },
    "spec": {"type": "team", "displayName": team_display_name, "children": []},
  }

  # Write Backstage team definition to output
  yaml_content: str = yaml.dump(backstage_team, default_flow_style=False)
  sdk.write_output(f"backstage-team-{team_id}.yaml", yaml_content.encode("utf-8"))

  print(f"Generated Backstage team definition for {team_display_name}")


if __name__ == "__main__":
  main()

