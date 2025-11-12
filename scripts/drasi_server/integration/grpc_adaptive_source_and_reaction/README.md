# Drasi Server Adaptive gRPC Integration Test

This is a self-contained integration test for Drasi Server that validates the complete end-to-end data flow using gRPC source and reaction endpoints with **adaptive batch sizing** for improved efficiency.

## Purpose

This test validates:
- **Adaptive gRPC Source Integration**: Data ingestion via gRPC on port 50051 with dynamic batch sizing
- **Continuous Query Processing**: Cypher query execution with real-time updates
- **gRPC Reaction Delivery**: Query results pushed via gRPC on port 50052
- **Building Comfort Model**: Synthetic sensor data generation (temperature, CO2, humidity)
- **Adaptive Batching**: Dynamic adjustment of batch sizes based on throughput and latency
- **Performance**: End-to-end throughput and latency measurement with adaptive optimization

Use this test to verify that adaptive batching in the gRPC source improves throughput and reduces latency compared to fixed batching.

## What is Adaptive Batching?

Adaptive batching is a dynamic optimization technique that automatically adjusts batch sizes and flush timeouts based on real-time system performance. Unlike fixed batching which uses static parameters, adaptive batching:

- **Monitors throughput and latency**: Tracks how quickly events are being processed
- **Adjusts batch size dynamically**: Increases batch size when throughput is high, decreases when latency increases
- **Optimizes for efficiency**: Balances between high throughput (large batches) and low latency (quick flushes)
- **Responds to load changes**: Automatically adapts to varying data generation rates

This test compares adaptive batching performance against the baseline fixed-batch test to demonstrate improved efficiency under real-world conditions.

## Architecture

```
┌─────────────────────────────┐
│  E2E Test Framework         │
│  (test-service)             │
│                             │
│  ┌───────────────────────┐  │
│  │ Data Generator        │  │
│  │  (Building Hierarchy) │  │
│  │  - 1,000 events       │  │
│  │  - Adaptive batching  │  │
│  └───────────┬───────────┘  │
│              │ gRPC         │
│              │ :50051       │
│              │ (adaptive)   │
└──────────────┼──────────────┘
               │
               ▼
┌─────────────────────────────┐
│   Drasi Server              │
│   Port: 8080 (API)          │
│                             │
│  ┌───────────────────────┐  │
│  │ Adaptive gRPC Source  │  │
│  │   :50051              │  │
│  │ - Dynamic batch size  │  │
│  └───────────┬───────────┘  │
│              │              │
│  ┌───────────▼───────────┐  │
│  │ Query Engine          │  │
│  │  (Cypher)             │  │
│  └───────────┬───────────┘  │
│              │              │
│  ┌───────────▼───────────┐  │
│  │ gRPC Reaction         │  │
│  │   :50052              │  │
│  └───────────┬───────────┘  │
└──────────────┼──────────────┘
               │ gRPC
               │ :50052
               ▼
┌─────────────────────────────┐
│  E2E Test Framework         │
│  (Reaction Handler)         │
│                             │
│  ┌───────────────────────┐  │
│  │  Performance Metrics  │  │
│  │  - Throughput         │  │
│  │  - Latency            │  │
│  └───────────────────────┘  │
└─────────────────────────────┘
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
1. Check port availability (8080, 50051, 50052)
2. Build and start Drasi Server
3. Build and run E2E Test Framework
4. Generate 1,000 sensor change events with adaptive batch sizing
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
| `drasi-server-config.yaml` | Drasi Server configuration (sources, queries, reactions) |
| `test-service-config.yaml` | E2E Test Framework configuration (test repos, test runs) |

### Scripts

| Script | Purpose |
|--------|---------|
| `start.sh` | Builds and runs the complete integration test |
| `stop.sh` | Stops all processes and cleans up ports |

### Log Files (Generated)

| File | Content |
|------|---------|
| `drasi-server.log` | Drasi Server logs (RUST_LOG=debug) |
| `test-service.log` | E2E Test Framework logs (RUST_LOG=debug) |

### Data Directory (Generated)

| Directory | Content |
|-----------|---------|
| `test_data_store/` | Test run data, performance metrics, source change logs (auto-deleted on start/stop) |

## Configuration Details

### drasi-server-config.yaml

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

### test-service-config.yaml

Configures the E2E Test Framework to use a test definition from GitHub:

**Data Store and Test Repositories:**
```yaml
data_store:
  data_store_path: ./test_data_cache    # Overridden by --data flag
  delete_on_start: true                 # Clean cache on start
  delete_on_stop: true                  # Clean cache on stop

  # Test Repository Configuration (nested under data_store)
  test_repos:
    - id: github_dev_repo
      kind: GitHub                      # Fetch test from GitHub
      owner: drasi-project
      repo: test-repo
      branch: query-host
      force_cache_refresh: false        # Use cached test if available
      root_path: dev_repo/drasi_server/integration
