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
