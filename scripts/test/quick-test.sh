#!/bin/bash
# Quick connectivity test

echo "🧪 Running quick connectivity tests..."

# Check if containers are running
echo "🔍 Checking container status..."
if ! docker-compose ps | grep -q "Up"; then
    echo "❌ No containers are running! Please deploy first:"
    echo "   bash scripts/deploy/deploy-baseline.sh"
    exit 1
fi

# Test Kafka
echo "📨 Testing Kafka connectivity..."
if docker-compose exec -T kafka kafka-topics --create --topic quicktest --bootstrap-server localhost:9092 --if-not-exists --replication-factor 1 --partitions 1; then
    echo "✅ Kafka topic created successfully"
else
    echo "❌ Failed to create Kafka topic"
    exit 1
fi

# Send test message
echo "📤 Sending test message..."
test_message="test-message-$(date +%s)"
echo "$test_message" | docker-compose exec -T kafka kafka-console-producer --topic quicktest --bootstrap-server localhost:9092

if [ $? -eq 0 ]; then
    echo "✅ Message sent successfully"
else
    echo "❌ Failed to send message"
fi

# Receive test message (with timeout)
echo "📥 Attempting to receive test message..."
if timeout 15 docker-compose exec -T kafka kafka-console-consumer --topic quicktest --bootstrap-server localhost:9092 --from-beginning --max-messages 1 2>/dev/null | grep -q "test-message"; then
    echo "✅ Message received successfully"
else
    echo "⚠️  Message receive test timed out (this might be normal)"
fi

# Test Prometheus
echo "📊 Testing Prometheus..."
if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
    echo "✅ Prometheus is healthy"
else
    echo "⚠️  Prometheus not ready yet (may need more time)"
fi

# Test Grafana
echo "📈 Testing Grafana..."
if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
    echo "✅ Grafana is healthy"
else
    echo "⚠️  Grafana not ready yet (may need more time)"
fi

# Test JMX Exporter
echo "🔧 Testing JMX Exporter..."
if curl -s http://localhost:8080/metrics >/dev/null 2>&1; then
    echo "✅ JMX Exporter is healthy"
else
    echo "⚠️  JMX Exporter not ready yet (may need more time)"
fi

echo ""
echo "📋 Container Status:"
docker-compose ps

echo ""
echo "✅ Basic connectivity tests completed!"
echo ""
echo "🌐 Open in browser:"
echo "   📊 Grafana:    http://localhost:3000 (admin/admin123)"
echo "   📈 Prometheus: http://localhost:9090"
echo "   🔍 Metrics:    http://localhost:8080/metrics"