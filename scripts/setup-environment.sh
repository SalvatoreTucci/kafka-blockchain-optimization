#!/bin/bash

# Complete environment setup script for Kafka-Blockchain optimization project
# This script sets up all necessary directories and configuration files

set -e

echo "Setting up Kafka-Blockchain Optimization Environment..."

# Create all necessary directories
echo "Creating directory structure..."
mkdir -p configs/{kafka,prometheus,grafana/{provisioning/datasources,dashboards},channel-artifacts}
mkdir -p scripts
mkdir -p benchmarks/{networks,workloads}
mkdir -p results/{baseline,optimization}
mkdir -p docs/results

# Create .env files for different configurations
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
KAFKA_REPLICA_FETCH_MAX_BYTES=1048576

# Test configuration
TEST_NAME=default-baseline
TEST_DURATION=600
TEST_TPS=100
EOF

# Optimization test configurations
cat > .env.batch-optimized << 'EOF'
# Kafka Batch Size Optimization
KAFKA_BATCH_SIZE=65536
KAFKA_LINGER_MS=10
KAFKA_COMPRESSION_TYPE=none
KAFKA_BUFFER_MEMORY=33554432
KAFKA_NUM_NETWORK_THREADS=3
KAFKA_NUM_IO_THREADS=8
KAFKA_SOCKET_SEND_BUFFER_BYTES=102400
KAFKA_REPLICA_FETCH_MAX_BYTES=1048576

TEST_NAME=batch-optimized
TEST_DURATION=600
TEST_TPS=100
EOF

cat > .env.compression-optimized << 'EOF'
# Kafka Compression Optimization
KAFKA_BATCH_SIZE=32768
KAFKA_LINGER_MS=5
KAFKA_COMPRESSION_TYPE=snappy
KAFKA_BUFFER_MEMORY=67108864
KAFKA_NUM_NETWORK_THREADS=8
KAFKA_NUM_IO_THREADS=16
KAFKA_SOCKET_SEND_BUFFER_BYTES=204800
KAFKA_REPLICA_FETCH_MAX_BYTES=2097152

TEST_NAME=compression-optimized
TEST_DURATION=600
TEST_TPS=100
EOF

# Create Grafana dashboard provisioning
cat > configs/grafana/provisioning/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

# Create basic test script
cat > scripts/run-test.sh << 'EOF'
#!/bin/bash

# Test runner script
ENV_FILE=${1:-.env.default}
TEST_NAME=${2:-baseline}

if [ ! -f "$ENV_FILE" ]; then
    echo "Environment file $ENV_FILE not found!"
    exit 1
fi

echo "Running test with configuration: $ENV_FILE"
echo "Test name: $TEST_NAME"

# Load environment
export $(cat $ENV_FILE | xargs)

# Stop existing containers
echo "Stopping existing containers..."
docker-compose down

# Clean up volumes if requested
if [ "$3" = "clean" ]; then
    echo "Cleaning up volumes..."
    docker-compose down -v
fi

# Start with new configuration
echo "Starting containers with new configuration..."
docker-compose --env-file $ENV_FILE up -d

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 60

# Check if Kafka is ready
echo "Checking Kafka connectivity..."
for i in {1..30}; do
    if docker exec kafka1 kafka-topics --list --bootstrap-server localhost:9092 > /dev/null 2>&1; then
        echo "Kafka is ready!"
        break
    fi
    echo "Waiting for Kafka... (attempt $i/30)"
    sleep 10
done

echo "Environment setup complete!"
echo "Grafana: http://localhost:3000 (admin/admin)"
echo "Prometheus: http://localhost:9090"
echo "Test configuration: $TEST_NAME"

# Create results directory for this test
mkdir -p results/$TEST_NAME
echo "Results will be saved in: results/$TEST_NAME/"
EOF

chmod +x scripts/run-test.sh

# Create cleanup script
cat > scripts/cleanup.sh << 'EOF'
#!/bin/bash

echo "Cleaning up Kafka-Blockchain environment..."

# Stop all containers
docker-compose down

# Remove all volumes (optional - uncomment if needed)
# docker-compose down -v

# Remove stopped containers
docker container prune -f

# Remove unused networks
docker network prune -f

echo "Cleanup completed!"
EOF

chmod +x scripts/cleanup.sh

# Create health check script
cat > scripts/health-check.sh << 'EOF'
#!/bin/bash

echo "Checking system health..."

# Check if containers are running
echo "=== Container Status ==="
docker-compose ps

# Check Kafka connectivity
echo -e "\n=== Kafka Status ==="
for broker in kafka1:9092 kafka2:9093 kafka3:9094; do
    echo -n "Checking $broker: "
    if docker exec kafka1 kafka-broker-api-versions --bootstrap-server $broker > /dev/null 2>&1; then
        echo "✓ OK"
    else
        echo "✗ FAILED"
    fi
done

# Check Zookeeper ensemble
echo -e "\n=== Zookeeper Status ==="
for zk in zookeeper1:2181 zookeeper2:2182 zookeeper3:2183; do
    echo -n "Checking $zk: "
    if docker exec zookeeper1 zkCli -server $zk <<< "ls /" > /dev/null 2>&1; then
        echo "✓ OK"
    else
        echo "✗ FAILED"
    fi
done

# Check web interfaces
echo -e "\n=== Web Interfaces ==="
echo "Grafana: http://localhost:3000"
echo "Prometheus: http://localhost:9090"
echo "cAdvisor: http://localhost:8080"
EOF

chmod +x scripts/health-check.sh

echo "Environment setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Run: chmod +x scripts/setup-crypto.sh && ./scripts/setup-crypto.sh"
echo "2. Run: ./scripts/run-test.sh .env.default baseline"
echo "3. Access Grafana at http://localhost:3000 (admin/admin)"
echo "4. Check system health: ./scripts/health-check.sh"
echo ""
echo "Directory structure created:"
find . -type d -name ".*" -prune -o -type d -print | head -20