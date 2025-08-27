#!/bin/bash
# Deploy baseline environment for testing

echo "🚀 Deploying Kafka-Blockchain Baseline Environment..."

# Check prerequisites
./scripts/utils/environment-check.sh

# Deploy infrastructure
echo "📦 Starting infrastructure..."
docker-compose up -d zookeeper-1 zookeeper-2 zookeeper-3
sleep 30

echo "📦 Starting Kafka cluster..."
docker-compose up -d kafka-1 kafka-2 kafka-3
sleep 30

echo "📦 Starting Hyperledger Fabric..."
docker-compose up -d peer0-org1 orderer
sleep 30

echo "📊 Starting monitoring..."
docker-compose up -d prometheus grafana kafka-exporter

echo "✅ Baseline environment deployed!"
echo "📊 Grafana: http://localhost:3000 (admin/admin)"
echo "📈 Prometheus: http://localhost:9090"
echo "🔍 Check status: docker-compose ps"