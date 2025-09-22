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
