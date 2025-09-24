#!/bin/bash

# Simplified Kafka Performance Testing Script
# Tests Kafka optimization parameters without blockchain complexity

set -e

# Configuration
ENV_FILE="${1:-.env.default}"
TEST_NAME="${2:-$(date +%Y%m%d_%H%M%S)}"
DURATION="${3:-300}"  # 5 minutes default
TPS="${4:-1000}"      # Target transactions per second

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Simplified Kafka Performance Test ===${NC}"
echo -e "Test Name: ${TEST_NAME}"
echo -e "Environment: ${ENV_FILE}"
echo -e "Duration: ${DURATION}s"
echo -e "Target TPS: ${TPS}"
echo

# Create results directory
RESULTS_DIR="results/${TEST_NAME}"
mkdir -p "${RESULTS_DIR}"

# Load environment - FIXED to handle comments properly
if [ -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}Loading environment from ${ENV_FILE}...${NC}"
    # Export only lines that don't start with # and contain =
    set -a
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -n "$line" && "$line" != \#* && "$line" == *=* ]]; then
            export "$line"
        fi
    done < "$ENV_FILE"
    set +a
    cp "$ENV_FILE" "${RESULTS_DIR}/config-used.env"
else
    echo -e "${RED}Environment file ${ENV_FILE} not found!${NC}"
    exit 1
fi

# Verify required variables are loaded
if [[ -z "${KAFKA_BATCH_SIZE:-}" ]]; then
    echo -e "${RED}Error: KAFKA_BATCH_SIZE not found in ${ENV_FILE}${NC}"
    exit 1
fi

echo -e "${GREEN}Configuration loaded successfully:${NC}"
echo "  KAFKA_BATCH_SIZE: ${KAFKA_BATCH_SIZE}"
echo "  KAFKA_LINGER_MS: ${KAFKA_LINGER_MS:-0}"
echo "  KAFKA_COMPRESSION_TYPE: ${KAFKA_COMPRESSION_TYPE:-none}"
echo "  KAFKA_BUFFER_MEMORY: ${KAFKA_BUFFER_MEMORY:-33554432}"

# Function to check if service is ready using Docker health checks
wait_for_service() {
    local service=$1
    local port=$2
    local max_attempts=30
    local attempt=1
    
    echo -n "Waiting for ${service}:${port} to be ready..."
    while [ $attempt -le $max_attempts ]; do
        # Use Docker health check instead of nc
        if docker-compose ps $service | grep -q "healthy\|Up"; then
            echo -e " ${GREEN}✓${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    echo -e " ${RED}✗${NC}"
    return 1
}

# Enhanced service readiness check using Docker commands
check_kafka_ready() {
    local max_attempts=60
    local attempt=1
    
    echo -n "Checking Kafka readiness..."
    while [ $attempt -le $max_attempts ]; do
        # Check if Kafka container is healthy first
        if docker-compose ps kafka | grep -q "healthy"; then
            # Then test Kafka functionality
            if docker-compose exec -T kafka kafka-topics --list --bootstrap-server localhost:9092 >/dev/null 2>&1; then
                echo -e " ${GREEN}✓${NC}"
                return 0
            fi
        fi
        echo -n "."
        sleep 3
        attempt=$((attempt + 1))
    done
    echo -e " ${RED}✗${NC}"
    return 1
}

