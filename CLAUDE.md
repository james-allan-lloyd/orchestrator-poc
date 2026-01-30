# Claude Code Configuration

This file contains configuration and development notes for Claude Code.

## Code Style

- Python: indentation of 2 with spaces. Use types as much as possible. Version should be 3.11+.

## Workflow

- Always run unit tests before committing.

## Testing Virtual Environment

**Location**: `tests/test-env/`

Always create and use the virtual environment in the `tests/` directory to keep testing dependencies isolated and organized:

```bash
# Navigate to tests directory
cd tests

# Create virtual environment
python -m venv test-env

# Activate virtual environment
source test-env/bin/activate  # On Windows: test-env\Scripts\activate

# Install test dependencies
pip install -r requirements.txt

# Run tests (from tests directory)
PYTHONPATH=../promises/team-promise/workflows/resource/configure/team-configure/python/scripts python -m pytest unit/ -v

# Deactivate when done
deactivate
```

## Important Notes

- Never install packages globally with `pip install` without a virtual environment
- Keep the virtual environment in `tests/test-env/` - it's already in `.gitignore`
- Always activate the virtual environment before running tests
- Run tests from the `tests/` directory for proper path resolution

## Pre-Commit Requirements

**ALWAYS run tests before committing code changes:**

```bash
cd tests
source test-env/bin/activate
python -m pytest unit/ -v
deactivate
```

Only commit if all tests pass. This ensures code quality and prevents regressions.

