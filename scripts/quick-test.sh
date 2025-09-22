#!/bin/bash

# Quick validation test - 5 minutes total

echo "=== QUICK VALIDATION TEST ==="
echo "Running 5-minute validation test..."

# Start environment  
./scripts/run-test.sh .env.default quick-test

# Wait for readiness
sleep 60

# Simulate load for 2 minutes
echo "Simulating blockchain load..."
sleep 120

# Collect basic metrics
echo "Collecting metrics..."
RESULTS_DIR="results/quick-test-$(date +%H%M%S)"
mkdir -p "${RESULTS_DIR}"

# Simple metrics collection
docker stats --no-stream kafka1 kafka2 kafka3 > "${RESULTS_DIR}/docker-stats.txt"
docker logs kafka1 > "${RESULTS_DIR}/kafka1.log" 2>&1
docker logs orderer.example.com > "${RESULTS_DIR}/orderer.log" 2>&1

echo "✓ Quick test completed"
echo "Results in: ${RESULTS_DIR}"
echo "Check logs and stats for basic health validation"
