#!/bin/bash

# Simple Blockchain Test - Validates Kafka optimization in blockchain context

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TEST_NAME="${1:-blockchain-test-$(date +%Y%m%d_%H%M%S)}"
NUM_TRANSACTIONS="${2:-100}"
RESULTS_DIR="results/${TEST_NAME}"

log_info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] SUCCESS:${NC} $1"
}

log_info "=== Simple Blockchain Test ==="
log_info "Test Name: $TEST_NAME"
log_info "Transactions: $NUM_TRANSACTIONS"

mkdir -p "$RESULTS_DIR"

cat > "$RESULTS_DIR/test_metadata.txt" << EOF
Simple Blockchain Test
=====================
Date: $(date -Iseconds)
Test Name: $TEST_NAME
Transactions: $NUM_TRANSACTIONS

Week 3 Optimal Kafka Configuration:
- Batch Size: 65536 bytes (65KB)
- Linger Time: 0 ms
- Compression: none
- Buffer Memory: 67108864 bytes (64MB)

Test Objective:
Validate that the optimal Kafka configuration from Week 3 
maintains performance improvements in a real blockchain context.