```

The test definition is loaded from:
`dev_repo/drasi_server/integration/building_comfort_grpc_adaptive.test`

This test file defines:
- **Data Generator**: BuildingHierarchy model (1 building, 1 floor, 1 room)
- **Change Events**: 1,000 sensor updates (temperature, CO2, humidity)
- **Source Dispatcher**: gRPC to localhost:50051 with adaptive batching enabled
  - `adaptive_enabled: true` - Enables dynamic batch size adjustment
  - `batch_size: 1000` - Initial batch size
  - `batch_timeout_ms: 50` - Initial batch flush timeout
- **Reaction Handler**: gRPC on 0.0.0.0:50052
- **Stop Trigger**: RecordCount of 1,000 results

**Test Run Configuration:**
```yaml
test_run_host:
  test_runs:
    - test_id: building_comfort_grpc_adaptive  # References the test file
      test_repo_id: github_dev_repo
      test_run_id: test_run_001
      sources:
        - test_source_id: facilities-db
          start_mode: auto              # Start immediately
      reactions:
        - test_reaction_id: building-comfort
          start_immediately: true
          output_loggers:
            - kind: PerformanceMetrics  # Log performance data
```

## Ports Used

| Port | Service | Direction | Description |
|------|---------|-----------|-------------|
| 8080 | Drasi Server API | Incoming | Health checks, Web API for inspection |
| 50051 | gRPC Source | Incoming | E2ETF → Drasi (data changes) |
| 50052 | gRPC Reaction | Outgoing | Drasi → E2ETF (query results) |

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

### E2E Test Service Web API (Not Enabled)

**Note:** This test configuration does not enable the test service Web API. The test runs in automated mode without interactive control.

To enable the Web API for interactive debugging, you would need to add the `--port` flag to the test-service command in `start.sh` (line 136):

```bash
RUST_LOG=debug cargo run --manifest-path ./test-service/Cargo.toml -- \
    --config "$SCRIPT_DIR/test-service-config.yaml" \
    --data "$SCRIPT_DIR/test_data_store" \
    --port 63123 > "$TEST_SERVICE_LOG" 2>&1  # Add --port flag
```

Once enabled, you can use the HTTP files in `../../../utils/test_service_web_api/` to interact with the Test Framework for operations like pausing/stepping through data generation, monitoring reactions, and inspecting test state.

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
test_data_store/test_runs/github_dev_repo.building_comfort_grpc_adaptive.test_run_001/reactions/building-comfort/output_log/performance_metrics/performance_metrics_*.json
```

Example metrics:
```json
{
  "start_time_ns": 1762662358612275000,
  "end_time_ns": 1762662358641108000,
  "duration_ns": 28833000,
  "record_count": 1000,
  "records_per_second": 34682.48,
  "test_run_reaction_id": "github_dev_repo.building_comfort_grpc_adaptive.test_run_001.building-comfort",
  "timestamp": "2025-11-09T04:25:58.641111Z"
}
```

