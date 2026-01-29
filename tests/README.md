# Testing the Team Promise

This directory contains comprehensive tests for the Kratix Team Promise, organized into multiple layers to ensure reliability and correctness.

## Test Structure

```
tests/
├── unit/                          # Unit tests for individual components
│   ├── test_configure.py         # Test Python configure script logic
│   └── fixtures/                 # Test data fixtures
├── integration/                   # Integration tests
│   ├── test_promise_deployment.py # Test Promise installation
│   ├── test_workflow_execution.py # Test end-to-end workflow
│   └── test_output_validation.py # Validate generated artifacts
├── contract/                      # Contract tests
│   ├── test_api_schema.py        # Validate CRD schema
│   └── test_backstage_format.py  # Validate Backstage output format
└── e2e/                          # End-to-end tests
    ├── test_team_provisioning.py # Full team creation workflow
    └── scenarios/                # Test scenarios
```

## Running Tests

### Prerequisites

Install test dependencies:
```bash
pip install -r tests/requirements.txt
```

### Unit Tests

Fast tests that don't require external dependencies:
```bash
cd tests
python -m pytest unit/ -v
```

### Contract Tests  

Validate API schemas and output formats:
```bash
cd tests
python -m pytest contract/ -v
```

### Integration Tests

Require a running Kubernetes cluster with Kratix installed:
```bash
cd tests
python -m pytest integration/ -v
```

### End-to-End Tests

Full workflow tests requiring Kratix and container runtime:
```bash
cd tests
python -m pytest e2e/ -v
```

### Run All Tests

```bash
cd tests
python -m pytest -v
```

## Test Categories

### Unit Tests (`unit/`)

- **Purpose**: Test individual components in isolation
- **Dependencies**: None (mocked)
- **Speed**: Fast (< 1 second per test)
- **Coverage**: Python configure script logic

### Integration Tests (`integration/`)

- **Purpose**: Test component interactions
- **Dependencies**: Kubernetes cluster, Kratix
- **Speed**: Medium (5-30 seconds per test)
- **Coverage**: Promise deployment, CRD creation, container execution

### Contract Tests (`contract/`)

- **Purpose**: Validate API contracts and output formats
- **Dependencies**: None (schema validation)
- **Speed**: Fast (< 1 second per test)  
- **Coverage**: CRD schema, Backstage format compliance

### End-to-End Tests (`e2e/`)

- **Purpose**: Test complete user workflows
- **Dependencies**: Full Kratix installation, container runtime
- **Speed**: Slow (1-5 minutes per test)
- **Coverage**: Complete team provisioning workflow

## CI/CD Integration

Tests are automatically run in GitHub Actions on every push and pull request:

- **unit-tests**: Runs unit and contract tests
- **integration-tests**: Runs integration tests in Kind cluster  
- **e2e-tests**: Runs end-to-end tests with container builds
- **lint-and-validate**: Validates YAML and Python syntax

## Test Data

Test fixtures are located in `tests/unit/fixtures/`:
- `team_resource.yaml`: Example team resource for testing
- `expected_backstage_output.yaml`: Expected Backstage format output

## Writing New Tests

### Unit Tests
- Mock external dependencies
- Focus on pure function testing
- Use descriptive test names
- Include edge cases

### Integration Tests
- Test real component interactions
- Clean up resources in tearDown
- Handle API exceptions gracefully
- Use unique test identifiers

### Contract Tests
- Validate schemas strictly
- Test both valid and invalid inputs
- Document expected formats
- Use JSON Schema validation

### E2E Tests
- Test complete user workflows
- Include realistic scenarios
- Handle timing and asynchronous operations
- Clean up thoroughly

## Debugging Tests

Run with verbose output and stop on first failure:
```bash
python -m pytest -v -x --tb=long
```

Run specific test:
```bash
python -m pytest tests/unit/test_configure.py::TestTeamConfigure::test_configure_generates_backstage_team -v
```

Print output during tests:
```bash
python -m pytest -s
```