# Drasi Server gRPC Adaptive Batching Integration Test

This is a self-contained integration test for Drasi Server that validates adaptive batching functionality for both gRPC sources and reactions. It extends the basic gRPC integration test to specifically test dynamic batch size adjustment based on load.

## Purpose

This test validates:
- **Adaptive gRPC Source Batching**: Dynamic batch size adjustment for incoming data
- **Adaptive gRPC Reaction Batching**: Dynamic batch size adjustment for outgoing results
- **High-Throughput Processing**: Server performance under adaptive batching
- **Building Comfort Model**: Synthetic sensor data generation (temperature, CO2, humidity)
- **Performance**: Batch size optimization and latency characteristics

Use this test to verify that:
- Adaptive batching correctly adjusts batch sizes based on throughput
- Changes to Drasi Server haven't broken adaptive batching logic
- Performance improvements from adaptive batching are maintained

## What is Adaptive Batching?

Adaptive batching dynamically adjusts batch sizes and wait times based on current throughput:

**Low Load** → Small batches, short wait times → Low latency
**High Load** → Large batches, longer wait times → High throughput

This provides optimal latency during quiet periods and optimal throughput during bursts.

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
│          │ ADAPTIVE │
│          │ BATCHING │
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
│  │ (Adaptive)    │  │
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
│  │ (Adaptive)    │  │
│  └───────┬───────┘  │
└──────────┼──────────┘
           │ gRPC
           │ :50052
           │ ADAPTIVE
           │ BATCHING
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
Starting Drasi Server Test - gRPC Adaptive (Debug Mode)
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
2. Build and start Drasi Server with adaptive batching enabled
3. Build and run E2E Test Framework with adaptive source batching
4. Generate 1,000 sensor change events (batched adaptively)
5. Verify 1,000 query results are delivered (batched adaptively)
6. Report performance metrics including batch size statistics
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
| `server-config.yaml` | Drasi Server configuration with adaptive batching settings |
| `e2etf-config.json` | E2E Test Framework configuration with adaptive source batching |

### Scripts

| Script | Purpose |
|--------|---------|
| `start.sh` | Builds and runs the complete integration test |
| `stop.sh` | Stops all processes and cleans up ports |

### Log Files (Generated)

| File | Content |
|------|---------|
| `drasi-server-debug.log` | Drasi Server debug logs including batch size adjustments |
| `test-service-debug.log` | E2E Test Framework debug logs including batching behavior |

### Data Directory (Generated)

| Directory | Content |
|-----------|---------|
| `test_data_store/` | Test run data, performance metrics, source change logs (auto-deleted on start/stop) |

## Configuration Details

### server-config.yaml

The key difference from the standard gRPC test is the `adaptive_batching` configuration in the reaction:

**Adaptive Reaction Configuration:**
```yaml
reactions:
- id: rooms-grpc
  reaction_type: grpc
  queries:
  - building-comfort
  auto_start: true
  endpoint: http://127.0.0.1:50052
  batch_size: 1000                    # Initial/default batch size
  batch_flush_timeout_ms: 100         # Initial/default timeout
  adaptive_batching:
    enabled: true                     # Enable adaptive batching
    min_batch_size: 1                 # Minimum batch size (low load)
    max_batch_size: 2000              # Maximum batch size (high load)
    min_wait_time_ms: 0.1             # Minimum wait time (low load)
    max_wait_time_ms: 100             # Maximum wait time (high load)
```

**How it works:**
- **Low throughput**: Batches ~1 record, waits ~0.1ms → Low latency
- **High throughput**: Batches up to 2000 records, waits up to 100ms → High throughput
- **Medium throughput**: Batch size and wait time adjust dynamically

**Increased Capacity Settings:**
```yaml
server_core:
  priority_queue_capacity: 500000      # Increased for adaptive batching
  broadcast_channel_capacity: 500000   # Increased for adaptive batching
```

These larger capacities allow the server to buffer more events during batch accumulation.

### e2etf-config.json

The key difference is the `adaptive_enabled` flag in the source dispatcher:

