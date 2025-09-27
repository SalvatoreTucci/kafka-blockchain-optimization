#!/bin/bash

set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 Starting Blockchain Benchmark with Optimal Kafka Config${NC}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="results/blockchain_benchmark_${TIMESTAMP}"
mkdir -p "${RESULTS_DIR}"

# Test parameters
TOTAL_TRANSACTIONS=${1:-500}  # Reduced for faster testing
CONCURRENT_CLIENTS=${2:-5}
TEST_DURATION=${3:-180}       # 3 minutes

echo -e "${YELLOW}📋 Benchmark Configuration:${NC}"
echo "  Total Transactions: ${TOTAL_TRANSACTIONS}"
echo "  Concurrent Clients: ${CONCURRENT_CLIENTS}"
echo "  Test Duration: ${TEST_DURATION}s"
echo "  Results Directory: ${RESULTS_DIR}"
echo ""

# Check if network is ready
echo -e "${YELLOW}🔍 Checking network readiness...${NC}"
if ! docker exec cli peer chaincode query -C businesschannel -n smallbank -c '{"function":"Balance","Args":["account1"]}' &>/dev/null; then
    echo -e "${RED}❌ Chaincode not ready. Deploy chaincode first.${NC}"
    echo "Run: cd ../fabric-network && ./scripts/chaincode-deploy.sh"
    exit 1
fi

echo -e "${GREEN}✅ Network and chaincode ready${NC}"

# Start monitoring
echo -e "${YELLOW}📊 Starting monitoring...${NC}"
echo "Start Time: $(date)" > "${RESULTS_DIR}/benchmark_log.txt"

# Monitor initial system stats
docker stats kafka orderer peer0-org1 --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" --no-stream > "${RESULTS_DIR}/system_stats_start.txt"

echo -e "${GREEN}✅ Monitoring started${NC}"

# Create transaction execution script
cat > "${RESULTS_DIR}/execute_transactions.sh" << 'INNER_EOF'
#!/bin/bash
CLIENT_ID=$1
TRANSACTIONS_PER_CLIENT=$2
RESULTS_FILE=$3

echo "Client $CLIENT_ID starting with $TRANSACTIONS_PER_CLIENT transactions"

for i in $(seq 1 $TRANSACTIONS_PER_CLIENT); do
    # Random accounts for transfer
    FROM_ACCOUNT="account$((RANDOM % 5 + 1))"
    TO_ACCOUNT="account$((RANDOM % 5 + 1))"
    
    # Avoid self-transfer
    while [ "$FROM_ACCOUNT" = "$TO_ACCOUNT" ]; do
        TO_ACCOUNT="account$((RANDOM % 5 + 1))"
    done
    
    AMOUNT=$((RANDOM % 1000 + 100))  # 100-1100 amount
    
    # Record start time (milliseconds)
    START_TIME=$(date +%s%3N)
    
    # Execute blockchain transaction
    if docker exec cli peer chaincode invoke \
        -o orderer.example.com:7050 \
        --channelID businesschannel \
        -n smallbank \
        -c "{\"function\":\"Transfer\",\"Args\":[\"$FROM_ACCOUNT\",\"$TO_ACCOUNT\",\"$AMOUNT\"]}" \
        &>/dev/null; then
        
        STATUS="SUCCESS"
    else
        STATUS="FAILED"
    fi
    
    # Record end time
    END_TIME=$(date +%s%3N)
    LATENCY=$((END_TIME - START_TIME))
    
    # Log transaction result
    echo "Client$CLIENT_ID,TX$i,$START_TIME,$END_TIME,$LATENCY,$STATUS,$FROM_ACCOUNT,$TO_ACCOUNT,$AMOUNT" >> "$RESULTS_FILE"
    
    # Progress indicator
    if [ $((i % 10)) -eq 0 ]; then
        echo "Client $CLIENT_ID: $i/$TRANSACTIONS_PER_CLIENT transactions completed"
    fi
    
    # Small delay to avoid overwhelming the network
    sleep 0.1