These metrics can be compared with the non-adaptive gRPC test to measure the performance improvement from adaptive batching.

### Log Analysis

**Check for errors in Drasi Server:**
```bash
grep -i error drasi-server.log
```

**Check for errors in Test Service:**
```bash
grep -i error test-service.log
```

**View source events sent to Drasi:**
```bash
grep "Processing gRPC event" drasi-server.log | head -10
```

**View query results sent to reactions:**
```bash
grep "sending.*results to reactions" drasi-server.log | head -10
```

## Modifying the Test

### Change Test Size

To test with more data, edit the test definition file in the GitHub repository:
`dev_repo/drasi_server/integration/building_comfort_grpc_adaptive.test`

```yaml
# In the sources section, under model_data_generator:
room_count: [10, 0]              # 10 rooms instead of 1
change_count: 10000              # 10,000 changes instead of 1,000
```

**Important:** Also update the stop trigger to match:
```yaml
# In the reactions section:
stop_triggers:
  - kind: RecordCount
    record_count: 10000          # Must match change_count
```

After modifying the test file, set `force_cache_refresh: true` in `test-service-config.yaml` to fetch the latest version from GitHub.

### Tune Adaptive Batching Parameters

To adjust the adaptive batching behavior, edit the test definition file:
`dev_repo/drasi_server/integration/building_comfort_grpc_adaptive.test`

```yaml
# In the sources section, under source_change_dispatchers:
adaptive_enabled: true           # Enable/disable adaptive batching
batch_size: 1000                 # Initial batch size
batch_timeout_ms: 50             # Initial batch flush timeout
```

The adaptive batching algorithm will automatically adjust these values based on throughput and latency characteristics.

### Change Query

Edit `drasi-server-config.yaml` to modify the Cypher query:

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
tail -50 drasi-server.log
tail -50 test-service.log
```

**Common issues:**
- **gRPC connection failed**: Check if ports 50051/50052 are actually listening
- **Query not processing**: Check query syntax in `drasi-server-config.yaml`
- **Test hangs at completion**: Check stop trigger `record_count` matches `change_count`
- **Adaptive batching not working**: Check `adaptive_enabled: true` in test definition and verify debug logs show batch size adjustments

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

The test automatically cleans `test_data_store/` on start and stop (configured via `delete_on_start` and `delete_on_stop` in `test-service-config.yaml`).

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
    --config "$SCRIPT_DIR/test-service-config.yaml" \
    --data "/path/to/custom/data/dir" > "$TEST_SERVICE_LOG" 2>&1
```

### Integration with CI/CD

The test returns exit code 0 on success, non-zero on failure:

```bash
#!/bin/bash
cd scripts/drasi_server/integration/grpc_adaptive_source_and_reaction
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

- `../grpc_source_and_reaction/` - Baseline gRPC test without adaptive batching (for performance comparison)

## Performance Comparison

To measure the benefits of adaptive batching, compare this test's performance metrics with the non-adaptive version:

1. **Run non-adaptive test:**
   ```bash
   cd ../grpc_source_and_reaction
   ./start.sh
   ```

2. **Run adaptive test:**
   ```bash
   cd ../grpc_adaptive_source_and_reaction
   ./start.sh
   ```

3. **Compare metrics:**
   - Check `records_per_second` in both performance metrics files
   - Compare `duration_ns` for the same `record_count`
   - Review debug logs to see batch size adjustments in adaptive mode

Expected results: Adaptive batching should show improved throughput and lower latency under varying load conditions.

## Related Documentation

- [Drasi Server Web API Utilities](../../../utils/drasi_server_web_api/)
- [E2E Test Framework Web API Utilities](../../../utils/test_service_web_api/)
- [E2E Test Framework Documentation](https://github.com/drasi-project/drasi-test-infra)
- [Drasi Server Documentation](https://github.com/drasi-project/drasi-server)
