#!/bin/bash
# Week 2.5: Single Parameter Testing
# Isolate effect of each parameter individually

set -e
export MSYS_NO_PATHCONV=1

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       WEEK 2.5: SINGLE PARAMETER TESTING              ║${NC}"
echo -e "${BLUE}║   Systematic isolation of parameter effects           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_BASE="results/week2.5_single_param_${TIMESTAMP}"
mkdir -p "$RESULTS_BASE"

NUM_TRANSACTIONS=5000

echo -e "${YELLOW}Configuration:${NC}"
echo "  Tests: 3 parameter progressions"
echo "  Transactions per test: ${NUM_TRANSACTIONS}"
echo "  Results directory: ${RESULTS_BASE}"
echo ""

# Function to run test
run_test() {
    local test_name=$1
    local batch_size=$2
    local linger_ms=$3
    local compression=$4
    local description=$5
    
    echo -e "\n${YELLOW}▶ Test: ${test_name}${NC}"
    echo "  ${description}"
    echo "  Config: batch=${batch_size}, linger=${linger_ms}ms, compression=${compression}"
    
    # Create test directory in results/
    local test_dir="${RESULTS_BASE}/${test_name}"
    mkdir -p "$test_dir"
    
    # Start monitoring - save to test directory
    ./scripts/monitoring/enhanced-stats.sh "${test_dir}/enhanced-stats.csv" 60 &
    STATS_PID=$!
    
    # Run test
    docker-compose exec -T test-runner python3 /scripts/blockchain/run-blockchain-benchmark.py \
        --config "${test_name}" \
        --batch-size ${batch_size} \
        --linger-ms ${linger_ms} \
        --compression "${compression}" \
        --transactions ${NUM_TRANSACTIONS} \
        2>&1 | tee "${test_dir}/output.log"
    
    # Stop monitoring
    kill $STATS_PID 2>/dev/null || true
    wait $STATS_PID 2>/dev/null || true
    echo "  Stopped stats collection"
    
    # Find and copy result JSON (with wildcard pattern)
    echo "  Looking for result file..."
    
    # List files in container to debug
    docker-compose exec -T test-runner ls -la /results/ | grep "${test_name}" || echo "  No files found matching ${test_name}"
    
    # Try to find the JSON file with timestamp
    RESULT_FILE=$(docker-compose exec -T test-runner sh -c "ls /results/blockchain_${test_name}_*.json 2>/dev/null | head -1" | tr -d '\r')
    
    if [ -n "$RESULT_FILE" ] && [ "$RESULT_FILE" != "" ]; then
        echo "  Found: $RESULT_FILE"
        
        # Copy with simplified name
        docker cp "test-runner:${RESULT_FILE}" "${test_dir}/${test_name}_result.json"
        
        if [ -f "${test_dir}/${test_name}_result.json" ]; then
            echo -e "${GREEN}✓ Test completed successfully${NC}"
            echo -e "  Result: ${test_dir}/${test_name}_result.json"
            
            # Clean up container
            docker-compose exec -T test-runner rm -f "${RESULT_FILE}" 2>/dev/null || true
        else
            echo -e "${RED}✗ Failed to copy result file${NC}"
        fi
    else
        echo -e "${RED}✗ No result file found in container${NC}"
        echo "  Expected pattern: /results/blockchain_${test_name}_*.json"
    fi
    
    sleep 5
}

echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}SERIES 1: BATCH SIZE PROGRESSION${NC}"
echo -e "${BLUE}(Keeping linger=0ms, compression=none constant)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

run_test "batch_16kb" 16384 0 "none" "Baseline: Default batch size"
run_test "batch_32kb" 32768 0 "none" "2x batch: Double default"
run_test "batch_65kb" 65536 0 "none" "4x batch: Moderate increase"
run_test "batch_131kb" 131072 0 "none" "8x batch: Maximum tested"

echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}SERIES 2: LINGER TIME PROGRESSION${NC}"
echo -e "${BLUE}(Keeping batch=65KB, compression=none constant)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

run_test "linger_0ms" 65536 0 "none" "Baseline: Immediate send"
run_test "linger_5ms" 65536 5 "none" "Short wait: 5ms batching window"
run_test "linger_10ms" 65536 10 "none" "Moderate wait: 10ms window"
run_test "linger_25ms" 65536 25 "none" "Long wait: 25ms window"

echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}SERIES 3: COMPRESSION COMPARISON${NC}"
echo -e "${BLUE}(Keeping batch=65KB, linger=10ms constant)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

run_test "compression_none" 65536 10 "none" "Baseline: No compression"
run_test "compression_lz4" 65536 10 "lz4" "Fast compression: LZ4"
run_test "compression_snappy" 65536 10 "snappy" "Google compression: Snappy"

# Create summary index
cat > "${RESULTS_BASE}/INDEX.md" << EOF
# Week 2.5 Single Parameter Tests - Results Index

**Generated**: $(date)
**Total Tests**: 11
**Results Directory**: ${RESULTS_BASE}

## Test Structure

\`\`\`
${RESULTS_BASE}/
├── batch_16kb/
│   ├── output.log
│   ├── enhanced-stats.csv
│   └── batch_16kb_result.json
├── batch_32kb/
├── batch_65kb/
├── batch_131kb/
├── linger_0ms/
├── linger_5ms/
├── linger_10ms/
├── linger_25ms/
├── compression_none/
├── compression_lz4/
├── compression_snappy/
└── analysis/ (generated after running analyze script)
\`\`\`

## Test Series

### Series 1: Batch Size Progression
- batch_16kb (baseline: 16KB, 0ms, none)
- batch_32kb (32KB, 0ms, none)
- batch_65kb (65KB, 0ms, none)
- batch_131kb (128KB, 0ms, none)

### Series 2: Linger Time Progression
- linger_0ms (65KB, 0ms, none)
- linger_5ms (65KB, 5ms, none)
- linger_10ms (65KB, 10ms, none)
- linger_25ms (65KB, 25ms, none)

### Series 3: Compression Comparison
- compression_none (65KB, 10ms, none)
- compression_lz4 (65KB, 10ms, lz4)
- compression_snappy (65KB, 10ms, snappy)

## Analysis

Run analysis with:
\`\`\`bash
python3 analyze_single_param_results.py ${RESULTS_BASE}
\`\`\`

Analysis output will be saved in: ${RESULTS_BASE}/analysis/
EOF

echo -e "\n${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       SINGLE PARAMETER TESTS COMPLETE                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"

echo -e "\nResults directory: ${YELLOW}${RESULTS_BASE}${NC}"
echo -e "Index file: ${YELLOW}${RESULTS_BASE}/INDEX.md${NC}"

# Count successful tests
SUCCESS_COUNT=$(find "$RESULTS_BASE" -name "*_result.json" 2>/dev/null | wc -l)
echo -e "\nSuccessful tests: ${GREEN}${SUCCESS_COUNT}/11${NC}"

if [ "$SUCCESS_COUNT" -eq 11 ]; then
    echo -e "${GREEN}✓ All tests completed successfully!${NC}"
else
    echo -e "${YELLOW}⚠ Some tests may have failed. Check individual directories.${NC}"
fi

echo -e "\nNext: Run analysis"
echo -e "${CYAN}python3 analyze_single_param_results.py ./${RESULTS_BASE}${NC}"