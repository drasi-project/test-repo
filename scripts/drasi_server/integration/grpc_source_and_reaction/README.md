# Drasi Server gRPC Integration Test

This is a self-contained integration test for the Drasi Server with gRPC source and reaction endpoints. The test validates the complete data flow from source generation through query processing to reaction delivery.

## Purpose

This test validates:
- gRPC source integration (port 50051)
- Continuous query processing with Cypher
- gRPC reaction delivery (port 50052)
- Building Comfort model data generation
- End-to-end data flow through Drasi Server

The test generates synthetic building comfort data (temperature, CO2, humidity sensors) and verifies that Drasi Server correctly processes changes and delivers results via gRPC.

## Architecture

```
┌─────────────────────┐
│  E2E Test Framework │
│  (test-service)     │
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
│   (port 8080)       │
│                     │
│  ┌───────────────┐  │
│  │ gRPC Source   │  │
│  └───────┬───────┘  │
│          │          │
│  ┌───────▼───────┐  │
│  │ Query Engine  │  │
│  │  (Cypher)     │  │
│  └───────┬───────┘  │
│          │          │
│  ┌───────▼───────┐  │
│  │ gRPC Reaction │  │
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

## Configuration Files

### server-config.yaml

Configures the Drasi Server with:
- **Server**: API on port 8080, logging, persistence disabled
- **Server Core**: Priority queue capacity settings
- **Sources**: gRPC source endpoint on port 50051 with keepalive and connection settings
- **Queries**: Cypher query returning Room entities with their properties
- **Reactions**: gRPC reaction endpoint on port 50052 with batching, retry, and metadata settings

```yaml
server:
  host: 0.0.0.0
  port: 8080
  log_level: drasi_server=info,drasi_core=warn
  disable_persistence: true

server_core:
  priority_queue_capacity: 10000

sources:
- id: facilities-db
  source_type: grpc
  auto_start: true
  keepalive_interval_seconds: 10
  keepalive_timeout_seconds: 10
  host: 0.0.0.0
  port: 50051
  max_message_size: 8388608
  max_connections: 100

queries:
- id: building-comfort
  query: |
    MATCH
      (r:Room)
    RETURN
      elementId(r) AS RoomId,
      r.temperature, r.humidity, r.co2
  sources:
  - facilities-db
  auto_start: true

reactions:
- id: rooms-grpc
  reaction_type: grpc
  queries:
  - building-comfort
  auto_start: true
  endpoint: http://127.0.0.1:50052
  batch_flush_timeout_ms: 100
  compression: false
  batch_size: 1000
  keepalive:
    interval_seconds: 10
    timeout_seconds: 10
  metadata:
    x-api-key: test-key-12345
    x-client-id: drasi-test
  max_retries: 3
  timeout_ms: 5000
  retry_delay_ms: 500
  tls:
    enabled: false
