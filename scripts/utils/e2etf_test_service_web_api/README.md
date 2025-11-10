# E2E Test Framework Web API - HTTP Files

This folder contains HTTP request collections for interacting with the E2E Test Framework's Web API. These files are designed for use with the [REST Client extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=humao.rest-client).

## Purpose

The HTTP files provide a convenient way to manually test and interact with the E2E Test Service Web API without needing separate tools like Postman or curl. They allow you to:

- Explore available API endpoints
- Control test execution (start, pause, stop, reset)
- Monitor test runs and their components
- Debug test configurations
- Step through test data generation

## Files

### web_api.http
**General API endpoints for test management**

Contains requests for:
- **Documentation**: Access API docs and OpenAPI specification
- **Test Repositories**: List and inspect test repositories and their tests
- **Test Runs**: View test run details, start/stop test runs

Variables:
- `hostname`: localhost (default)
- `port`: 63123 (Test Service default port)
- `repo_id`: local_dev_repo
- `test_id`: building_comfort
- `test_run_id`: test_run_001

### web_api_source.http
**Source control endpoints**

Contains requests for managing test data sources:
- **List/Detail**: View sources in a test run
- **Control**: Start, pause, stop, reset sources
- **Step**: Execute specific number of data generation steps
- **Skip**: Skip ahead in data generation sequence
- **Bootstrap**: Request bootstrap data for queries

Useful for:
- Debugging data generation
- Testing incremental data flows
- Simulating bootstrap scenarios

### web_api_query.http
**Query control endpoints**

Contains requests for managing continuous queries:
- **List/Detail**: View queries in a test run
- **Control**: Start, pause, stop, reset queries
- **Profile**: Get query result summaries and statistics

Useful for:
- Monitoring query execution
- Analyzing query performance
- Debugging query results

### web_api_reaction.http
**Reaction control endpoints**

Contains requests for managing reactions (result handlers):
- **List/Detail**: View reactions in a test run
- **Control**: Start, pause, stop, reset reactions
- **Profile**: Get reaction result summaries and statistics

Useful for:
- Monitoring result delivery
- Testing reaction endpoints
- Debugging result processing

## Prerequisites

### 1. Install REST Client Extension

In Visual Studio Code:
1. Open Extensions (Cmd+Shift+X)
2. Search for "REST Client"
3. Install the extension by Huachao Mao

### 2. Start the E2E Test Service

The Test Service must be running before using these HTTP files. You can start it by:

**Option A: Run an integration test**
```bash
cd ../../drasi_server/integration/grpc_source_and_reaction
./start.sh
```

**Option B: Run Test Service directly**
```bash
cd /path/to/drasi-test-infra/e2e-test-framework
cargo run --bin test-service -- --config /path/to/config.json
```

The Test Service runs on port `63123` by default.

## Usage

### Basic Workflow

1. **Open an HTTP file** in VS Code
2. **Review the variables** at the top of the file - adjust if needed
3. **Click "Send Request"** above any HTTP request
4. **View the response** in a new editor pane

### Example: Checking Test Service Health

Open `web_api.http` and send the homepage request:

```http
### Homepage
GET http://{{hostname}}:{{port}}
```

Click "Send Request" above the `GET` line. You should see the Test Service homepage response.

### Example: Controlling a Source

Open `web_api_source.http`:

1. **Start a source**:
   ```http
   ### START a Test Run Source
   POST http://{{hostname}}:{{port}}/api/test_runs/{{fq_test_run_id}}/sources/{{source_id}}/start
   ```

2. **Pause the source**:
   ```http
   ### PAUSE a Test Run Source
   POST http://{{hostname}}:{{port}}/api/test_runs/{{fq_test_run_id}}/sources/{{source_id}}/pause
   ```

3. **Step through data** (execute 1 change event):
   ```http
   ### STEP a Test Run Source
   POST http://{{hostname}}:{{port}}/api/test_runs/{{fq_test_run_id}}/sources/{{source_id}}/step
   Content-Type: application/json

   {
     "num_steps": 1,
     "spacing_mode": "None"
   }
   ```

### Variables

All HTTP files use variables (defined with `@variableName = value`) that can be referenced using `{{variableName}}`.

**Common variables:**
- `{{hostname}}`: Server hostname (default: localhost)
- `{{port}}`: Server port (default: 63123)
- `{{repo_id}}`: Test repository ID
- `{{test_id}}`: Test ID
- `{{test_run_id}}`: Test run ID
- `{{fq_test_run_id}}`: Fully qualified test run ID (computed: `repo_id.test_id.test_run_id`)
- `{{source_id}}`, `{{query_id}}`, `{{reaction_id}}`: Component IDs

**To customize:**
- Edit the `@` variable declarations at the top of each file
- Or create a `settings.json` with REST Client environment variables

## API Endpoints Overview

### Test Repositories
- `GET /api/test_repos` - List all test repositories
- `GET /api/test_repos/{repo_id}` - Get repository details
- `GET /api/test_repos/{repo_id}/tests` - List tests in repository
- `GET /api/test_repos/{repo_id}/tests/{test_id}` - Get test details
- `GET /api/test_repos/{repo_id}/tests/{test_id}/sources` - List test sources