# Robust environment startup with improved logic
start_environment() {
    local max_retries=3
    local retry=1
    
    while [ $retry -le $max_retries ]; do
        echo -e "${YELLOW}Starting Kafka environment (attempt $retry/$max_retries)...${NC}"
        
        # Clean shutdown first
        docker-compose down -v >/dev/null 2>&1
        sleep 5
        
        # Start services
        docker-compose up -d
        
        # Wait for containers to start
        sleep 20
        
        # Check services using Docker status instead of network tools
        echo -e "${YELLOW}Checking container health...${NC}"
        if wait_for_service "zookeeper" 2181; then
            echo -e "${GREEN}Zookeeper container ready${NC}"
            
            if wait_for_service "kafka" 9092; then
                echo -e "${GREEN}Kafka container ready${NC}"
                
                # Additional wait for Kafka internal initialization
                echo -e "${YELLOW}Waiting for Kafka internal initialization...${NC}"
                sleep 30
                
                # Test actual Kafka functionality
                if check_kafka_ready; then
                    echo -e "${GREEN}Kafka fully operational${NC}"
                    return 0
                else
                    echo -e "${RED}Kafka commands not responding${NC}"
                fi
            else
                echo -e "${RED}Kafka container not healthy${NC}"
            fi
        else
            echo -e "${RED}Zookeeper container not healthy${NC}"
        fi
        
        # Show detailed container status for debugging
        echo -e "${YELLOW}Detailed container status:${NC}"
        docker-compose ps
        echo ""
        echo -e "${YELLOW}Container health checks:${NC}"
        docker-compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"
        
        if [ $retry -lt $max_retries ]; then
            echo -e "${YELLOW}Retrying in 10 seconds...${NC}"
            sleep 10
        fi
        
        retry=$((retry + 1))
    done
    
    echo -e "${RED}Failed to start environment after $max_retries attempts${NC}"
    echo -e "${RED}Debug information:${NC}"
    echo ""
    echo "=== Container Status ==="
    docker-compose ps
    echo ""
    echo "=== Recent Kafka Logs ==="
    docker-compose logs --tail=20 kafka
    echo ""
    echo "=== Recent Zookeeper Logs ==="
    docker-compose logs --tail=10 zookeeper
    echo ""
    return 1
}

# Check if environment is already running and healthy
echo -e "${YELLOW}Checking existing environment...${NC}"
if docker-compose ps | grep -q "Up" && docker-compose ps kafka | grep -q "healthy"; then
    if check_kafka_ready; then
        echo -e "${GREEN}Using existing healthy Docker environment${NC}"
    else
        echo -e "${YELLOW}Existing environment not fully ready, restarting...${NC}"
        if ! start_environment; then
            echo -e "${RED}Environment startup failed. Exiting.${NC}"
            exit 1
        fi
    fi
else
    if ! start_environment; then
        echo -e "${RED}Environment startup failed. Exiting.${NC}"
        exit 1
    fi
fi

# Create test topic with retry logic
create_test_topic() {
    local max_attempts=5
    local attempt=1
    
    echo -e "${YELLOW}Creating test topic...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose exec -T kafka kafka-topics --create \
            --topic blockchain-simulation \
            --bootstrap-server localhost:9092 \
            --partitions 3 \
            --replication-factor 1 \
            --if-not-exists >/dev/null 2>&1; then
            echo -e "${GREEN}Test topic created successfully${NC}"
            return 0
        fi
        
        echo -n "Topic creation attempt $attempt/$max_attempts..."
        if [ $attempt -lt $max_attempts ]; then
            echo " retrying in 5 seconds"
            sleep 5
        else
            echo " failed"
        fi
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}Failed to create test topic after $max_attempts attempts${NC}"
    return 1
}

if ! create_test_topic; then
    echo -e "${RED}Cannot proceed without test topic. Exiting.${NC}"
    exit 1
fi

# Start monitoring
echo -e "${YELLOW}Starting performance monitoring...${NC}"
PROMETHEUS_START=$(date +%s)

# Record test parameters
cat > "${RESULTS_DIR}/test-info.txt" << EOF
Kafka Performance Test Results
==============================
Test Name: ${TEST_NAME}
Start Time: $(date -Iseconds)
Duration: ${DURATION} seconds
Target TPS: ${TPS}

Configuration Used:
KAFKA_BATCH_SIZE=${KAFKA_BATCH_SIZE}
KAFKA_LINGER_MS=${KAFKA_LINGER_MS:-0}
KAFKA_COMPRESSION_TYPE=${KAFKA_COMPRESSION_TYPE:-none}
KAFKA_BUFFER_MEMORY=${KAFKA_BUFFER_MEMORY:-33554432}
KAFKA_NUM_NETWORK_THREADS=${KAFKA_NUM_NETWORK_THREADS:-3}
KAFKA_NUM_IO_THREADS=${KAFKA_NUM_IO_THREADS:-8}

Test Environment:
- Single Kafka Broker
- Single Zookeeper
- 3 Partitions Topic
- Replication Factor: 1
EOF