**Adaptive Source Configuration:**
```json
{
  "source_change_dispatchers": [{
    "kind": "Grpc",
    "host": "localhost",
    "port": 50051,
    "source_id": "facilities-db",
    "batch_events": true,           // Enable batching
    "adaptive_enabled": true,       // Enable adaptive behavior
    "batch_size": 1000,             // Target batch size
    "batch_timeout_ms": 50          // Batch timeout
  }]
}
```

**Test Run Identifier:**
```json
{
  "test_run_id": "test_run_adaptive_001"  // Different from standard test
}
```

This allows running both tests simultaneously for comparison.

## Ports Used

| Port | Service | Direction | Description |
|------|---------|-----------|-------------|
| 8080 | Drasi Server API | Incoming | Health checks, Web API for inspection |
| 50051 | gRPC Source (Adaptive) | Incoming | E2ETF → Drasi (batched data changes) |
| 50052 | gRPC Reaction (Adaptive) | Outgoing | Drasi → E2ETF (batched query results) |
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
- **Reaction Details**: `GET http://localhost:8080/reactions/rooms-grpc`
  - Check adaptive batching status and current batch size

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

1. **Pause data generation to observe batch size adjustment:**
   ```http
   POST http://localhost:63123/api/test_runs/local_dev_repo.building_comfort.test_run_adaptive_001/sources/facilities-db/pause
   ```

2. **Step through data to test low-load batching:**
   ```http
   POST http://localhost:63123/api/test_runs/local_dev_repo.building_comfort.test_run_adaptive_001/sources/facilities-db/step
   Content-Type: application/json

   {"num_steps": 1, "spacing_mode": "None"}
   ```

3. **Check reaction statistics including batch sizes:**
   ```http
   GET http://localhost:63123/api/test_runs/local_dev_repo.building_comfort.test_run_adaptive_001/reactions/building-comfort/profile
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
test_data_store/test_runs/local_dev_repo.building_comfort.test_run_adaptive_001/reactions/building-comfort/output_log/performance_metrics/performance_metrics_*.json
```

Example metrics:
```json
{
  "start_time_ns": 1762662358612275000,
  "end_time_ns": 1762662358641108000,
  "duration_ns": 28833000,
  "record_count": 1000,
  "records_per_second": 34682.48,
  "test_run_reaction_id": "local_dev_repo.building_comfort.test_run_adaptive_001.building-comfort",
  "timestamp": "2025-11-09T04:25:58.641111Z"
}
```

### Analyzing Adaptive Batching Behavior

**Check batch size adjustments in Drasi Server logs:**
```bash
grep -i "batch" drasi-server-debug.log | grep -i "adaptive"
```

**Check source batching in Test Service logs:**
```bash
grep -i "batch" test-service-debug.log | head -20
```

**View batch processing times:**
```bash
grep "Dequeued query result" drasi-server-debug.log | head -20
```

**Compare with standard gRPC test:**
Run both tests and compare performance metrics to see the impact of adaptive batching.

### Log Analysis

**Check for errors in Drasi Server:**
```bash
grep -i error drasi-server-debug.log
```

**Check for errors in Test Service:**
```bash
grep -i error test-service-debug.log
```

**View batched events sent to Drasi:**
```bash
grep "Processing.*batch" drasi-server-debug.log | head -10
```

**View batched results sent to reactions:**
```bash
grep "sending.*results to reactions" drasi-server-debug.log | head -10
```

## Modifying the Test

### Adjust Adaptive Batching Parameters

Edit `server-config.yaml` to tune adaptive batching behavior:

```yaml
reactions:
- id: rooms-grpc
  adaptive_batching:
    enabled: true
    min_batch_size: 10              # Increase minimum for testing
    max_batch_size: 5000            # Increase maximum for high throughput
    min_wait_time_ms: 1.0           # Increase for more batching at low load
    max_wait_time_ms: 500           # Increase for larger batches at high load
```

### Test with More Data

To stress-test adaptive batching with higher load, edit `e2etf-config.json`:

```json
{
  "room_count": [10, 0],         // 10 rooms instead of 1
  "change_count": 100000         // 100,000 changes instead of 1,000
}
```

