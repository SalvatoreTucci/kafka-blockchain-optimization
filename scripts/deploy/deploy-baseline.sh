#!/bin/bash
# Deploy baseline Kafka environment - Fixed version

set -e

echo "=========================================="
echo "Kafka-Blockchain Baseline Deployment"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Clean up existing
echo -e "${YELLOW}[1/6] Cleaning up existing containers...${NC}"
docker-compose down --remove-orphans --volumes 2>/dev/null || true
sleep 2

# Create directories
echo -e "${YELLOW}[2/6] Creating configuration directories...${NC}"
mkdir -p configs/monitoring docker/base results

# Create Prometheus config
if [ ! -f "configs/monitoring/prometheus.yml" ]; then
    echo "Creating Prometheus configuration..."
    cat > configs/monitoring/prometheus.yml << 'EOL'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'kafka-jmx'
    static_configs:
      - targets: ['jmx-exporter:8080']
    scrape_interval: 30s
EOL
fi

# Create JMX Exporter config
if [ ! -f "configs/monitoring/jmx_exporter_config.yml" ]; then
    echo "Creating JMX Exporter configuration..."
    cat > configs/monitoring/jmx_exporter_config.yml << 'EOL'
hostPort: kafka:9094
lowercaseOutputName: true
lowercaseOutputLabelNames: true
rules:
  - pattern: kafka.server<type=(.+), name=(.+)><>Value
    name: kafka_server_$1_$2
  - pattern: kafka.server<type=(.+), name=(.+), clientId=(.+)><>Value
    name: kafka_server_$1_$2
    labels:
      clientId: "$3"
EOL
fi

# Create test Dockerfile
if [ ! -f "docker/base/Dockerfile.test" ]; then
    echo "Creating test runner Dockerfile..."
    cat > docker/base/Dockerfile.test << 'EOL'
FROM python:3.9-slim
RUN apt-get update && \
    apt-get install -y curl wget netcat-traditional && \
    rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir kafka-python==2.0.2 requests==2.31.0
WORKDIR /workspace
CMD ["bash"]
EOL
fi

# Start services
echo -e "${YELLOW}[3/6] Starting Docker Compose services...${NC}"
docker-compose up -d

# Wait for Zookeeper
echo -e "${YELLOW}[4/6] Waiting for Zookeeper to become healthy...${NC}"
MAX_WAIT=60
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if docker-compose ps zookeeper | grep -q "healthy"; then
        echo -e "${GREEN}✓ Zookeeper is healthy!${NC}"
        break
    fi
    echo -n "."
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo -e "${RED}✗ Zookeeper failed to become healthy${NC}"
    docker-compose logs --tail=20 zookeeper
    exit 1
fi

# Wait for Kafka
echo -e "${YELLOW}[5/6] Waiting for Kafka to become healthy (this may take up to 2 minutes)...${NC}"
MAX_WAIT=120
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if docker-compose ps kafka | grep -q "healthy"; then
        echo -e "${GREEN}✓ Kafka is healthy!${NC}"
        break
    fi
    echo -n "."
    sleep 3
    ELAPSED=$((ELAPSED + 3))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo -e "${RED}✗ Kafka failed to become healthy${NC}"
    echo "Last 30 lines of Kafka logs:"
    docker-compose logs --tail=30 kafka
    exit 1
fi

# Verify Kafka functionality
echo -e "${YELLOW}[6/6] Verifying Kafka functionality...${NC}"
sleep 5

# Test topic creation
echo "Creating test topic..."
if docker-compose exec -T kafka kafka-topics \
    --create \
    --topic test-topic \
    --bootstrap-server localhost:9092 \
    --partitions 1 \
    --replication-factor 1 2>/dev/null; then
    echo -e "${GREEN}✓ Test topic created successfully${NC}"
else
    echo -e "${RED}✗ Failed to create test topic${NC}"
fi

# List topics
echo "Listing topics..."
docker-compose exec -T kafka kafka-topics \
    --list \
    --bootstrap-server localhost:9092 2>/dev/null || echo -e "${RED}Failed to list topics${NC}"

# Show all container status
echo ""
echo "=========================================="
echo -e "${GREEN}Deployment Complete!${NC}"
echo "=========================================="
echo ""
docker-compose ps

echo ""
echo "📊 Access Points:"
echo "  • Grafana:    http://localhost:3000 (admin/admin123)"
echo "  • Prometheus: http://localhost:9090"
echo "  • Kafka:      localhost:9092"
echo ""
echo "🧪 Test Commands:"
echo "  # List topics"
echo "  docker-compose exec kafka kafka-topics --list --bootstrap-server localhost:9092"
echo ""
echo "  # Producer test"
echo "  docker-compose exec kafka kafka-console-producer --topic test-topic --bootstrap-server localhost:9092"
echo ""
echo "  # Consumer test"
echo "  docker-compose exec kafka kafka-console-consumer --topic test-topic --from-beginning --bootstrap-server localhost:9092"
echo ""
echo "  # Enter test-runner container"
echo "  docker-compose exec test-runner bash"
echo ""
echo "📝 View logs:"
echo "  docker-compose logs -f kafka"
echo "  docker-compose logs -f zookeeper"
echo ""