# Run performance tests with error handling
run_performance_tests() {
    local num_records=$1
    
    echo -e "${BLUE}=== Running Producer Performance Test ===${NC}"
    echo "Testing with $num_records records..."
    
    # Run producer test with timeout
    if ! timeout 300 docker-compose exec -T kafka kafka-producer-perf-test \
        --topic blockchain-simulation \
        --num-records $num_records \
        --record-size 1024 \
        --throughput $TPS \
        --producer-props \
            bootstrap.servers=localhost:9092 \
            batch.size=${KAFKA_BATCH_SIZE} \
            linger.ms=${KAFKA_LINGER_MS:-0} \
            compression.type=${KAFKA_COMPRESSION_TYPE:-none} \
            buffer.memory=${KAFKA_BUFFER_MEMORY:-33554432} \
        > "${RESULTS_DIR}/producer-test.log" 2>&1; then
        echo -e "${RED}Producer test failed or timed out${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Producer test completed${NC}"
    
    # Run consumer test with timeout  
    echo -e "${BLUE}=== Running Consumer Performance Test ===${NC}"
    if ! timeout 120 docker-compose exec -T kafka kafka-consumer-perf-test \
        --topic blockchain-simulation \
        --bootstrap-server localhost:9092 \
        --messages $num_records \
        --threads 3 \
        > "${RESULTS_DIR}/consumer-test.log" 2>&1; then
        echo -e "${YELLOW}Consumer test failed or timed out (this may be normal)${NC}"
        # Consumer test failure is not critical, continue
    else
        echo -e "${GREEN}Consumer test completed${NC}"
    fi
    
    return 0
}

# Calculate number of records and run tests
NUM_RECORDS=$((TPS * DURATION / 10))  # Reduced by factor of 10 for faster testing
if [ $NUM_RECORDS -gt 50000 ]; then
    NUM_RECORDS=50000  # Cap at 50k for reasonable test time
elif [ $NUM_RECORDS -lt 1000 ]; then
    NUM_RECORDS=1000   # Minimum for meaningful results
fi

if ! run_performance_tests $NUM_RECORDS; then
    echo -e "${RED}Performance tests failed${NC}"
    echo -e "${YELLOW}Collecting available logs for debugging...${NC}"
    
    # Still try to collect what we can
    docker-compose logs --tail=50 kafka > "${RESULTS_DIR}/kafka-debug.log" 2>/dev/null || true
    docker stats kafka --no-stream > "${RESULTS_DIR}/final-stats.txt" 2>/dev/null || true
    
    # Create error summary
    cat > "${RESULTS_DIR}/summary.txt" << EOF
Kafka Performance Test - FAILED
===============================
Test: ${TEST_NAME}
Date: $(date)
Configuration: ${ENV_FILE}
Status: FAILED - Performance tests did not complete successfully

Configuration Parameters:
Batch Size: ${KAFKA_BATCH_SIZE} bytes
Linger Time: ${KAFKA_LINGER_MS:-0} ms
Compression: ${KAFKA_COMPRESSION_TYPE:-none}
Buffer Memory: ${KAFKA_BUFFER_MEMORY:-33554432} bytes

Error Details:
Check kafka-debug.log for detailed error information.
Consider running with more time or adjusting Docker resources.

Troubleshooting:
1. Check Docker memory allocation (needs 4GB+)
2. Verify no other services using ports 2181, 9092
3. Try: docker-compose down -v && docker system prune -f
EOF

    echo -e "${RED}Test failed. Check ${RESULTS_DIR}/summary.txt for details.${NC}"
    exit 1
fi

# Stop monitoring
PROMETHEUS_END=$(date +%s)
echo "Test completed at: $(date -Iseconds)" >> "${RESULTS_DIR}/test-info.txt"

# Collect final metrics
echo -e "${YELLOW}Collecting final metrics...${NC}"

# Container final stats
docker stats kafka --no-stream > "${RESULTS_DIR}/final-stats.txt" 2>/dev/null

# Kafka topics info
docker-compose exec -T kafka kafka-topics --list --bootstrap-server localhost:9092 > "${RESULTS_DIR}/topics.txt" 2>/dev/null
docker-compose exec -T kafka kafka-topics --describe --topic blockchain-simulation --bootstrap-server localhost:9092 > "${RESULTS_DIR}/topic-details.txt" 2>/dev/null

