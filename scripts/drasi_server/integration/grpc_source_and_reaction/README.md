# Drasi Server gRPC Integration Test

This is a self-contained integration test for Drasi Server that validates the complete end-to-end data flow using gRPC source and reaction endpoints.

## Purpose

This test validates:
- **gRPC Source Integration**: Data ingestion via gRPC on port 50051
- **Continuous Query Processing**: Cypher query execution with real-time updates
- **gRPC Reaction Delivery**: Query results pushed via gRPC on port 50052
- **Building Comfort Model**: Synthetic sensor data generation (temperature, CO2, humidity)
- **Performance**: End-to-end throughput and latency measurement

Use this test to verify that changes to Drasi Server haven't broken the core gRPC integration pathways.

## Architecture

```
┌─────────────────────┐
│  E2E Test Framework │
│  (test-service)     │
│  Port: 63123        │
│                     │
│  ┌───────────────┐  │
│  │ Data Generator│  │
│  │  (Building    │  │
│  │   Hierarchy)  │  │
│  └───────┬───────┘  │
│          │ gRPC     │
│          │ :50051   │
└──────────┼──────────┘
           │
           ▼
┌─────────────────────┐
│   Drasi Server      │
│   Port: 8080 (API)  │
│                     │
│  ┌───────────────┐  │
│  │ gRPC Source   │  │
│  │   :50051      │  │
│  └───────┬───────┘  │
│          │          │
│  ┌───────▼───────┐  │
│  │ Query Engine  │  │
│  │  (Cypher)     │  │
│  └───────┬───────┘  │
│          │          │
│  ┌───────▼───────┐  │
│  │ gRPC Reaction │  │
│  │   :50052      │  │
│  └───────┬───────┘  │
└──────────┼──────────┘
           │ gRPC
           │ :50052
           ▼
┌─────────────────────┐
│  E2E Test Framework │
│  (Reaction Handler) │
│                     │
│  ┌───────────────┐  │
│  │  Performance  │  │
│  │   Metrics     │  │
│  └───────────────┘  │
└─────────────────────┘
```

## Prerequisites

This test requires the following sibling repositories:

```
parent/
  drasi-server/          # Main Drasi server codebase
  drasi-test-infra/      # E2E test framework
    e2e-test-framework/
      test-service/      # Test service Cargo project
  drasi-test-repo/       # This repository
```

The test scripts automatically navigate to these directories using relative paths.

## Quick Start

### Run the Test

```bash
./start.sh
```

Expected output:
```
Starting Drasi Server Test - gRPC (Debug Mode)
================================================
Checking port availability...
All required ports are available
Found Drasi Server at: /path/to/drasi-server
Found E2E Test Framework at: /path/to/e2e-test-framework
...
Test completed successfully!
```

The test will automatically:
1. Check port availability (8080, 50051, 50052, 63123)
2. Build and start Drasi Server
3. Build and run E2E Test Framework
4. Generate 1,000 sensor change events
5. Verify 1,000 query results are delivered
6. Report performance metrics
7. Clean up processes

### Stop the Test

```bash
./stop.sh
```

This gracefully terminates all processes and cleans up ports. Run this if:
- The test hangs or fails
- You need to interrupt a running test
- You get "port already in use" errors

## Files Overview

### Configuration Files

| File | Purpose |
|------|---------|
| `server-config.yaml` | Drasi Server configuration (sources, queries, reactions) |
| `e2etf-config.json` | E2E Test Framework configuration (test data, generators, triggers) |

### Scripts

| Script | Purpose |
|--------|---------|
| `start.sh` | Builds and runs the complete integration test |
| `stop.sh` | Stops all processes and cleans up ports |

### Log Files (Generated)

| File | Content |
|------|---------|
| `drasi-server-debug.log` | Drasi Server debug logs (RUST_LOG=debug) |
| `test-service-debug.log` | E2E Test Framework debug logs (RUST_LOG=debug) |

