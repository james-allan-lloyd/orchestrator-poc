#!/usr/bin/env python3

import yaml
import os
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

  # Generate Terraform files for organization creation
  try:
    generate_terraform_files(sdk, team_id, team_display_name, team_email)
    print(f"Successfully generated Terraform files for {team_display_name}")
  except Exception as e:
    print(f"ERROR generating Terraform files: {e}")
    import traceback
    traceback.print_exc()


def generate_terraform_files(sdk: ks.KratixSDK, team_id: str, team_name: str, team_email: str) -> None:
  """Generate Terraform files for creating Gitea organization"""
  
  # Get the directory of the current script for template location
  script_dir: str = os.path.dirname(os.path.abspath(__file__))
  template_dir: str = os.path.join(script_dir, "terraform_templates")
  
  # Read organization Terraform template
  org_template_path: str = os.path.join(template_dir, "organization.tf.template")
  with open(org_template_path, "r") as f:
    org_template: str = f.read()
  
  # Replace template variables with actual values
  org_content: str = org_template.replace("{{team_id}}", team_id).replace("{{team_name}}", team_name).replace("{{team_email}}", team_email)
  
  # Write team-specific organization Terraform file
  # Note: provider.tf and variables.tf live in the template kratix repo
  # and are NOT written here, so they survive team resource deletion.
  sdk.write_output(f"terraform/org-{team_id}.tf", org_content.encode("utf-8"))

  print(f"Generated Terraform files for organization: {team_id}")


if __name__ == "__main__":
  main()