**Important:** Also update the stop trigger to match:
```json
{
  "stop_triggers": [{
    "kind": "RecordCount",
    "record_count": 100000       // Must match change_count
  }]
}
```

### Disable Adaptive Batching for Comparison

To compare performance with/without adaptive batching:

**In `server-config.yaml`:**
```yaml
reactions:
- id: rooms-grpc
  adaptive_batching:
    enabled: false              # Disable adaptive batching
```

**In `e2etf-config.json`:**
```json
{
  "source_change_dispatchers": [{
    "adaptive_enabled": false   // Disable adaptive source batching
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

For performance benchmarking, edit `start.sh` line 82:

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

### Adaptive Batching Not Working

**Check if adaptive batching is enabled:**
```bash
# In server-config.yaml
grep -A5 "adaptive_batching" server-config.yaml

# In e2etf-config.json
grep "adaptive_enabled" e2etf-config.json
```

**Check for adaptive batching logs:**
```bash
grep -i "adaptive" drasi-server-debug.log
```

**Verify batch sizes are changing:**
Look for varying batch sizes in the logs rather than constant sizes.

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
- **Batch sizes not adapting**: Check `adaptive_batching.enabled` is `true`

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

## Performance Comparison

### Comparing with Standard gRPC Test

To understand the impact of adaptive batching, run both tests and compare:

**Standard gRPC test:**
```bash
cd ../grpc_source_and_reaction
./start.sh
# Note the throughput from performance metrics
```

**Adaptive gRPC test:**
```bash
cd ../grpc_adaptive_source_and_reaction
./start.sh
# Compare throughput and latency
```

**Expected differences:**
- **Adaptive batching** may show higher peak throughput during bursts
- **Adaptive batching** may show lower latency during quiet periods
- **Adaptive batching** should show varying batch sizes in logs
- **Standard batching** should show consistent batch sizes

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
cd scripts/drasi_server/integration/grpc_adaptive_source_and_reaction
./start.sh
if [ $? -eq 0 ]; then
    echo "Adaptive batching integration test passed"
    exit 0
else
    echo "Adaptive batching integration test failed"
    exit 1
fi
```

### Benchmark Suite

Create a script to run both tests and compare results:

```bash
#!/bin/bash

echo "Running standard gRPC test..."
cd ../grpc_source_and_reaction
./start.sh
STANDARD_RESULT=$?

echo "Running adaptive gRPC test..."
cd ../grpc_adaptive_source_and_reaction
./start.sh
ADAPTIVE_RESULT=$?

if [ $STANDARD_RESULT -eq 0 ] && [ $ADAPTIVE_RESULT -eq 0 ]; then
    echo "Both tests passed - comparing metrics..."
    # Compare performance metrics from both tests
    exit 0
else
    echo "One or more tests failed"
    exit 1
fi
```

## Adaptive Batching Algorithm

The adaptive batching algorithm works as follows:

1. **Monitor throughput**: Track the rate of incoming events or outgoing results
2. **Adjust batch size**:
   - High throughput → Increase batch size (up to `max_batch_size`)
   - Low throughput → Decrease batch size (down to `min_batch_size`)
3. **Adjust wait time**:
   - High throughput → Increase wait time (up to `max_wait_time_ms`)
   - Low throughput → Decrease wait time (down to `min_wait_time_ms`)
4. **Send batch** when either:
   - Batch size reaches current target, OR
   - Wait time expires

This provides:
- **Low latency** during quiet periods (small batches, short waits)
- **High throughput** during bursts (large batches, longer waits)
- **Smooth transitions** between load levels

## Related Tests

- `../grpc_source_and_reaction/` - Standard gRPC test without adaptive batching

## Related Documentation

- [Drasi Server Web API Utilities](../../../utils/drasi_server_web_api/)
- [E2E Test Framework Web API Utilities](../../../utils/e2etf_test_service_web_api/)
- [E2E Test Framework Documentation](https://github.com/drasi-project/drasi-test-infra)
- [Drasi Server Documentation](https://github.com/drasi-project/drasi-server)
- [Standard gRPC Integration Test](../grpc_source_and_reaction/README.md)
