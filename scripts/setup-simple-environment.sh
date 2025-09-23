#!/bin/bash

# Hybrid environment setup for Kafka optimization with blockchain validation
# Combines Kafka performance testing with real blockchain implementation

set -e

echo "Setting up Hybrid Kafka-Blockchain Environment..."

# Create directory structure
echo "Creating directory structure..."
mkdir -p configs/{prometheus,grafana/{provisioning/datasources,dashboards}}
mkdir -p blockchain-config/{orderer,org1/peer0,org2/peer0}
mkdir -p chaincodes/simple-ledger
mkdir -p scripts
mkdir -p results/{baseline,optimized,hybrid}

# Call blockchain setup
echo "Setting up blockchain components..."
./scripts/setup-blockchain.sh

# Create environment files
echo "Creating environment configuration files..."

# Default configuration (Paper 3 baseline)
cat > .env.default << 'EOF'
KAFKA_BATCH_SIZE=16384
KAFKA_LINGER_MS=0
KAFKA_COMPRESSION_TYPE=none
KAFKA_BUFFER_MEMORY=33554432
KAFKA_NUM_NETWORK_THREADS=3
KAFKA_NUM_IO_THREADS=8
KAFKA_SOCKET_SEND_BUFFER_BYTES=102400
KAFKA_SOCKET_RECEIVE_BUFFER_BYTES=102400
KAFKA_REPLICA_FETCH_MAX_BYTES=1048576
TEST_NAME=default-baseline
TEST_DURATION=300
TEST_TPS=1000
EOF

# Batch optimization
cat > .env.batch-optimized << 'EOF'
KAFKA_BATCH_SIZE=65536
KAFKA_LINGER_MS=10
KAFKA_COMPRESSION_TYPE=none
KAFKA_BUFFER_MEMORY=67108864
KAFKA_NUM_NETWORK_THREADS=8
KAFKA_NUM_IO_THREADS=16
KAFKA_SOCKET_SEND_BUFFER_BYTES=204800
KAFKA_SOCKET_RECEIVE_BUFFER_BYTES=204800
KAFKA_REPLICA_FETCH_MAX_BYTES=2097152
TEST_NAME=batch-optimized
TEST_DURATION=300
TEST_TPS=1000
EOF

# Compression optimization
cat > .env.compression-optimized << 'EOF'
KAFKA_BATCH_SIZE=32768
KAFKA_LINGER_MS=5
KAFKA_COMPRESSION_TYPE=snappy
KAFKA_BUFFER_MEMORY=134217728
KAFKA_NUM_NETWORK_THREADS=16
KAFKA_NUM_IO_THREADS=32
KAFKA_SOCKET_SEND_BUFFER_BYTES=409600
KAFKA_SOCKET_RECEIVE_BUFFER_BYTES=409600
KAFKA_REPLICA_FETCH_MAX_BYTES=4194304
TEST_NAME=compression-optimized
TEST_DURATION=300
TEST_TPS=1000
EOF

# High throughput optimization
cat > .env.high-throughput << 'EOF'
KAFKA_BATCH_SIZE=262144
KAFKA_LINGER_MS=100
KAFKA_COMPRESSION_TYPE=lz4
KAFKA_BUFFER_MEMORY=268435456
KAFKA_NUM_NETWORK_THREADS=32
KAFKA_NUM_IO_THREADS=32
KAFKA_SOCKET_SEND_BUFFER_BYTES=819200
KAFKA_SOCKET_RECEIVE_BUFFER_BYTES=819200
KAFKA_REPLICA_FETCH_MAX_BYTES=8388608
TEST_NAME=high-throughput
TEST_DURATION=300
TEST_TPS=2000
EOF

# Create test suite runner
cat > scripts/run-hybrid-suite.sh << 'EOF'
#!/bin/bash

echo "=== Running Complete Hybrid Test Suite ==="
echo "This tests Kafka optimization + blockchain validation"

CONFIGS=(".env.default" ".env.batch-optimized" ".env.compression-optimized" ".env.high-throughput")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

for config in "${CONFIGS[@]}"; do
    echo "======================================="
    echo "Testing configuration: $config"
    echo "======================================="
    
    # Run hybrid test
    ./scripts/hybrid-full-test.sh "$config" "${config#.env.}-hybrid-${TIMESTAMP}"
    
    # Wait between tests
    echo "Waiting 60 seconds before next test..."
    sleep 60
done

echo "=== Complete test suite finished ==="
echo "Results in: results/*-hybrid-${TIMESTAMP}/"

# Generate comparison report
echo "Generating comparison report..."
python3 scripts/compare-hybrid-results.py results/ "*-hybrid-${TIMESTAMP}"
EOF

# Create comparison script
cat > scripts/compare-hybrid-results.py << 'EOF'
#!/usr/bin/env python3
"""
Compare multiple hybrid test results
"""

import os
import sys
import glob
from pathlib import Path
import re

