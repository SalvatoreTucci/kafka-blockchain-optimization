#!/bin/bash

# Simplified environment setup for Kafka performance testing
# No blockchain complexity - focus on Kafka optimization

set -e

echo "Setting up Simplified Kafka Performance Testing Environment..."

# Create directory structure
echo "Creating directory structure..."
mkdir -p configs/{prometheus,grafana/{provisioning/datasources,dashboards}}
mkdir -p benchmarks
mkdir -p results/{baseline,optimized}
mkdir -p scripts

# Create environment files
echo "Creating environment configuration files..."

# Default configuration (Paper 3 baseline)
cat > .env.default << 'EOF'
# Kafka Default Configuration (Paper 3 Baseline)
KAFKA_BATCH_SIZE=16384
KAFKA_LINGER_MS=0
KAFKA_COMPRESSION_TYPE=none
KAFKA_BUFFER_MEMORY=33554432
KAFKA_NUM_NETWORK_THREADS=3
KAFKA_NUM_IO_THREADS=8
KAFKA_SOCKET_SEND_BUFFER_BYTES=102400
KAFKA_SOCKET_RECEIVE_BUFFER_BYTES=102400
KAFKA_REPLICA_FETCH_MAX_BYTES=1048576

TEST_NAME=default-baseline
TEST_DURATION=300
TEST_TPS=1000
EOF

# Batch optimization
cat > .env.batch-optimized << 'EOF'
# Kafka Batch Size Optimization
KAFKA_BATCH_SIZE=65536
KAFKA_LINGER_MS=10
KAFKA_COMPRESSION_TYPE=none
KAFKA_BUFFER_MEMORY=67108864
KAFKA_NUM_NETWORK_THREADS=8
KAFKA_NUM_IO_THREADS=16
KAFKA_SOCKET_SEND_BUFFER_BYTES=204800
KAFKA_SOCKET_RECEIVE_BUFFER_BYTES=204800
KAFKA_REPLICA_FETCH_MAX_BYTES=2097152

TEST_NAME=batch-optimized
TEST_DURATION=300
TEST_TPS=1000
EOF

# Compression optimization
cat > .env.compression-optimized << 'EOF'
# Kafka Compression Optimization
KAFKA_BATCH_SIZE=32768
KAFKA_LINGER_MS=5
KAFKA_COMPRESSION_TYPE=snappy
KAFKA_BUFFER_MEMORY=134217728
KAFKA_NUM_NETWORK_THREADS=16
KAFKA_NUM_IO_THREADS=32
KAFKA_SOCKET_SEND_BUFFER_BYTES=409600
KAFKA_SOCKET_RECEIVE_BUFFER_BYTES=409600
KAFKA_REPLICA_FETCH_MAX_BYTES=4194304

TEST_NAME=compression-optimized
TEST_DURATION=300
TEST_TPS=1000
EOF

# High throughput optimization
cat > .env.high-throughput << 'EOF'
# Kafka High Throughput Optimization
KAFKA_BATCH_SIZE=262144
KAFKA_LINGER_MS=100
KAFKA_COMPRESSION_TYPE=lz4
KAFKA_BUFFER_MEMORY=268435456
KAFKA_NUM_NETWORK_THREADS=32
KAFKA_NUM_IO_THREADS=32
KAFKA_SOCKET_SEND_BUFFER_BYTES=819200
KAFKA_SOCKET_RECEIVE_BUFFER_BYTES=819200
KAFKA_REPLICA_FETCH_MAX_BYTES=8388608

TEST_NAME=high-throughput
TEST_DURATION=300
TEST_TPS=2000
EOF

# Create health check script
cat > scripts/health-check-simple.sh << 'EOF'
#!/bin/bash

echo "Checking simplified Kafka environment health..."

echo "=== Container Status ==="
docker-compose ps

echo -e "\n=== Kafka Status ==="
if docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1; then
    echo "✓ Kafka is responsive"
else
    echo "✗ Kafka not responding"
fi

echo -e "\n=== Topics ==="
docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 2>/dev/null || echo "No topics yet"

echo -e "\n=== Web Interfaces ==="
echo "Grafana: http://localhost:3000 (admin/admin)"
echo "Prometheus: http://localhost:9090"
EOF

# Create quick test script
cat > scripts/quick-simple-test.sh << 'EOF'
#!/bin/bash

echo "=== Quick Kafka Test ==="

# Start environment
echo "Starting simplified environment..."
docker-compose up -d

# Wait for readiness
echo "Waiting for services..."
sleep 30

# Create test topic
echo "Creating test topic..."
docker exec kafka kafka-topics --create --topic quick-test --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1 2>/dev/null || echo "Topic exists"

# Quick producer test
echo "Running quick producer test..."
docker exec kafka kafka-producer-perf-test \
    --topic quick-test \
    --num-records 10000 \
    --record-size 1024 \
    --throughput 1000 \
    --producer-props bootstrap.servers=localhost:9092

echo "✓ Quick test completed"
echo "Environment ready for full testing"
EOF

# Create full test suite script
cat > scripts/run-full-suite.sh << 'EOF'
#!/bin/bash

echo "=== Running Full Kafka Optimization Test Suite ==="

CONFIGS=(".env.default" ".env.batch-optimized" ".env.compression-optimized" ".env.high-throughput")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

for config in "${CONFIGS[@]}"; do
    echo "======================================="
    echo "Testing configuration: $config"
    echo "======================================="
    
    # Run test
    ./scripts/simple-kafka-test.sh "$config" "${config#.env.}-${TIMESTAMP}" 300 1000
    
    # Wait between tests
    echo "Waiting 30 seconds before next test..."
    sleep 30
done

echo "=== Full test suite completed ==="
echo "Results in: results/*-${TIMESTAMP}/"
EOF

# Make scripts executable
chmod +x scripts/*.sh

# Create cleanup script
cat > scripts/cleanup-simple.sh << 'EOF'
#!/bin/bash

echo "Cleaning up simplified Kafka environment..."

# Stop containers
docker-compose down

# Optional: clean volumes
if [ "$1" = "volumes" ]; then
    echo "Cleaning volumes..."
    docker-compose down -v
fi

# Clean unused containers
docker container prune -f

echo "Cleanup completed!"
EOF

chmod +x scripts/cleanup-simple.sh

echo "✓ Simplified environment setup completed!"
echo ""
echo "Files created:"
echo "  - docker-compose.yml (simplified)"
echo "  - .env.* (4 test configurations)"
echo "  - configs/ (Prometheus, Grafana, JMX)"
echo "  - scripts/ (testing and analysis tools)"
echo ""
echo "Next steps:"
echo "1. Test basic setup:"
echo "   ./scripts/quick-simple-test.sh"
echo ""
echo "2. Run single configuration test:"
echo "   ./scripts/simple-kafka-test.sh .env.default test1"
echo ""
echo "3. Run full test suite:"
echo "   ./scripts/run-full-suite.sh"
echo ""
echo "4. Analyze results:"
echo "   python3 scripts/analyze-simple-results.py results/test1/"
echo ""
echo "5. View dashboards:"
echo "   Grafana: http://localhost:3000 (admin/admin)"
echo "   Prometheus: http://localhost:9090"