### Data Directory (Generated)

| Directory | Content |
|-----------|---------|
| `test_data_store/` | Test run data, performance metrics, source change logs (auto-deleted on start/stop) |

## Configuration Details

### server-config.yaml

Configures Drasi Server with three main sections:

**Server Configuration:**
```yaml
server:
  host: 0.0.0.0
  port: 8080                    # Health check and Web API
  log_level: drasi_server=info,drasi_core=warn
  disable_persistence: true     # No disk persistence needed for tests
```

**Source Configuration:**
```yaml
sources:
- id: facilities-db
  source_type: grpc
  auto_start: true              # Start when server starts
  port: 50051                   # gRPC source endpoint
  max_message_size: 8388608     # 8MB max message
  max_connections: 100
  keepalive_interval_seconds: 10
  keepalive_timeout_seconds: 10
```

**Query Configuration:**
```yaml
queries:
- id: building-comfort
  query: |
    MATCH (r:Room)
    RETURN elementId(r) AS RoomId,
           r.temperature, r.humidity, r.co2
  sources:
  - facilities-db
  auto_start: true
```

**Reaction Configuration:**
```yaml
reactions:
- id: rooms-grpc
  reaction_type: grpc
  queries:
  - building-comfort
  auto_start: true
  endpoint: http://127.0.0.1:50052
  batch_size: 1000
  batch_flush_timeout_ms: 100
  max_retries: 3
  timeout_ms: 5000
  metadata:
    x-api-key: test-key-12345
    x-client-id: drasi-test
```

### e2etf-config.json

Configures the E2E Test Framework:

**Data Store:**
```json
{
  "data_store_path": "./test_data_cache",  // Overridden by --data flag
  "delete_on_start": true,                 // Clean cache on start
  "delete_on_stop": true                   // Clean cache on stop
}
```

**Test Source (Data Generator):**
```json
{
  "test_source_id": "facilities-db",
  "kind": "Model",
  "model_data_generator": {
    "kind": "BuildingHierarchy",
    "building_count": [1, 0],        // 1 building, no variance
    "floor_count": [1, 0],           // 1 floor per building
    "room_count": [1, 0],            // 1 room per floor
    "change_count": 1000,            // Generate 1,000 change events
    "room_sensors": [
      {"kind": "NormalFloat", "id": "temperature"},
      {"kind": "NormalFloat", "id": "co2"},
      {"kind": "NormalFloat", "id": "humidity"}
    ]
  },
  "source_change_dispatchers": [{
    "kind": "Grpc",
    "host": "localhost",
    "port": 50051,
    "source_id": "facilities-db"
  }]
}
```

**Test Reaction (Result Handler):**
```json
{
  "test_reaction_id": "building-comfort",
  "output_handler": {
    "kind": "Grpc",
    "host": "0.0.0.0",
    "port": 50052,
    "query_ids": ["building-comfort"]
  },
  "stop_triggers": [{
    "kind": "RecordCount",
    "record_count": 1000           // Stop after receiving 1,000 results
  }]
}
```

## Ports Used

| Port | Service | Direction | Description |
|------|---------|-----------|-------------|
| 8080 | Drasi Server API | Incoming | Health checks, Web API for inspection |
| 50051 | gRPC Source | Incoming | E2ETF → Drasi (data changes) |
| 50052 | gRPC Reaction | Outgoing | Drasi → E2ETF (query results) |
| 63123 | Test Service API | Incoming | Web API for test control/inspection |

## Inspecting Running Tests

Both Drasi Server and the E2E Test Framework expose Web APIs for inspection and control during test execution.

### Drasi Server Web API (Port 8080)

Use the HTTP files in `../../../utils/drasi_server_web_api/` to interact with Drasi Server:

```bash
# Open in VS Code with REST Client extension
code ../../../utils/drasi_server_web_api/web_api.http
```