```

### e2etf-config.json

Configures the E2E Test Framework with:
- **Test Data Cache**: Stored in `test_data_store/` subdirectory (overridden by `--data` command-line argument)
- **Test Repository**: References `dev_repo/` from drasi-test-repo
- **Data Generator**: Building Hierarchy model
  - 1 building, 1 floor, 1 room
  - 1,000 change events
  - 3 sensors per room (temperature, CO2, humidity)
- **Source Dispatcher**: gRPC to localhost:50051
- **Reaction Handler**: gRPC on port 50052
- **Stop Trigger**: After receiving 1,000 records

Key settings:
```json
{
  "data_store": {
    "data_store_path": "./test_data_cache",
    "delete_on_start": true,
    "delete_on_stop": true
  },
  "test_repos": [{
    "source_path": "../../../../../drasi-test-repo/dev_repo"
  }]
}
```

**Note**: The `data_store_path` in the config is overridden by the `--data` command-line argument passed by `start.sh`, which sets it to `test_data_store/` in the script's directory.

## Running the Test

### Start the Test

From the test directory:
```bash
./start.sh
```

The script will:
1. Check if required ports (8080, 50051, 50052) are available
2. Build drasi-server (debug mode) from `../../../../../drasi-server`
3. Remove old log file if it exists
4. Start drasi-server with the local `server-config.yaml`
5. Wait for server health check on port 8080
6. Build and run E2E test framework from `../../../../../drasi-test-infra/e2e-test-framework`
7. Execute the test with `e2etf-config.json` and data stored in `test_data_store/`
8. Display test progress and results
9. Clean up and report final status

**Expected output:**
```
Starting Drasi Server Test - gRPC (Debug Mode)
================================================
Checking port availability...
All required ports are available
Found Drasi Server at: /path/to/drasi-server
Found E2E Test Framework at: /path/to/e2e-test-framework
Cleaning up any existing processes...
Building Drasi Server (Debug)...
Removing old log file...
Starting Drasi Server with debug logging...
Drasi Server PID: 12345
Drasi Server log: /path/to/drasi-server-debug.log
Waiting for Drasi Server to be ready...
Drasi Server is ready!
Starting E2E Test Framework (Debug)...
...
Test completed successfully!
```

### Stop the Test

If you need to manually stop the test:
```bash
./stop.sh
```

This script will:
- Gracefully terminate drasi-server processes
- Gracefully terminate test-service processes
- Force kill processes on ports 8080, 50051, 50052 if needed
- Preserve log files for debugging

## Test Logs

### Drasi Server Logs
- **Location**: `drasi-server-debug.log`
- **Content**: Server startup, source connections, query execution, reaction delivery
- **Log Level**: Debug (controlled by RUST_LOG=debug in start.sh)

### E2E Test Framework Logs
- **Console Output**: Real-time test progress
- **Performance Metrics**: Stored in `test_data_cache/test_runs/.../performance_metrics/`
- **Source Change Log**: Stored in `test_data_cache/test_runs/.../sources/facilities-db/`

## Ports Used

| Port  | Service | Description |
|-------|---------|-------------|
| 8080  | Drasi Server API | Health check and management API |
| 50051 | gRPC Source | E2ETF sends data changes to Drasi |
| 50052 | gRPC Reaction | Drasi sends query results to E2ETF |

## Test Data

The test generates a building hierarchy:
- **Buildings**: 1
- **Floors per Building**: 1
- **Rooms per Floor**: 1
- **Sensors per Room**: 3 (temperature, CO2, humidity)
- **Change Events**: 1,000 property updates

Each change event modifies sensor values with:
- Random walk behavior (momentum-based changes)
- Configurable variance
- Value range constraints

## Modifying the Test

### Change Test Size

Edit `e2etf-config.json`:
```json
{
  "building_count": [1, 0],     // [count, variance]
  "floor_count": [1, 0],
  "room_count": [5, 0],         // Increase rooms
  "change_count": 10000         // More changes
}
```

Also update the stop trigger:
```json
{
  "stop_triggers": [{
    "kind": "RecordCount",
    "record_count": 10000        // Match change_count
  }]
}
```

### Change Sensor Behavior

Edit sensor definitions in `e2etf-config.json`:
```json
{
  "id": "temperature",
  "value_init": [72, 5],          // Initial: 72°F ± 5
  "value_change": [1, 0.5],       // Change: ±1°F with variance
  "value_range": [60, 85],        // Constrain to 60-85°F
  "momentum_init": [5, 1, 0.5]    // Momentum settings
}
```

### Use Release Build

Edit `start.sh` to build in release mode:
```bash
cargo build --release
```

And update the binary path:
```bash
./target/release/drasi-server --config "$CONFIG_FILE"
```

## Troubleshooting

### Port Already in Use

**Error**: "The following required ports are already in use"

The start script automatically checks if ports 8080, 50051, and 50052 are available before running. If any port is in use, you'll see an error message like:

```
Error: The following required ports are already in use:
  - Port 8080 (Drasi Server API)
  - Port 50051 (gRPC Source)
```

**Solution**: Run `./stop.sh` to clean up existing processes:
```bash
./stop.sh
```

**Manual cleanup** (if stop.sh doesn't work):
```bash
lsof -ti:8080 | xargs kill -9
lsof -ti:50051 | xargs kill -9
lsof -ti:50052 | xargs kill -9
```

### Test Hangs

- Check `drasi-server-debug.log` for errors
- Verify all three components are running:
  ```bash
  ps aux | grep drasi-server
  ps aux | grep test-service
  ```
- Check port connectivity:
  ```bash
  curl http://localhost:8080/health
  ```

### Test Data Cache Issues

If you encounter cache-related errors:
```bash
rm -rf test_data_store/
./start.sh
```

The test data cache is stored in the `test_data_store/` subdirectory and is automatically cleaned on start/stop as configured in `e2etf-config.json` (`delete_on_start: true`, `delete_on_stop: true`).

## Performance Metrics

After a successful test run, performance metrics are available in:
```
test_data_store/test_runs/local_dev_repo.building_comfort.test_run_001/reactions/building-comfort/output_log/performance_metrics/
```

Metrics include:
- Record processing latency
- Throughput (records/second)
- End-to-end latency distribution
- Batch processing times

## Related Documentation

- [Drasi Server Documentation](https://github.com/drasi-project/drasi-server)
- [E2E Test Framework](https://github.com/drasi-project/drasi-test-infra)
- [Building Comfort Model](../../dev_repo/building_comfort.test.json)
