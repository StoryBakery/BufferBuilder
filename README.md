# BufferUtil

## Tests
This package runs tests with `lune`.

### Prerequisites
- Install Rokit tools with `rokit install`.
- Install dependencies with `pesde install`.

### Run
- `lune run scripts/run_tests.luau`

## CI
- GitHub Actions workflow: `.github/workflows/ci.yml`
- Trigger: `push` (`main`, `master`) and `pull_request`
- Tests are executed directly with `lune` through `scripts/run_tests.luau`
