#!/bin/bash

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Drasi Server Test - gRPC (Debug Mode)${NC}"
echo "================================================"

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if required ports are available
echo -e "${YELLOW}Checking port availability...${NC}"
PORTS_IN_USE=()

if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    PORTS_IN_USE+=("8080 (Drasi Server API)")
fi

if lsof -Pi :50051 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    PORTS_IN_USE+=("50051 (gRPC Source)")
fi

if lsof -Pi :50052 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    PORTS_IN_USE+=("50052 (gRPC Reaction)")
fi

if [ ${#PORTS_IN_USE[@]} -gt 0 ]; then
    echo -e "${RED}Error: The following required ports are already in use:${NC}"
    for port in "${PORTS_IN_USE[@]}"; do
        echo -e "${RED}  - Port $port${NC}"
    done
    echo ""
    echo -e "${YELLOW}Please stop the processes using these ports or run:${NC}"
    echo -e "${YELLOW}  ./stop.sh${NC}"
    echo ""
    echo -e "${YELLOW}To manually free the ports:${NC}"
    for port_info in "${PORTS_IN_USE[@]}"; do
        port=$(echo "$port_info" | cut -d' ' -f1)
        echo -e "${YELLOW}  lsof -ti:$port | xargs kill -9${NC}"
    done
    exit 1
fi

echo -e "${GREEN}All required ports are available${NC}"

# Navigate to drasi-server using relative path from script directory
DRASI_SERVER_DIR="$SCRIPT_DIR/../../../../../drasi-server"
if [ ! -d "$DRASI_SERVER_DIR" ]; then
    echo -e "${RED}Error: Drasi Server directory not found at $DRASI_SERVER_DIR${NC}"
    echo -e "${RED}Expected path: $DRASI_SERVER_DIR${NC}"
    exit 1
fi
DRASI_SERVER_DIR="$( cd "$DRASI_SERVER_DIR" && pwd )"
echo -e "${GREEN}Found Drasi Server at: $DRASI_SERVER_DIR${NC}"

# Navigate to e2e-test-framework using relative path from script directory
E2E_ROOT="$SCRIPT_DIR/../../../../../drasi-test-infra/e2e-test-framework"
if [ ! -d "$E2E_ROOT" ]; then
    echo -e "${RED}Error: E2E Test Framework directory not found at $E2E_ROOT${NC}"
    echo -e "${RED}Expected path: $E2E_ROOT${NC}"
    exit 1
fi
E2E_ROOT="$( cd "$E2E_ROOT" && pwd )"
echo -e "${GREEN}Found E2E Test Framework at: $E2E_ROOT${NC}"

# Kill any existing processes
echo -e "${YELLOW}Cleaning up any existing processes...${NC}"
pkill -f "drasi-server" 2>/dev/null || true
pkill -f "test-service.*building_comfort.*drasi_server_grpc" 2>/dev/null || true
sleep 2

# Build Drasi Server in debug mode
echo -e "${YELLOW}Building Drasi Server (Debug)...${NC}"
cd "$DRASI_SERVER_DIR"
cargo build

# Use the permanent server config file
CONFIG_FILE="$SCRIPT_DIR/drasi-server-config.yaml"

# Remove old log files if they exist
LOG_FILE="$SCRIPT_DIR/drasi-server.log"
if [ -f "$LOG_FILE" ]; then
    echo -e "${YELLOW}Removing old drasi-server log file...${NC}"
    rm "$LOG_FILE"
fi

TEST_SERVICE_LOG="$SCRIPT_DIR/test-service.log"
if [ -f "$TEST_SERVICE_LOG" ]; then
    echo -e "${YELLOW}Removing old test-service log file...${NC}"
    rm "$TEST_SERVICE_LOG"
fi

# Start Drasi Server in background with debug logging
echo -e "${YELLOW}Starting Drasi Server with debug logging...${NC}"
RUST_LOG=debug ./target/debug/drasi-server --config "$CONFIG_FILE" > "$LOG_FILE" 2>&1 &
DRASI_PID=$!
echo "Drasi Server PID: $DRASI_PID"
echo "Drasi Server log: $LOG_FILE"

# Wait for server to be ready
echo -e "${YELLOW}Waiting for Drasi Server to be ready...${NC}"
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -s -f http://localhost:8080/health > /dev/null 2>&1; then
        echo -e "${GREEN}Drasi Server is ready!${NC}"
        break
    fi
    echo -n "."
    sleep 1
    ATTEMPT=$((ATTEMPT + 1))
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo -e "${RED}Error: Drasi Server failed to start after 30 seconds${NC}"
    echo "Last 50 lines of server log:"
    tail -50 "$LOG_FILE"
    kill $DRASI_PID 2>/dev/null || true
    exit 1
fi

# Wait a bit more for gRPC source to be fully ready
sleep 2

# Run the E2E test with filtered logging and capture output
echo -e "${YELLOW}Starting E2E Test Framework (Filtered Debug)...${NC}"
echo "Test Service log: $TEST_SERVICE_LOG"
cd "$E2E_ROOT"
RUST_LOG=info,data_collector=debug,test_run_host=debug,test_data_store=debug,test_service=debug cargo run --manifest-path ./test-service/Cargo.toml -- \
    --config "$SCRIPT_DIR/test-service-config.yaml" \
    --data "$SCRIPT_DIR/test_data_store" > "$TEST_SERVICE_LOG" 2>&1

TEST_EXIT_CODE=$?

# Clean up
echo -e "${YELLOW}Cleaning up...${NC}"
kill $DRASI_PID 2>/dev/null || true
wait $DRASI_PID 2>/dev/null || true

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}Test completed successfully!${NC}"
else
    echo -e "${RED}Test failed with exit code: $TEST_EXIT_CODE${NC}"
    echo "Check the logs at:"
    echo "  - Drasi Server: $LOG_FILE"
    echo "  - Test Service: $TEST_SERVICE_LOG"
fi

exit $TEST_EXIT_CODE