**Available Operations:**
- **Health Check**: `GET http://localhost:8080/health`
- **List Sources**: `GET http://localhost:8080/sources`
- **List Queries**: `GET http://localhost:8080/queries`
- **List Reactions**: `GET http://localhost:8080/reactions`
- **Query Details**: `GET http://localhost:8080/queries/{query_id}`
- **Reaction Details**: `GET http://localhost:8080/reactions/{reaction_id}`

See `../../../utils/drasi_server_web_api/` for more operations (start/stop/pause sources, queries, and reactions).

### E2E Test Service Web API (Port 63123)

Use the HTTP files in `../../../utils/e2etf_test_service_web_api/` to interact with the Test Framework:

```bash
# Open in VS Code with REST Client extension
code ../../../utils/e2etf_test_service_web_api/web_api.http
```

**Available Operations:**
- **Test Runs**: List/view test runs and their status
- **Sources**: Control data generation (start/pause/stop/step/skip)
- **Queries**: Monitor query execution and results
- **Reactions**: Monitor reaction delivery and performance
- **Test Repos**: Inspect test definitions and configurations

**Example Use Cases:**

1. **Pause data generation to debug query processing:**
   ```http
   POST http://localhost:63123/api/test_runs/local_dev_repo.building_comfort.test_run_001/sources/facilities-db/pause
   ```

2. **Step through data one event at a time:**
   ```http
   POST http://localhost:63123/api/test_runs/local_dev_repo.building_comfort.test_run_001/sources/facilities-db/step
   Content-Type: application/json

   {"num_steps": 1, "spacing_mode": "None"}
   ```

3. **Check reaction statistics:**
   ```http
   GET http://localhost:63123/api/test_runs/local_dev_repo.building_comfort.test_run_001/reactions/building-comfort/profile
   ```

See `../../../utils/e2etf_test_service_web_api/README.md` for detailed API documentation.

### Using the HTTP Files

1. **Install REST Client extension** in VS Code:
   - Open Extensions (Cmd+Shift+X / Ctrl+Shift+X)
   - Search for "REST Client"
   - Install the extension by Huachao Mao

2. **Open an HTTP file** from the utils folders

3. **Click "Send Request"** above any HTTP request to execute it

4. **View the response** in a new editor pane

## Viewing Test Results

### Performance Metrics

After a successful test run, performance metrics are saved to:
```
test_data_store/test_runs/local_dev_repo.building_comfort.test_run_001/reactions/building-comfort/output_log/performance_metrics/performance_metrics_*.json
```

Example metrics:
```json
{
  "start_time_ns": 1762662358612275000,
  "end_time_ns": 1762662358641108000,
  "duration_ns": 28833000,
  "record_count": 1000,
  "records_per_second": 34682.48,
  "test_run_reaction_id": "local_dev_repo.building_comfort.test_run_001.building-comfort",
  "timestamp": "2025-11-09T04:25:58.641111Z"
}
```

### Log Analysis

**Check for errors in Drasi Server:**
```bash
grep -i error drasi-server-debug.log
```

**Check for errors in Test Service:**
```bash
grep -i error test-service-debug.log
```

**View source events sent to Drasi:**
```bash
grep "Processing gRPC event" drasi-server-debug.log | head -10
```

**View query results sent to reactions:**
```bash
grep "sending.*results to reactions" drasi-server-debug.log | head -10
```

## Modifying the Test

### Change Test Size

To test with more data, edit `e2etf-config.json`:

```json
{
  "room_count": [10, 0],         // 10 rooms instead of 1
  "change_count": 10000          // 10,000 changes instead of 1,000
}
```

**Important:** Also update the stop trigger to match:
```json
{
  "stop_triggers": [{
    "kind": "RecordCount",
    "record_count": 10000        // Must match change_count
  }]
}
```

### Change Query

Edit `server-config.yaml` to modify the Cypher query:

