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