def parse_hybrid_report(report_file):
    """Parse hybrid test report file"""
    data = {}
    
    with open(report_file, 'r') as f:
        content = f.read()
    
    # Extract key metrics
    producer_match = re.search(r'Producer Throughput:\s+([\d.]+)', content)
    latency_match = re.search(r'Average Latency:\s+([\d.]+)', content)
    blocks_match = re.search(r'Blocks Created:\s+(\d+)', content)
    
    data['producer_tps'] = float(producer_match.group(1)) if producer_match else 0
    data['avg_latency'] = float(latency_match.group(1)) if latency_match else 0
    data['blocks_created'] = int(blocks_match.group(1)) if blocks_match else 0
    
    # Extract configuration
    config_section = re.search(r'KAFKA CONFIGURATION TESTED:(.*?)KAFKA PERFORMANCE', content, re.DOTALL)
    if config_section:
        config_text = config_section.group(1)
        batch_match = re.search(r'Batch Size:\s+(\d+)', config_text)
        linger_match = re.search(r'Linger Time:\s+(\d+)', config_text)
        compression_match = re.search(r'Compression:\s+(\w+)', config_text)
        
        data['batch_size'] = int(batch_match.group(1)) if batch_match else 0
        data['linger_ms'] = int(linger_match.group(1)) if linger_match else 0
        data['compression'] = compression_match.group(1) if compression_match else 'none'
    
    return data

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 compare-hybrid-results.py <results_dir> <pattern>")
        sys.exit(1)
    
    results_dir = sys.argv[1]
    pattern = sys.argv[2]
    
    # Find all matching result directories
    search_pattern = os.path.join(results_dir, f"*{pattern}*")
    result_dirs = glob.glob(search_pattern)
    
    if not result_dirs:
        print(f"No results found matching pattern: {pattern}")
        sys.exit(1)
    
    print("HYBRID TEST RESULTS COMPARISON")
    print("=" * 50)
    
    results = []
    
    for result_dir in sorted(result_dirs):
        report_file = os.path.join(result_dir, 'hybrid-test-report.txt')
        if os.path.exists(report_file):
            config_name = os.path.basename(result_dir).split('-hybrid-')[0]
            data = parse_hybrid_report(report_file)
            data['config_name'] = config_name
            results.append(data)
    
    if not results:
        print("No valid reports found")
        sys.exit(1)
    
    # Print comparison table
    print(f"{'Config':<20} {'TPS':<10} {'Latency(ms)':<12} {'Blocks':<8} {'Batch':<10} {'Linger':<8} {'Compression':<12}")
    print("-" * 90)
    
    for result in results:
        print(f"{result['config_name']:<20} "
              f"{result['producer_tps']:<10.0f} "
              f"{result['avg_latency']:<12.1f} "
              f"{result['blocks_created']:<8} "
              f"{result['batch_size']:<10} "
              f"{result['linger_ms']:<8} "
              f"{result['compression']:<12}")
    
    # Find best configuration
    best_tps = max(results, key=lambda x: x['producer_tps'])
    best_latency = min(results, key=lambda x: x['avg_latency'])
    
    print("\nBEST PERFORMERS:")
    print(f"Highest TPS: {best_tps['config_name']} ({best_tps['producer_tps']:.0f} TPS)")
    print(f"Lowest Latency: {best_latency['config_name']} ({best_latency['avg_latency']:.1f} ms)")
    
    # Paper comparison
    default_result = next((r for r in results if 'default' in r['config_name']), None)
    if default_result:
        print(f"\nCOMPARISON WITH PAPER 3 BASELINE:")
        print(f"Default Configuration: {default_result['producer_tps']:.0f} TPS")
        print(f"Paper 3 Target: 1000 TPS")
        
        if default_result['producer_tps'] >= 1000:
            improvement = ((default_result['producer_tps'] - 1000) / 1000) * 100
            print(f"Result: +{improvement:.1f}% vs target")
        else:
            gap = ((1000 - default_result['producer_tps']) / 1000) * 100
            print(f"Gap: -{gap:.1f}% vs target")

if __name__ == "__main__":
    main()
EOF

# Make scripts executable
chmod +x scripts/*.sh scripts/*.py

echo "✓ Hybrid environment setup completed!"
echo
echo "Complete setup includes:"
echo "  - Kafka optimization testing"
echo "  - Blockchain validation with Hyperledger Fabric"
echo "  - Monitoring (Prometheus + Grafana)"
echo "  - 4 pre-configured test scenarios"
echo
echo "Available commands:"
echo "1. Quick Kafka test:     ./scripts/simple-kafka-test.sh .env.default"
echo "2. Blockchain validation: ./scripts/blockchain-test.sh .env.default"
echo "3. Hybrid test:          ./scripts/hybrid-full-test.sh .env.default"
echo "4. Complete suite:       ./scripts/run-hybrid-suite.sh"
echo "5. Compare results:      python3 scripts/compare-hybrid-results.py results/ pattern"
echo
echo "Monitoring:"
echo "  Grafana: http://localhost:3000 (admin/admin)"
echo "  Prometheus: http://localhost:9090"