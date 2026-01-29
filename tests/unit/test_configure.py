#!/usr/bin/env python3

import os
import yaml
import pytest
import kratix_sdk as ks


@pytest.fixture
def test_data():
    """Load test fixtures"""
    test_dir = os.path.dirname(__file__)
    fixtures_dir = os.path.join(test_dir, "fixtures")

    # Load test data
    with open(os.path.join(fixtures_dir, "team_resource.yaml"), "r") as f:
        team_resource = yaml.safe_load(f)

    with open(os.path.join(fixtures_dir, "expected_backstage_output.yaml"), "r") as f:
        expected_output = yaml.safe_load(f)

    return {"team_resource": team_resource, "expected_output": expected_output}


def test_configure_generates_backstage_team(test_data, tmp_path, capsys):
    """Test that configure script generates correct Backstage team definition"""

    # Set up temporary directories
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    metadata_dir = tmp_path / "metadata"

    input_dir.mkdir()
    output_dir.mkdir()
    metadata_dir.mkdir()

    # Write test team resource to input file
    input_file = input_dir / "object.yaml"
    with open(input_file, "w") as f:
        yaml.dump(test_data["team_resource"], f)

    # Set Kratix SDK directories to use our test directories
    ks.set_input_dir(str(input_dir))
    ks.set_output_dir(str(output_dir))
    ks.set_metadata_dir(str(metadata_dir))

    # Import and run the configure script
    import configure

    configure.main()

    # Check that output file was created
    output_files = list(output_dir.glob("backstage-team-*.yaml"))
    assert len(output_files) == 1

    output_file = output_files[0]

    # Verify filename format
    assert output_file.name == "backstage-team-team-test.yaml"

    # Verify the output content
    with open(output_file, "r") as f:
        output_data = yaml.safe_load(f)

    assert output_data["apiVersion"] == "backstage.io/v1alpha1"
    assert output_data["kind"] == "Group"
    assert output_data["metadata"]["name"] == "team-test"
    assert output_data["spec"]["displayName"] == "Test Team"
    assert output_data["spec"]["type"] == "team"

    # Verify print output
    captured = capsys.readouterr()
    assert "Configuring team: Test Team (ID: team-test)" in captured.out


def test_backstage_format_validation(test_data):
    """Test that the expected output format is valid Backstage format"""
    expected_output = test_data["expected_output"]

    # Validate required fields exist
    assert "apiVersion" in expected_output
    assert "kind" in expected_output
    assert "metadata" in expected_output
    assert "spec" in expected_output

    # Validate specific values
    assert expected_output["apiVersion"] == "backstage.io/v1alpha1"
    assert expected_output["kind"] == "Group"
    assert expected_output["spec"]["type"] == "team"
