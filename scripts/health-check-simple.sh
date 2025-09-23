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