```yaml
queries:
- id: building-comfort
  query: |
    MATCH (r:Room)
    WHERE r.temperature > 5500
    RETURN elementId(r) AS RoomId,
           r.temperature, r.humidity, r.co2
```

### Use Release Build

For performance testing, edit `start.sh` line 82:

```bash
# Change from:
cargo build

# To:
cargo build --release
```

And update line 102:
```bash
# Change from:
RUST_LOG=debug ./target/debug/drasi-server --config "$CONFIG_FILE" > "$LOG_FILE" 2>&1 &

# To:
./target/release/drasi-server --config "$CONFIG_FILE" > "$LOG_FILE" 2>&1 &
```

## Troubleshooting

### Port Already in Use

**Symptom:**
```
Error: The following required ports are already in use:
  - Port 8080 (Drasi Server API)
  - Port 50051 (gRPC Source)
  - Port 50052 (gRPC Reaction)
  - Port 63123 (Test Service API)
```

**Solution:**
```bash
./stop.sh
```

If `stop.sh` doesn't resolve it:
```bash
# Find and kill processes on specific ports
lsof -ti:8080 | xargs kill -9
lsof -ti:50051 | xargs kill -9
lsof -ti:50052 | xargs kill -9
lsof -ti:63123 | xargs kill -9
```

### Test Hangs or Fails

**Check if processes are running:**
```bash
ps aux | grep drasi-server
ps aux | grep test-service
```

**Check Drasi Server health:**
```bash
curl http://localhost:8080/health
```

**Review logs for errors:**
```bash
tail -50 drasi-server-debug.log
tail -50 test-service-debug.log
```

**Common issues:**
- **gRPC connection failed**: Check if ports 50051/50052 are actually listening
- **Query not processing**: Check query syntax in `server-config.yaml`
- **Test hangs at completion**: Check stop trigger `record_count` matches `change_count`

### Build Failures

**Drasi Server build fails:**
```bash
# Navigate to drasi-server and build manually
cd ../../../../../drasi-server
cargo clean
cargo build
```

**E2E Test Framework build fails:**
```bash
# Navigate to e2e-test-framework and build manually
cd ../../../../../drasi-test-infra/e2e-test-framework
cargo clean
cargo build --manifest-path ./test-service/Cargo.toml
```

### Test Data Cache Issues

If you encounter cache-related errors or want a clean slate:
```bash
rm -rf test_data_store/
./start.sh
```

The test automatically cleans `test_data_store/` on start and stop (configured via `delete_on_start` and `delete_on_stop` in `e2etf-config.json`).

## Advanced Usage

### Running in Background

To run the test in the background and monitor via logs:
```bash
./start.sh > test-output.log 2>&1 &
tail -f test-output.log
```

### Custom Test Data Path

The `start.sh` script passes `--data ./test_data_store` to the test-service. To use a different location, modify line 138 in `start.sh`:

```bash
RUST_LOG=debug cargo run --manifest-path ./test-service/Cargo.toml -- \
    --config "$SCRIPT_DIR/e2etf-config.json" \
    --data "/path/to/custom/data/dir" > "$TEST_SERVICE_LOG" 2>&1
```

### Integration with CI/CD

The test returns exit code 0 on success, non-zero on failure:

```bash
#!/bin/bash
cd scripts/drasi_server/integration/grpc_source_and_reaction
./start.sh
if [ $? -eq 0 ]; then
    echo "Integration test passed"
    exit 0
else
    echo "Integration test failed"
    exit 1
fi
```

## Related Tests

- `../grpc_adaptive_source_and_reaction/` - Tests adaptive batching with gRPC sources

## Related Documentation

- [Drasi Server Web API Utilities](../../../utils/drasi_server_web_api/)
- [E2E Test Framework Web API Utilities](../../../utils/e2etf_test_service_web_api/)
- [E2E Test Framework Documentation](https://github.com/drasi-project/drasi-test-infra)
- [Drasi Server Documentation](https://github.com/drasi-project/drasi-server)