### Test Runs
- `GET /api/test_runs` - List all test runs
- `GET /api/test_runs/{test_run_id}` - Get test run details
- `POST /api/test_runs/{test_run_id}/start` - Start a test run
- `POST /api/test_runs/{test_run_id}/stop` - Stop a test run

### Sources (within a test run)
- `GET /api/test_runs/{test_run_id}/sources` - List sources
- `GET /api/test_runs/{test_run_id}/sources/{source_id}` - Get source details
- `POST /api/test_runs/{test_run_id}/sources/{source_id}/start` - Start source
- `POST /api/test_runs/{test_run_id}/sources/{source_id}/pause` - Pause source
- `POST /api/test_runs/{test_run_id}/sources/{source_id}/step` - Step source
- `POST /api/test_runs/{test_run_id}/sources/{source_id}/skip` - Skip data
- `POST /api/test_runs/{test_run_id}/sources/{source_id}/stop` - Stop source
- `POST /api/test_runs/{test_run_id}/sources/{source_id}/reset` - Reset source
- `POST /api/test_runs/{test_run_id}/sources/{source_id}/bootstrap` - Get bootstrap data

### Queries (within a test run)
- `GET /api/test_runs/{test_run_id}/queries` - List queries
- `GET /api/test_runs/{test_run_id}/queries/{query_id}` - Get query details
- `POST /api/test_runs/{test_run_id}/queries/{query_id}/start` - Start query
- `POST /api/test_runs/{test_run_id}/queries/{query_id}/pause` - Pause query
- `POST /api/test_runs/{test_run_id}/queries/{query_id}/stop` - Stop query
- `POST /api/test_runs/{test_run_id}/queries/{query_id}/reset` - Reset query
- `GET /api/test_runs/{test_run_id}/queries/{query_id}/profile` - Get query profile

### Reactions (within a test run)
- `GET /api/test_runs/{test_run_id}/reactions` - List reactions
- `GET /api/test_runs/{test_run_id}/reactions/{reaction_id}` - Get reaction details
- `POST /api/test_runs/{test_run_id}/reactions/{reaction_id}/start` - Start reaction
- `POST /api/test_runs/{test_run_id}/reactions/{reaction_id}/pause` - Pause reaction
- `POST /api/test_runs/{test_run_id}/reactions/{reaction_id}/stop` - Stop reaction
- `POST /api/test_runs/{test_run_id}/reactions/{reaction_id}/reset` - Reset reaction
- `GET /api/test_runs/{test_run_id}/reactions/{reaction_id}/profile` - Get reaction profile

## Known Issues

Some endpoints currently have known issues (marked with `TODO` comments in the HTTP files):

- **Test Repository Listing**: `GET /api/test_repos/{repo_id}/tests` returns empty list
- **Source Listing**: `GET /api/test_repos/{repo_id}/tests/{test_id}/sources` returns 500 error
- **Test Run Control**: Start/Stop test run endpoints may hang
- **Step/Skip**: Step and skip source functionality needs to be re-implemented
- **Bootstrap**: Bootstrap endpoint needs to be re-implemented
- **Query/Reaction Profiles**: Profile endpoints need to be re-implemented

These issues are documented in the HTTP files and should be addressed in future updates.

## Tips

### Viewing All Requests

Use VS Code's outline view (Cmd+Shift+O) to see all requests in the current file and quickly navigate between them.

### Sending Multiple Requests

You can send multiple requests in sequence by selecting them and clicking "Send Request" or using the keyboard shortcut (Cmd+Alt+R on macOS).

### Saving Responses

Responses appear in a new editor pane. You can:
- Copy the response body
- Save the response to a file
- Compare multiple responses

### Environment Configuration

For more advanced configuration, create a `.vscode/settings.json` file in your workspace:

```json
{
  "rest-client.environmentVariables": {
    "local": {
      "hostname": "localhost",
      "port": 63123
    },
    "remote": {
      "hostname": "test-server.example.com",
      "port": 8080
    }
  }
}
```

Then switch between environments using the REST Client status bar.

## Troubleshooting

### Connection Refused
**Error**: `connect ECONNREFUSED 127.0.0.1:63123`
- **Cause**: Test Service is not running
- **Solution**: Start the Test Service (see Prerequisites section)

### 404 Not Found
**Error**: `404 Not Found` for API endpoints
- **Cause**: Incorrect URL or endpoint doesn't exist
- **Solution**: Check variable values and API endpoint path

### 500 Internal Server Error
**Error**: `500 Internal Server Error`
- **Cause**: Server-side error in Test Service
- **Solution**: Check Test Service logs for error details

### Invalid Test Run ID
**Error**: `Test run not found`
- **Cause**: Incorrect `fq_test_run_id` or test run hasn't been initialized
- **Solution**: Verify the test run exists using `GET /api/test_runs`

## Related Documentation

- [REST Client Extension Documentation](https://marketplace.visualstudio.com/items?itemName=humao.rest-client)
- [E2E Test Framework](https://github.com/drasi-project/drasi-test-infra)
- [Drasi Server Integration Tests](../../drasi_server/integration/)
