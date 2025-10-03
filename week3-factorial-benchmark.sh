#!/bin/bash
# Week 3 Factorial Design 2³ Benchmark
# Systematic parameter optimization with ANOVA analysis

set -e
export MSYS_NO_PATHCONV=1

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         WEEK 3 FACTORIAL DESIGN BENCHMARK             ║${NC}"
echo -e "${BLUE}║              2³ Design with ANOVA                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_BASE="results/week3_factorial_design_${TIMESTAMP}"
mkdir -p "$RESULTS_BASE"

NUM_TRANSACTIONS=5000
REPLICATIONS=5

echo -e "${YELLOW}Configuration:${NC}"
echo "  Design: 2³ Full Factorial"
echo "  Configurations: 8"
echo "  Replications: ${REPLICATIONS}"
echo "  Total tests: 24"
echo "  Transactions per test: ${NUM_TRANSACTIONS}"
echo "  Results directory: ${RESULTS_BASE}"
echo ""

# Factorial design configurations
declare -A CONFIGS=(
    ["config_1"]="16384 0 none"
    ["config_2"]="16384 0 lz4"
    ["config_3"]="16384 25 none"
    ["config_4"]="16384 25 lz4"
    ["config_5"]="131072 0 none"
    ["config_6"]="131072 0 lz4"
    ["config_7"]="131072 25 none"
    ["config_8"]="131072 25 lz4"
)

# Function to run single test
run_factorial_test() {
    local config_name=$1
    local batch_size=$2
    local linger_ms=$3
    local compression=$4
    local replication=$5
    
    local test_name="${config_name}_rep${replication}"
    
    echo -e "\n${CYAN}▶ Testing: ${test_name}${NC}"
    echo "  Batch: ${batch_size}, Linger: ${linger_ms}ms, Compression: ${compression}"
    
    # Create test directory in results/
    local test_dir="${RESULTS_BASE}/${test_name}"
    mkdir -p "$test_dir"
    
    # Start resource monitoring
    ./scripts/monitoring/enhanced-stats.sh "${test_dir}/enhanced-stats.csv" 60 &
    STATS_PID=$!
    
    # Run blockchain benchmark
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
    
    # Find and copy result JSON
    echo "  Looking for result file..."
    
    RESULT_FILE=$(docker-compose exec -T test-runner sh -c "ls /results/blockchain_${test_name}_*.json 2>/dev/null | head -1" | tr -d '\r')
    
    if [ -n "$RESULT_FILE" ] && [ "$RESULT_FILE" != "" ]; then
        echo "  Found: $RESULT_FILE"
        
        # Copy with simplified name
        docker cp "test-runner:${RESULT_FILE}" "${test_dir}/${test_name}_result.json"
        
        if [ -f "${test_dir}/${test_name}_result.json" ]; then
            echo -e "${GREEN}✓ Test completed: ${test_name}${NC}"
            
            # Clean up container
            docker-compose exec -T test-runner rm -f "${RESULT_FILE}" 2>/dev/null || true
        else
            echo -e "${RED}✗ Failed to copy result file${NC}"
        fi
    else
        echo -e "${RED}✗ No result file found${NC}"
    fi
    
    sleep 5
}

# Main execution loop
echo -e "\n${BLUE}Starting factorial design execution...${NC}\n"

test_count=1
total_tests=$((${#CONFIGS[@]} * REPLICATIONS))

for config_name in config_1 config_2 config_3 config_4 config_5 config_6 config_7 config_8; do
    IFS=' ' read -r batch_size linger_ms compression <<< "${CONFIGS[$config_name]}"
    
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Configuration: ${config_name}${NC}"
    echo -e "${YELLOW}  Batch Size: ${batch_size}"
    echo -e "${YELLOW}  Linger MS: ${linger_ms}"
    echo -e "${YELLOW}  Compression: ${compression}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    
    # Run replications
    for rep in $(seq 1 $REPLICATIONS); do
        echo -e "${BLUE}[Test ${test_count}/${total_tests}] Replication ${rep}/${REPLICATIONS}${NC}"
        run_factorial_test "$config_name" "$batch_size" "$linger_ms" "$compression" "$rep"
        ((test_count++))
    done
done

# Create design matrix
cat > "${RESULTS_BASE}/DESIGN_MATRIX.md" << 'EOF'
# Week 3 Factorial Design 2³ - Design Matrix

**Generated**: $(date)

## Factorial Design Matrix

| Config | A: Batch | B: Linger | C: Compression | Coded | Replications |
|--------|----------|-----------|----------------|-------|--------------|
| config_1 | 16KB | 0ms | none | (-, -, -) | rep1, rep2, rep3 |
| config_2 | 16KB | 0ms | lz4 | (-, -, +) | rep1, rep2, rep3 |
| config_3 | 16KB | 25ms | none | (-, +, -) | rep1, rep2, rep3 |
| config_4 | 16KB | 25ms | lz4 | (-, +, +) | rep1, rep2, rep3 |
| config_5 | 128KB | 0ms | none | (+, -, -) | rep1, rep2, rep3 |
| config_6 | 128KB | 0ms | lz4 | (+, -, +) | rep1, rep2, rep3 |
| config_7 | 128KB | 25ms | none | (+, +, -) | rep1, rep2, rep3 |
| config_8 | 128KB | 25ms | lz4 | (+, +, +) | rep1, rep2, rep3 |

## Analysis

Run ANOVA with:
```bash
python3 analyze_factorial_results.py ./results/week3_factorial_design_*/
EOF

echo -e "\n${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       FACTORIAL DESIGN COMPLETE                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"

echo -e "\nResults directory: ${YELLOW}${RESULTS_BASE}${NC}"

# Count successful tests
SUCCESS_COUNT=$(find "$RESULTS_BASE" -name "*_result.json" 2>/dev/null | wc -l)
echo -e "\nSuccessful tests: ${GREEN}${SUCCESS_COUNT}/24${NC}"

if [ "$SUCCESS_COUNT" -eq 24 ]; then
    echo -e "${GREEN}✓ All tests completed successfully!${NC}"
else
    echo -e "${YELLOW}⚠ Some tests may have failed. Check individual directories.${NC}"
fi

echo -e "\nNext: Run ANOVA analysis"
echo -e "${CYAN}python3 analyze_factorial_results.py ./${RESULTS_BASE}${NC}"