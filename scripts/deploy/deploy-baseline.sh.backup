#!/bin/bash
# Deploy baseline Kafka environment - Fixed health checks

set -e

echo "Deploying Kafka-Blockchain Baseline Environment..."

# Clean up
docker-compose down --remove-orphans 2>/dev/null || true

# Create directories
mkdir -p configs/monitoring docker/base

# Create configs
if [ ! -f "configs/monitoring/prometheus.yml" ]; then
    cat > configs/monitoring/prometheus.yml << 'EOL'
global:
  scrape_interval: 15s
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

if [ ! -f "configs/monitoring/jmx_exporter_config.yml" ]; then
    cat > configs/monitoring/jmx_exporter_config.yml << 'EOL'
hostPort: kafka:9094
rules:
- pattern: kafka.server<type=(.+), name=(.+)><>Value
  name: kafka_server_$1_$2
EOL
fi

if [ ! -f "docker/base/Dockerfile.test" ]; then
    cat > docker/base/Dockerfile.test << 'EOL'
FROM python:3.9-slim
RUN apt-get update && apt-get install -y curl wget netcat-traditional && rm -rf /var/lib/apt/lists/*
RUN pip install kafka-python==2.0.2 requests==2.31.0
WORKDIR /workspace
CMD ["bash"]
EOL
fi

# Start all services
echo "Starting services..."
docker-compose up -d

echo "Waiting for initialization (60 seconds)..."
sleep 60

# Check Zookeeper with correct command
echo "Checking Zookeeper..."
if docker-compose exec -T zookeeper sh -c 'echo "srvr" | nc localhost 2181' 2>/dev/null | grep -q "Zookeeper version"; then
    echo "Zookeeper is healthy!"
elif docker-compose logs zookeeper | grep -q "binding to port"; then
    echo "Zookeeper is running!"
else
    echo "Zookeeper status unclear - checking logs:"
    docker-compose logs --tail=5 zookeeper
fi

# Check Kafka
echo "Checking Kafka..."
if docker-compose exec -T kafka kafka-topics --bootstrap-server localhost:9092 --list &>/dev/null; then
    echo "Kafka is healthy!"
elif docker-compose logs kafka | grep -q "started.*KafkaServer"; then
    echo "Kafka is running!"
else
    echo "Kafka status unclear - checking logs:"
    docker-compose logs --tail=5 kafka
fi

echo ""
echo "Container Status:"
docker-compose ps

echo ""
echo "Access Points:"
echo "  Grafana:    http://localhost:3000 (admin/admin123)"
echo "  Prometheus: http://localhost:9090"

echo ""
echo "Test Kafka manually:"
echo "  docker-compose exec kafka kafka-topics --list --bootstrap-server localhost:9092"