# Enhanced results parsing with better error handling
parse_test_results() {
    local success=false
    
    # Extract key metrics from producer test
    if [ -f "${RESULTS_DIR}/producer-test.log" ]; then
        # Parse producer results - example: "10000 records sent, 1000.100000 records/sec (0.98 MB/sec), 2.50 ms avg latency, 45.00 ms max latency"
        PRODUCER_LINE=$(grep "records sent" "${RESULTS_DIR}/producer-test.log" | tail -1)
        if [[ -n "$PRODUCER_LINE" ]]; then
            PRODUCER_THROUGHPUT=$(echo "$PRODUCER_LINE" | awk '{print $1}' 2>/dev/null || echo "N/A")
			PRODUCER_RATE=$(echo "$PRODUCER_LINE" | awk '{print $4}' 2>/dev/null || echo "N/A")
            
            # More robust latency parsing
            AVG_LATENCY=$(echo "$PRODUCER_LINE" | grep -oE '[0-9]+\.[0-9]+ ms avg latency' | grep -oE '[0-9]+\.[0-9]+' || echo "N/A")
            MAX_LATENCY=$(echo "$PRODUCER_LINE" | grep -oE '[0-9]+\.[0-9]+ ms max latency' | grep -oE '[0-9]+\.[0-9]+' || echo "N/A")
            
            if [[ "$PRODUCER_RATE" != "N/A" && "$PRODUCER_RATE" != "0" ]]; then
                success=true
            fi
        else
            # Check for errors in producer log
            if grep -q "ERROR\|Exception\|Failed" "${RESULTS_DIR}/producer-test.log"; then
                echo -e "${RED}Producer test encountered errors:${NC}"
                grep "ERROR\|Exception\|Failed" "${RESULTS_DIR}/producer-test.log" | head -3
            fi
            PRODUCER_THROUGHPUT="N/A"
            PRODUCER_RATE="N/A"
            AVG_LATENCY="N/A"
            MAX_LATENCY="N/A"
        fi
    else
        PRODUCER_THROUGHPUT="N/A"
        PRODUCER_RATE="N/A"
        AVG_LATENCY="N/A"
        MAX_LATENCY="N/A"
    fi

    # Extract consumer metrics
    if [ -f "${RESULTS_DIR}/consumer-test.log" ]; then
        CONSUMER_LINE=$(grep -E "MB/sec|records consumed" "${RESULTS_DIR}/consumer-test.log" | tail -1)
        if [[ -n "$CONSUMER_LINE" ]]; then
            CONSUMER_THROUGHPUT=$(echo "$CONSUMER_LINE" | awk '{print $3}' 2>/dev/null || echo "N/A")
            CONSUMER_RATE=$(echo "$CONSUMER_LINE" | awk '{print $5}' 2>/dev/null || echo "N/A")
        else
            CONSUMER_THROUGHPUT="N/A"
            CONSUMER_RATE="N/A"
        fi
    else
        CONSUMER_THROUGHPUT="N/A"
        CONSUMER_RATE="N/A"
    fi
    
    # Return success status
    $success
}

# Parse results and create summary
echo -e "${YELLOW}Generating test summary...${NC}"

if parse_test_results; then
    TEST_STATUS="COMPLETED SUCCESSFULLY"
    echo -e "${GREEN}Test results parsed successfully${NC}"
else
    TEST_STATUS="COMPLETED WITH WARNINGS"
    echo -e "${YELLOW}Test completed but with limited results${NC}"
fi

# Create comprehensive summary with status
cat > "${RESULTS_DIR}/summary.txt" << EOF
Kafka Performance Test Summary
==============================
Test: ${TEST_NAME}
Date: $(date)
Configuration: ${ENV_FILE}
Status: ${TEST_STATUS}

=== Configuration Parameters ===
Batch Size: ${KAFKA_BATCH_SIZE} bytes
Linger Time: ${KAFKA_LINGER_MS:-0} ms
Compression: ${KAFKA_COMPRESSION_TYPE:-none}
Buffer Memory: ${KAFKA_BUFFER_MEMORY:-33554432} bytes
Network Threads: ${KAFKA_NUM_NETWORK_THREADS:-3}
IO Threads: ${KAFKA_NUM_IO_THREADS:-8}

