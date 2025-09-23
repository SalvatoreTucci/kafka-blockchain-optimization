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

# Load environment
if [ -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}Loading environment from ${ENV_FILE}...${NC}"
    export $(cat $ENV_FILE | xargs)
    cp "$ENV_FILE" "${RESULTS_DIR}/config-used.env"
else
    echo -e "${RED}Environment file ${ENV_FILE} not found!${NC}"
    exit 1
fi

# Function to check if service is ready
wait_for_service() {
    local service=$1
    local port=$2
    local max_attempts=30
    local attempt=1
    
    echo -n "Waiting for ${service}:${port} to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if nc -z localhost $port 2>/dev/null; then
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

# Function to check blockchain readiness
wait_for_blockchain() {
    echo -e "${YELLOW}Checking blockchain components...${NC}"
    
    # Check if orderer is creating blocks
    for i in {1..30}; do
        if docker logs orderer 2>&1 | grep -q "Beginning to serve requests\|Starting orderer"; then
            echo -e "${GREEN}✓ Orderer is ready${NC}"
            break
        fi
        echo -n "."
        sleep 3
    done
    
    # Check if peers are ready
    for i in {1..20}; do
        if docker logs peer0-org1 2>&1 | grep -q "Starting peer\|Peer started"; then
            echo -e "${GREEN}✓ Peers are ready${NC}"
            break
        fi
        echo -n "."
        sleep 2
    done
}

# Stop existing containers and start fresh
echo -e "${YELLOW}Starting Kafka environment...${NC}"
docker-compose down > /dev/null 2>&1
docker-compose --env-file "$ENV_FILE" up -d

# Wait for services
wait_for_service "Zookeeper" 2181
wait_for_service "Kafka" 9092
wait_for_service "Prometheus" 9090
wait_for_service "Grafana" 3000

# Additional wait for Kafka to be fully ready
echo -e "${YELLOW}Waiting for Kafka to be fully operational...${NC}"
sleep 30

# Create test topic
echo -e "${YELLOW}Creating test topic...${NC}"
docker exec kafka kafka-topics --create \
    --topic blockchain-simulation \
    --bootstrap-server localhost:9092 \
    --partitions 3 \
    --replication-factor 1 > /dev/null 2>&1 || echo "Topic might already exist"

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
$(cat "$ENV_FILE" | grep "KAFKA_")

Test Environment:
- Single Kafka Broker
- Single Zookeeper
- 3 Partitions Topic
- Replication Factor: 1
EOF

# Performance Test 1: Producer Test
echo -e "${BLUE}=== Running Producer Performance Test ===${NC}"
docker exec kafka kafka-producer-perf-test \
    --topic blockchain-simulation \
    --num-records $((TPS * DURATION / 3)) \
    --record-size 1024 \
    --throughput $TPS \
    --producer-props \
        bootstrap.servers=localhost:9092 \
        batch.size=$KAFKA_BATCH_SIZE \
        linger.ms=$KAFKA_LINGER_MS \
        compression.type=$KAFKA_COMPRESSION_TYPE \
        buffer.memory=$KAFKA_BUFFER_MEMORY \
    > "${RESULTS_DIR}/producer-test.log" 2>&1 &

PRODUCER_PID=$!

# Performance Test 2: Consumer Test (in background)
echo -e "${BLUE}=== Running Consumer Performance Test ===${NC}"
docker exec kafka kafka-consumer-perf-test \
    --topic blockchain-simulation \
    --bootstrap-server localhost:9092 \
    --messages $((TPS * DURATION / 3)) \
    --threads 3 \
    > "${RESULTS_DIR}/consumer-test.log" 2>&1 &

CONSUMER_PID=$!

# Monitor system resources during test
echo -e "${YELLOW}Monitoring system resources...${NC}"
docker stats kafka --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" > "${RESULTS_DIR}/docker-stats.txt" &

# Wait for producer test to complete
wait $PRODUCER_PID
wait $CONSUMER_PID

# Stop monitoring
PROMETHEUS_END=$(date +%s)
echo "Test completed at: $(date -Iseconds)" >> "${RESULTS_DIR}/test-info.txt"

# Collect final metrics
echo -e "${YELLOW}Collecting final metrics...${NC}"

# JVM metrics from Kafka
docker exec kafka kafka-log-dirs --bootstrap-server localhost:9092 \
    --describe --json > "${RESULTS_DIR}/kafka-log-dirs.json" 2>/dev/null || true

# Container final stats
docker stats kafka --no-stream > "${RESULTS_DIR}/final-stats.txt"

# Kafka topics info
docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 > "${RESULTS_DIR}/topics.txt"
docker exec kafka kafka-topics --describe --topic blockchain-simulation --bootstrap-server localhost:9092 > "${RESULTS_DIR}/topic-details.txt"

# Collect Prometheus metrics via API
echo -e "${YELLOW}Collecting Prometheus metrics...${NC}"
PROM_URL="http://localhost:9090/api/v1/query_range"

# Key metrics to collect
declare -A METRICS=(
    ["jvm_memory_heap_used"]="jvm_memory_heap_used"
    ["jvm_memory_heap_max"]="jvm_memory_heap_max"
    ["kafka_server_requests_total"]="kafka_server_BrokerTopicMetrics_MessagesInPerSec"
    ["kafka_server_bytes_total"]="kafka_server_BrokerTopicMetrics_BytesInPerSec"
)

for metric_name in "${!METRICS[@]}"; do
    query="${METRICS[$metric_name]}"
    curl -s -G "${PROM_URL}" \
        --data-urlencode "query=${query}" \
        --data-urlencode "start=${PROMETHEUS_START}" \
        --data-urlencode "end=${PROMETHEUS_END}" \
        --data-urlencode "step=15" \
        > "${RESULTS_DIR}/metrics_${metric_name}.json" || true
done

# Parse results and create summary
echo -e "${YELLOW}Generating test summary...${NC}"

# Extract key metrics from producer test
if [ -f "${RESULTS_DIR}/producer-test.log" ]; then
    PRODUCER_THROUGHPUT=$(grep "records sent" "${RESULTS_DIR}/producer-test.log" | tail -1 | awk '{print $1}' || echo "N/A")
    PRODUCER_RATE=$(grep "records sent" "${RESULTS_DIR}/producer-test.log" | tail -1 | awk '{print $3}' | sed 's/[()]//g' || echo "N/A")
    AVG_LATENCY=$(grep "avg latency" "${RESULTS_DIR}/producer-test.log" | tail -1 | awk '{print $9}' || echo "N/A")
    MAX_LATENCY=$(grep "max latency" "${RESULTS_DIR}/producer-test.log" | tail -1 | awk '{print $12}' || echo "N/A")
else
    PRODUCER_THROUGHPUT="N/A"
    PRODUCER_RATE="N/A"
    AVG_LATENCY="N/A"
    MAX_LATENCY="N/A"
fi

# Extract consumer metrics
if [ -f "${RESULTS_DIR}/consumer-test.log" ]; then
    CONSUMER_THROUGHPUT=$(grep "MB/sec" "${RESULTS_DIR}/consumer-test.log" | tail -1 | awk '{print $3}' || echo "N/A")
    CONSUMER_RATE=$(grep "records/sec" "${RESULTS_DIR}/consumer-test.log" | tail -1 | awk '{print $5}' || echo "N/A")
else
    CONSUMER_THROUGHPUT="N/A"
    CONSUMER_RATE="N/A"
fi

# Create comprehensive summary
cat > "${RESULTS_DIR}/summary.txt" << EOF
Kafka Performance Test Summary
==============================
Test: ${TEST_NAME}
Date: $(date)
Configuration: ${ENV_FILE}

=== Configuration Parameters ===
Batch Size: ${KAFKA_BATCH_SIZE} bytes
Linger Time: ${KAFKA_LINGER_MS} ms
Compression: ${KAFKA_COMPRESSION_TYPE}
Buffer Memory: ${KAFKA_BUFFER_MEMORY} bytes
Network Threads: ${KAFKA_NUM_NETWORK_THREADS}
IO Threads: ${KAFKA_NUM_IO_THREADS}

=== Performance Results ===
Producer Throughput: ${PRODUCER_RATE} records/sec
Total Records Sent: ${PRODUCER_THROUGHPUT}
Average Latency: ${AVG_LATENCY} ms
Maximum Latency: ${MAX_LATENCY} ms

Consumer Throughput: ${CONSUMER_RATE} records/sec
Consumer Rate: ${CONSUMER_THROUGHPUT} MB/sec

=== System Resources ===
$(cat "${RESULTS_DIR}/final-stats.txt" 2>/dev/null || echo "Stats not available")

=== Files Generated ===
- producer-test.log: Detailed producer performance metrics
- consumer-test.log: Detailed consumer performance metrics
- docker-stats.txt: System resource usage during test
- metrics_*.json: Prometheus metrics data
- kafka-log-dirs.json: Kafka log directory information

=== Analysis ===
This test measures Kafka performance with the specified configuration.
Compare results across different parameter combinations to identify optimal settings.

For detailed analysis, use:
  python3 scripts/analyze-simple-results.py ${RESULTS_DIR}

=== Next Steps ===
1. Test different parameter combinations
2. Compare with baseline results
3. Analyze resource utilization patterns
4. Document optimal configurations
EOF

echo -e "${GREEN}✓ Test completed successfully!${NC}"
echo -e "${BLUE}Results saved to: ${RESULTS_DIR}/${NC}"
echo
cat "${RESULTS_DIR}/summary.txt"

echo
echo -e "${YELLOW}View results:${NC}"
echo -e "📊 Grafana Dashboard: ${YELLOW}http://localhost:3000${NC}"
echo -e "📈 Prometheus Metrics: ${YELLOW}http://localhost:9090${NC}"
echo -e "📁 Raw Data: ${YELLOW}${RESULTS_DIR}/${NC}"

echo
echo -e "${GREEN}Test environment is still running for analysis.${NC}"
echo -e "Run ${YELLOW}'docker-compose down'${NC} when done."