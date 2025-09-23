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
