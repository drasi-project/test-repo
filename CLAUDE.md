# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a test configuration repository for Drasi E2E testing. It contains test data, configuration files, and integration test scripts for the Drasi continuous query processing system. The repository does not contain application source code, but rather test definitions and orchestration scripts.

## Repository Structure

- `dev_repo/`: Test configuration files (JSON) defining building comfort model tests
  - Test files use `.test.json` extension
  - Define sources, queries, reactions, and data generators for E2E tests

- `scripts/drasi_server/integration/`: Integration test orchestration scripts
  - Contains bash scripts to start/stop Drasi server for testing
  - Includes server configuration (YAML) and E2E test framework configuration (JSON)

## Test Configuration Format

Test files in `dev_repo/` follow this structure:

```json
{
  "version": 1,
  "description": "Test description",
  "test_folder": "folder_name",
  "queries": [...],
  "sources": [...],
  "reactions": [...]
}
```

### Key Configuration Elements

**Sources**: Define data generators (e.g., BuildingHierarchy model)
- `model_data_generator`: Configures synthetic data generation
  - `building_count`, `floor_count`, `room_count`: [count, variance]
  - `change_count`: Total number of change events to generate
  - `change_interval`: Timing between changes in nanoseconds [array of intervals]
  - `room_sensors`: Array of sensor definitions (temperature, co2, humidity)
  - `seed`: Random seed for reproducibility

**Queries**: Define result handling and stop triggers
- `result_stream_handler`: Where query results are sent (e.g., RedisStream)
- `stop_trigger`: When to stop the test (RecordSequenceNumber or RecordCount)

**source_change_dispatchers**: How changes are delivered to Drasi
- `Dapr`: For Dapr pubsub integration
- `Grpc`: For gRPC source integration

## Running Integration Tests

### gRPC Source and Reaction Test

Located in `scripts/drasi_server/integration/grpc_source_and_reaction/`:

**Start test:**
```bash
./scripts/drasi_server/integration/grpc_source_and_reaction/start.sh
```

This script:
1. Builds drasi-server from `../../drasi-server` (debug mode)
2. Starts drasi-server with `server-config.yaml`
3. Waits for health check on port 8080
4. Runs E2E test framework with `e2etf-config.json`
5. Logs output to `drasi-server-debug.log`

**Stop test:**
```bash
./scripts/drasi_server/integration/grpc_source_and_reaction/stop.sh
```

Cleans up processes and ports (8080, 50051, 50052).

### Test Ports

- 8080: Drasi Server API
- 50051: gRPC source endpoint
- 50052: gRPC reaction endpoint

## Important Path Relationships

The integration test scripts assume this repository structure:
```
parent/
  drasi-server/          # Main Drasi server codebase
  e2e-test-framework/    # E2E test framework
    test-service/        # Test service Cargo project
  drasi-test-repo/       # This repository
```

The `start.sh` script navigates relative to this structure (`../../drasi-server`).

## Modifying Test Configurations

When creating or modifying test files:

1. Set appropriate `change_count` and `change_interval` values for test duration
2. Use `building_comfort_small.test.json` as a template for smaller/faster tests (100 changes, 1 building, 1 floor, 5 rooms)
3. Use `building_comfort.test.json` for larger tests (100,000 changes, 10x10x10 hierarchy)
4. Adjust `stop_trigger` values to match expected result counts
5. Ensure `seed` values are set for reproducible test runs

## Server Configuration

The `server-config.yaml` defines:
- Sources (type, port, host)
- Queries (Cypher query language, linked to sources)
- Reactions (endpoints, batch size, timeout)

All three elements can be auto-started or manually controlled.