=== Performance Results ===
Producer Throughput: ${PRODUCER_RATE} records/sec
Total Records Sent: ${PRODUCER_THROUGHPUT}
Average Latency: ${AVG_LATENCY} ms
Maximum Latency: ${MAX_LATENCY} ms

Consumer Throughput: ${CONSUMER_RATE} records/sec
Consumer Data Rate: ${CONSUMER_THROUGHPUT} MB/sec

=== System Resources ===
$(cat "${RESULTS_DIR}/final-stats.txt" 2>/dev/null || echo "Resource stats not available")

=== Research Analysis ===
This test establishes baseline performance with the specified configuration.
Results can be compared with Paper 2/3 literature baselines (~1000 TPS target).

Paper Comparison:
- Target TPS: 1000 (Paper 2/3 baseline)
- Measured TPS: ${PRODUCER_RATE}
- Status: $(if [[ "$PRODUCER_RATE" != "N/A" && "${PRODUCER_RATE%.*}" -gt 800 ]]; then echo "✓ Good baseline established"; else echo "⚠ Consider retesting with more resources"; fi)

=== Files Generated ===
- producer-test.log: Detailed producer performance metrics
- consumer-test.log: Detailed consumer performance metrics
- docker-stats.txt: System resource usage during test
- topics.txt: Kafka topic information

=== Next Steps ===
1. If results look good: test optimized configurations
2. Compare with optimizations: ./scripts/simple-kafka-test.sh .env.batch-optimized
3. Run analysis: python3 scripts/analyze-simple-results.py ${RESULTS_DIR}
4. Generate research findings

=== Troubleshooting (if results are poor) ===
- Increase Docker memory allocation (4GB+ recommended)
- Check: docker stats (during test)
- Check: docker-compose logs kafka
- Try: docker-compose down -v && docker system prune -f
EOF

echo -e "${GREEN}✓ Test completed!${NC}"
echo -e "${BLUE}Results saved to: ${RESULTS_DIR}/${NC}"

# Show key results immediately
echo
echo -e "${YELLOW}=== KEY RESULTS ===${NC}"
echo "Producer Throughput: ${PRODUCER_RATE} records/sec"
echo "Average Latency: ${AVG_LATENCY} ms"
echo "Test Status: ${TEST_STATUS}"

# Provide immediate feedback on results quality
if [[ "$PRODUCER_RATE" != "N/A" ]]; then
    RATE_NUM=${PRODUCER_RATE%.*}  # Remove decimal part for comparison
    if [[ $RATE_NUM -gt 800 ]]; then
        echo -e "${GREEN}✓ Good baseline results! Ready for optimization testing.${NC}"
    elif [[ $RATE_NUM -gt 300 ]]; then
        echo -e "${YELLOW}⚠ Moderate results. Consider increasing Docker resources.${NC}"
    else
        echo -e "${RED}⚠ Low throughput. Check system resources and retry.${NC}"
    fi
else
    echo -e "${RED}⚠ No throughput measured. Check logs for errors.${NC}"
fi
echo
cat "${RESULTS_DIR}/summary.txt"

echo
echo -e "${YELLOW}View detailed results:${NC}"
echo -e "📊 Summary: ${YELLOW}cat ${RESULTS_DIR}/summary.txt${NC}"
echo -e "📈 Producer details: ${YELLOW}cat ${RESULTS_DIR}/producer-test.log${NC}" 
echo -e "📁 Full results directory: ${YELLOW}${RESULTS_DIR}/${NC}"

if command -v python3 &> /dev/null; then
    echo
    echo -e "${GREEN}Run analysis:${NC}"
    echo -e "python3 scripts/analyze-simple-results.py ${RESULTS_DIR}"
fi

echo
echo -e "${BLUE}Monitoring still available:${NC}"
echo -e "📊 Grafana: ${YELLOW}http://localhost:3000${NC} (admin/admin123)"
echo -e "📈 Prometheus: ${YELLOW}http://localhost:9090${NC}"