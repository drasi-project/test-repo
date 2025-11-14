# Drasi Server gRPC Integration Test

This is a self-contained integration test the uses the E2E Test Framework to test Drasi Server. The test validates the complete end-to-end data flow using gRPC source and reaction endpoints.

## Purpose

This test validates:
- **gRPC Source Integration**: Data ingestion via gRPC on port 50051
- **Continuous Query Processing**: Cypher query execution with real-time updates
- **gRPC Reaction Delivery**: Query results pushed via gRPC on port 50052
- **Building Comfort Model**: Synthetic sensor data generation (temperature, CO2, humidity)
- **Performance**: End-to-end throughput and latency measurement

Use this test to verify that changes to Drasi Server and Drasi Core haven't broken the gRPC integration pathways.

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

The test scripts automatically navigate to these directories using relative paths when you run the test from the folder containing this README file.

## Quick Start

Open a terminal and navigate to the directory containing this README:

```bash
cd scripts/drasi_server/integration/grpc_source_and_reaction

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

The configuration files that drive this test are YAML files and contain extensive comments explaining each section and the options you have to change the test behavior.

## Ports Used

| Port | Service | Direction | Description |
|------|---------|-----------|-------------|
| 8080 | Drasi Server API | Incoming | Health checks, Web API for inspection |
| 50051 | gRPC Source | Incoming | E2ETF → Drasi (data changes) |
| 50052 | gRPC Reaction | Outgoing | Drasi → E2ETF (query results) |
| 63123 | E2E Test Framework API | Incoming | Web API for test control |

## Inspecting Running Tests

Both Drasi Server and the E2E Test Framework expose Web APIs for inspection and control during test execution.

### Drasi Server Web API (Port 8080)

Use the HTTP files in `../../../../utils/drasi_server_web_api/` to interact with Drasi Server.

Open the folder in VS Code and use the REST Client extension to send requests. The four files available are:
- `web_api.http`: General Drasi Server API operations
- `web_aoi_source.http`: Source management operations
- `web_api_query.http`: Query management operations
- `web_api_reaction.http`: Reaction management operations

### E2E Test Service Web API (Optional)

**Note:** This test configuration does not enable the test service Web API. The test runs in automated mode without interactive control.

To enable the Web API for interactive debugging, you would need to add the `--port` flag to the test-service command in `start.sh`:

```bash
cargo run --manifest-path ./test-service/Cargo.toml -- \
    --config "$SCRIPT_DIR/test-service-config.yaml" \
    --data "$SCRIPT_DIR/test_data_store" \
    --port 63123  # Add this to enable Web API
```

Once enabled, you can use the HTTP files in `../../../utils/test_service_web_api/` to interact with the Test Framework for operations like pausing/stepping through data generation, monitoring reactions, and inspecting test state.

See `../../../utils/test_service_web_api/README.md` for detailed API documentation.

## Viewing Test Results

The Test Service generates logs and performance metrics in the `test_data_store/` directory.

### Source Output

The source is configured to log all generated source change events and to calculate performance metrics at the end of the test run.

Source change events are logged to:
```
test_data_store/test_runs/github_dev_repo.building_comfort_grpc.test_run_001/sources/building-comfort-grpc/source_output/source_events_*.log
```

Source performance metrics are saved to:
```
test_data_store/test_runs/github_dev_repo.building_comfort_grpc.test_run_001/sources/building-comfort-grpc/source_output/performance_metrics/performance_metrics_*.json
```

Example metrics:
```json
{
  "actual_end_time": "2025-11-14T00:15:39.350777Z",
  "actual_end_time_ns": 1763079339350777000,
  "actual_start_time": "2025-11-14T00:15:38.277528Z",
  "actual_start_time_ns": 1763079338277528000,
  "num_skipped_source_events": 0,
  "num_source_change_events": 1000,
  "processing_rate": 931.7502275799932,
  "run_duration_ns": 1073249000,
  "run_duration_sec": 1.073249,
  "test_run_source_id": "github_dev_repo.building_comfort_grpc.test_run_001.facilities-db"
}
```

### Reaction Output

The reaction is configured to log all received query result events and to calculate performance metrics at the end of the test run.

Reaction result events are logged to:
```
test_data_store/test_runs/github_dev_repo.building_comfort_grpc.test_run_001/reactions/building-comfort-grpc/reaction_output/reaction_events_*.log
```

Reaction performance metrics are saved to:
```
test_data_store/test_runs/github_dev_repo.building_comfort_grpc.test_run_001/reactions/building-comfort-grpc/reaction_output/performance_metrics/performance_metrics_*.json
```

Example metrics:
```json
{
  "start_time_ns": 1763079339399046000,
  "end_time_ns": 1763079339444751000,
  "duration_ns": 45705000,
  "record_count": 1000,
  "records_per_second": 21879.44426211574,
  "test_run_reaction_id": "github_dev_repo.building_comfort_grpc.test_run_001.building-comfort",
  "timestamp": "2025-11-14T00:15:39.444753Z"
}
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