done

echo "Client $CLIENT_ID completed all $TRANSACTIONS_PER_CLIENT transactions"
INNER_EOF

chmod +x "${RESULTS_DIR}/execute_transactions.sh"

# Execute concurrent blockchain load test
echo -e "${YELLOW}🔄 Starting concurrent blockchain transactions...${NC}"

TRANSACTIONS_PER_CLIENT=$((TOTAL_TRANSACTIONS / CONCURRENT_CLIENTS))
echo "Each client will execute $TRANSACTIONS_PER_CLIENT transactions"

# Start all clients concurrently
for client in $(seq 1 $CONCURRENT_CLIENTS); do
    "${RESULTS_DIR}/execute_transactions.sh" "$client" "$TRANSACTIONS_PER_CLIENT" "${RESULTS_DIR}/client_${client}_results.txt" &
    CLIENT_PID=$!
    echo "  Client $client started (PID: $CLIENT_PID)"
done

echo "⏳ Waiting for all clients to complete..."
wait

echo -e "${GREEN}✅ All blockchain transactions completed${NC}"

# Collect final system statistics
echo -e "${YELLOW}📊 Collecting final statistics...${NC}"

# Final system stats
docker stats kafka orderer peer0-org1 --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" --no-stream > "${RESULTS_DIR}/system_stats_end.txt"

# Kafka metrics
echo "📈 Collecting Kafka metrics..."
docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 > "${RESULTS_DIR}/kafka_topics.txt" 2>/dev/null || echo "Could not collect kafka topics"
docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --list > "${RESULTS_DIR}/kafka_consumer_groups.txt" 2>/dev/null || echo "Could not collect consumer groups"

# Container logs (last 100 lines)
echo "📋 Collecting container logs..."
docker logs --tail 100 orderer > "${RESULTS_DIR}/orderer_logs.txt" 2>&1
docker logs --tail 100 kafka > "${RESULTS_DIR}/kafka_logs.txt" 2>&1
docker logs --tail 100 peer0-org1 > "${RESULTS_DIR}/peer0_logs.txt" 2>&1

# Final benchmark info
echo "End Time: $(date)" >> "${RESULTS_DIR}/benchmark_log.txt"
echo "Total Clients: $CONCURRENT_CLIENTS" >> "${RESULTS_DIR}/benchmark_log.txt"
echo "Transactions per Client: $TRANSACTIONS_PER_CLIENT" >> "${RESULTS_DIR}/benchmark_log.txt"

echo -e "${GREEN}🎉 Blockchain benchmark completed!${NC}"
echo -e "${BLUE}📁 Results saved in: ${RESULTS_DIR}${NC}"
echo ""
echo -e "${YELLOW}📊 Quick Analysis:${NC}"

# Quick results summary
TOTAL_SUCCESS=0
TOTAL_FAILED=0

for client_file in "${RESULTS_DIR}"/client_*_results.txt; do
    if [ -f "$client_file" ]; then
        SUCCESS_COUNT=$(grep -c "SUCCESS" "$client_file" 2>/dev/null || echo 0)
        FAILED_COUNT=$(grep -c "FAILED" "$client_file" 2>/dev/null || echo 0)
        TOTAL_SUCCESS=$((TOTAL_SUCCESS + SUCCESS_COUNT))
        TOTAL_FAILED=$((TOTAL_FAILED + FAILED_COUNT))
    fi
done

echo "  Successful Transactions: $TOTAL_SUCCESS"
echo "  Failed Transactions: $TOTAL_FAILED"
echo "  Success Rate: $(( TOTAL_SUCCESS * 100 / (TOTAL_SUCCESS + TOTAL_FAILED) ))%" 2>/dev/null || echo "  Success Rate: N/A"
echo ""
echo -e "${BLUE}Run detailed analysis:${NC}"
echo "  python3 ../scripts/analyze_blockchain_results.py ${RESULTS_DIR}"
