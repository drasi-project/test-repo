# ARN gRPC Adaptive Performance Test

This performance test evaluates Drasi Server's ability to handle high-volume Azure Resource Notifications (ARN) data using adaptive gRPC batching.

## Test Overview

- **Test Type**: Performance test with 1 million events
- **Protocol**: gRPC with adaptive batching
- **Data Source**: Script-based replay from JSONL files
- **Query**: Simple ARN resource query (Room temperature, humidity, CO2)
- **Expected Duration**: Varies based on hardware and batch optimization

## Test Variants

This directory contains four test configurations:

### 1. Azure Storage Blob (Default - Recommended)
Uses Azure Storage with managed identity authentication (no rate limits, fast downloads).

**Config**: `test-service-config.yaml`
**Script**: `start.sh`

```bash
./start.sh
```

**Requirements**:
- Azure Storage account with test data uploaded
- Managed identity with "Storage Blob Data Reader" role
- Run `az login` for local development
- See [Azure Setup](#azure-storage-setup) below

**Advantages**:
- ✅ No rate limits
- ✅ Fast downloads for large datasets (2.5 GB)
- ✅ Secure (uses managed identity, no access keys)
- ✅ Production-ready

### 2. Local Storage
Uses local filesystem for test data (no network required, no rate limits).

**Config**: `test-service-config-local.yaml`
**Script**: `start-local.sh`

```bash
./start-local.sh
```

**Requirements**:
- Test data must be present locally in `test-repo/dev_repo/drasi_server/perf/`

**Advantages**:
- ✅ No network required
- ✅ No authentication setup needed
- ✅ Fastest for repeated local testing

### 3. GitHub Storage
Uses GitHub as the data source (subject to API rate limits).

**Config**: `test-service-config-github.yaml`
**Script**: `start-github.sh`

```bash
# Unauthenticated (60 requests/hour - NOT recommended for large datasets)
./start-github.sh

# Authenticated (5000 requests/hour - recommended)
export GITHUB_TOKEN='ghp_your_personal_access_token'
./start-github.sh
```

**Requirements**:
- Test data uploaded to GitHub repository
- Public repository or GitHub personal access token for authentication

**Authentication Setup**:
To avoid rate limits, create a GitHub personal access token:

1. Go to https://github.com/settings/tokens/new
2. Give it a name like "Drasi E2E Test"
3. Set expiration (e.g., 90 days)
4. Select scopes:
   - **For public repos**: No scopes required (or select `public_repo` if you prefer)
   - **For private repos**: Select `repo` (full control of private repositories)
5. Click "Generate token" and copy the token (starts with `ghp_`)
6. Export it as an environment variable:
   ```bash
   export GITHUB_TOKEN='ghp_your_token_here'
   ```
7. Run the test:
   ```bash
   ./start-github.sh
   ```

**Note**: The token is only used for read-only access to the repository contents. For public repositories like `drasi-project/test-repo`, the token just authenticates your identity to increase the rate limit from 60 to 5000 requests/hour.

**Rate Limits**:
- **Unauthenticated**: 60 requests/hour (will fail for large datasets)
- **Authenticated**: 5000 requests/hour (sufficient for most tests)

**Limitations**:
- ⚠️ Subject to GitHub API rate limits (even when authenticated)
- ⚠️ May fail for very large datasets (1000+ files)
- ⚠️ Slower downloads compared to Azure Storage

**Note**: GitHub storage is provided for compatibility but is **not recommended** for performance testing with large datasets. Use Azure Storage or Local Storage instead.

### 4. Hugging Face Storage
Uses Hugging Face Datasets as the data source (ideal for sharing ML test datasets).

**Config**: `test-service-config-huggingface.yaml`
**Script**: `start-huggingface.sh`

```bash
# Run the test
./start-huggingface.sh
```

**Requirements**:
- Test data uploaded to a Hugging Face dataset
- Public dataset or Hugging Face token for authentication

**Authentication Setup**:
To access private datasets or increase rate limits, create a Hugging Face access token:

1. Go to https://huggingface.co/settings/tokens
2. Click "New token"
3. Give it a name like "Drasi E2E Test"
4. Select token type: "Read" (for read-only access)
5. Click "Generate token" and copy the token (starts with `hf_`)
6. Add the token to `test-service-config-huggingface.yaml`:
   ```yaml
   token: hf_your_token_here
   ```

**Configuration**:
Edit `test-service-config-huggingface.yaml` to point to your dataset:
```yaml
test_repos:
  - id: huggingface_perf_repo
    kind: HuggingFace
    organization: drasi-project       # Your Hugging Face organization
    dataset: drasi-test-data          # Your dataset name
    revision: main                    # Branch/tag (defaults to "main")
    root_path: dev_repo               # Path within dataset
    token: hf_your_token              # Optional token
```

**Advantages**:
- ✅ Good for sharing ML/test datasets publicly
- ✅ Version control with dataset revisions
- ✅ Simple setup for public datasets
- ✅ Integration with ML ecosystem

**Limitations**:
- ⚠️ May have rate limits (check Hugging Face documentation)
- ⚠️ Network-dependent performance
- ⚠️ For large datasets, Azure Storage or Local Storage may be faster

**Note**: Hugging Face storage is ideal for sharing test datasets in ML contexts but may not be optimal for very large datasets. Use Azure Storage for production performance testing.

## Prerequisites

### All Test Variants

1. **Rust toolchain** installed
2. **Homebrew dependencies**:
   ```bash
   brew install jq oniguruma rocksdb
   ```

3. **Environment variables** in `~/.zshrc`:
   ```bash
   export JQ_LIB_DIR=/opt/homebrew/opt/jq/lib
   export LIBONIG_LIB_DIR=/opt/homebrew/opt/oniguruma/lib
   export ROCKSDB_LIB_DIR=/opt/homebrew/opt/rocksdb/lib
   export RUSTFLAGS="-L /opt/homebrew/opt/jq/lib -L /opt/homebrew/opt/oniguruma/lib"
   ```

4. **Build the test framework**:
   ```bash
   cd drasi-test-infra/e2e-test-framework
   ROCKSDB_LIB_DIR=/opt/homebrew/opt/rocksdb/lib cargo build --release
   ```

5. **Available ports**: 8080 (Drasi API), 50051 (gRPC Source), 50052 (gRPC Reaction)

## Azure Storage Setup

### 1. Create Azure Storage Account
```bash
# Create resource group (if needed)
az group create --name drasi-test-rg --location eastus

# Create storage account
az storage account create \
  --name drasidev \
  --resource-group drasi-test-rg \
  --location eastus \
  --sku Standard_LRS
```

### 2. Create Container and Upload Test Data
```bash
# Create container
az storage container create \
  --account-name drasidev \
  --name e2etests \
  --auth-mode login

# Upload test definition
az storage blob upload \
  --account-name drasidev \
  --container-name e2etests \
  --name dev_repo/arn_inline_grpc_adaptive.test \
  --file test-repo/dev_repo/drasi_server/perf/arn_inline_grpc_adaptive.test \
  --auth-mode login

# Upload test data (2.5 GB, ~1000 files)
az storage blob upload-batch \
  --account-name drasidev \
  --destination e2etests \
  --destination-path dev_repo/arn_inline \
  --source test-repo/dev_repo/drasi_server/perf/arn_inline \
  --auth-mode login \
  --overwrite
```

### 3. Configure Authentication

#### For Local Development:
```bash
# Login with Azure CLI
az login

# Grant yourself "Storage Blob Data Reader" role
az role assignment create \
  --role "Storage Blob Data Reader" \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --scope /subscriptions/<subscription-id>/resourceGroups/drasi-test-rg/providers/Microsoft.Storage/storageAccounts/drasidev
```

#### For CI/CD or Azure VMs:
Create a managed identity and assign the "Storage Blob Data Reader" role:

```bash
# Create user-assigned managed identity
az identity create \
  --name drasi-test-identity \
  --resource-group drasi-test-rg

# Get the principal ID
PRINCIPAL_ID=$(az identity show \
  --name drasi-test-identity \
  --resource-group drasi-test-rg \
  --query principalId -o tsv)

# Assign role
az role assignment create \
  --role "Storage Blob Data Reader" \
  --assignee $PRINCIPAL_ID \
  --scope /subscriptions/<subscription-id>/resourceGroups/drasi-test-rg/providers/Microsoft.Storage/storageAccounts/drasidev
```

### 4. Update Configuration
Edit `test-service-config-azure.yaml`:
```yaml
account_name: drasidev           # Your storage account name
container: e2etests              # Your container name
root_path: dev_repo              # Path prefix (no trailing slash!)
```

## Running the Tests

### Quick Start (Azure Storage - Default)
```bash
# Navigate to test directory
cd test-repo/scripts/drasi_server_arn/perf/grpc_adaptive_source_and_reaction

# Ensure you're authenticated
az login

# Run the test
./start.sh
```

### Alternative (Local Storage)
```bash
# Run the test with local data
./start-local.sh
```

## Test Configuration

### Build Mode
All scripts use **release mode** for optimal performance:
- Drasi Server: `cargo build --release`
- Test Framework: `cargo run --release`

### Logging Level
Set to **INFO** level to reduce log size while maintaining visibility:
- Drasi Server: `RUST_LOG=info`
- Test Framework: `RUST_LOG=info`

### Performance Metrics
The test only collects **PerformanceMetrics** (no JSONL output logging):
- Throughput (events/second)
- Latency percentiles (p50, p95, p99)
- Total duration

## Output and Logs

After the test completes, check the logs:

```bash
# Drasi Server logs
tail -50 drasi-server.log

# Test Service logs (includes performance metrics)
tail -100 test-service.log

# Search for performance metrics
grep -i "performance\|throughput\|latency" test-service.log
```

## Cleanup

Stop any running processes:
```bash
./stop.sh
```

Or manually:
```bash
# Kill Drasi Server
pkill -f drasi-server

# Kill Test Service
pkill -f test-service

# Free ports if needed
lsof -ti:8080 | xargs kill -9
lsof -ti:50051 | xargs kill -9
lsof -ti:50052 | xargs kill -9
```

## Troubleshooting

### Error: "could not find native static library `rocksdb`"
```bash
export ROCKSDB_LIB_DIR=/opt/homebrew/opt/rocksdb/lib
cargo build --release
```

### Error: "Port already in use"
```bash
./stop.sh
# Or manually kill processes on the ports
lsof -ti:8080 | xargs kill -9
```

### Error: "Azure Storage authentication failed"
```bash
# Re-login to Azure
az login

# Verify your role assignment
az role assignment list \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --scope /subscriptions/<subscription-id>/resourceGroups/drasi-test-rg/providers/Microsoft.Storage/storageAccounts/drasidev
```

### Error: "Script is missing Header record"
The JSONL files in Azure Storage are missing the required header line. Re-upload:
```bash
az storage blob upload-batch \
  --account-name drasidev \
  --destination e2etests \
  --destination-path dev_repo/arn_inline \
  --source test-repo/dev_repo/drasi_server/perf/arn_inline \
  --auth-mode login \
  --overwrite
```

### Error: "Blob name does not start with expected prefix"
The `root_path` in `test-service-config-azure.yaml` has a trailing slash. Remove it:
```yaml
root_path: dev_repo  # Correct (no trailing slash)
# NOT: dev_repo/     # Wrong (trailing slash causes double slash)
```

## Test Data Structure

The test expects the following structure in Azure Storage:

```
e2etests/                                          (container)
└── dev_repo/
    ├── arn_inline_grpc_adaptive.test              (test definition)
    └── arn_inline/                                (test data folder)
        └── sources/
            └── arn-db/
                ├── bootstrap_scripts/
                │   └── arn_resources/
                │       └── arn_resources_00000.jsonl
                └── source_change_scripts/
                    ├── source_change_scripts_00000.jsonl
                    ├── source_change_scripts_00001.jsonl
                    └── ... (up to source_change_scripts_01000.jsonl)
```

Each JSONL file must start with a header line:
```json
{"kind":"Header","start_time":"2025-11-25T18:13:39.863059Z","description":"Drasi Source Change Script for TestID small-test, SourceID: arn-events"}
```

## Performance Expectations

Typical results on modern hardware:
- **Throughput**: 10,000-50,000 events/second (varies with adaptive batching)
- **Total Duration**: 20-100 seconds for 1 million events
- **Memory Usage**: 2-4 GB peak

Actual performance depends on:
- CPU cores and speed
- Available memory
- Network latency (for Azure Storage downloads)
- Adaptive batch optimization convergence

## Architecture

```
┌─────────────────────┐
│  Azure Storage      │
│  (Test Data)        │
└──────────┬──────────┘
           │ Download JSONL files
           ▼
┌─────────────────────┐
│  Test Service       │
│  - Reads test def   │
│  - Replays events   │
│  - Sends to Drasi   │
└──────────┬──────────┘
           │ gRPC (port 50051)
           │ Adaptive batching
           ▼
┌─────────────────────┐
│  Drasi Server       │
│  - Processes events │
│  - Runs query       │
│  - Sends results    │
└──────────┬──────────┘
           │ gRPC (port 50052)
           │ Query results
           ▼
┌─────────────────────┐
│  Test Service       │
│  - Receives results │
│  - Logs metrics     │
│  - Stops at 1M      │
└─────────────────────┘
```

## Contributing

When making changes to this test:

1. Test locally first with `start-local.sh`
2. Verify Azure Storage integration with `start-azure.sh`
3. Update this README if configuration changes
4. Commit changes to the `arn-test` branch
5. Create a pull request to the main repository

## References

- [Drasi Documentation](https://drasi.io/)
- [E2E Test Framework](../../../../drasi-test-infra/e2e-test-framework/README.md)
- [Azure Storage Blob Documentation](https://learn.microsoft.com/en-us/azure/storage/blobs/)
- [Managed Identity Documentation](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview)
