# Blockchain Benchmark Testing - Complete Replication Guide

## Overview

This guide documents the complete blockchain simulation benchmark testing performed on Apache Kafka to validate performance optimizations for blockchain ordering services. The testing demonstrates a **+41% throughput improvement** over baseline configuration.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Test Execution](#test-execution)
4. [Results Analysis](#results-analysis)
5. [Key Findings](#key-findings)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### System Requirements
- **OS**: Linux/macOS (Windows with WSL2 or Git Bash)
- **Docker**: 20.10+ with Docker Compose
- **Memory**: 8GB RAM minimum
- **Disk**: 20GB free space
- **Python**: 3.9+ (for analysis scripts)

### Required Software
```bash
# Docker & Docker Compose
docker --version  # Should be 20.10+
docker-compose --version

# Python 3.9+
python3 --version

# Git (to clone repository)
git --version
```

---

## Environment Setup

### 1. Clone Repository

```bash
git clone https://github.com/SalvatoreTucci/kafka-blockchain-optimization.git
cd kafka-blockchain-optimization
```

### 2. Deploy Baseline Environment

```bash
# Deploy Kafka + Zookeeper + Monitoring stack
./scripts/deploy/deploy-baseline.sh
```

**Expected Output:**
```
==========================================
Kafka-Blockchain Baseline Deployment
==========================================
[1/6] Cleaning up existing containers...
[2/6] Creating configuration directories...
[3/6] Starting Docker Compose services...
✓ Kafka is healthy!
✓ Test topic created successfully
==========================================
Deployment Complete!
==========================================
```

### 3. Verify Installation

```bash
# Quick connectivity test
./scripts/test/quick-test.sh
```

**Expected Output:**
```
🧪 Running quick connectivity tests...
✅ Kafka topic created successfully
✅ Message sent successfully
✅ Message received successfully
✅ Prometheus is healthy
✅ Grafana is healthy
```

---

## Test Execution

### Step 1: Test Blockchain Simulator

Verify the blockchain simulator is working correctly:

```bash
docker-compose exec test-runner python3 ./scripts/blockchain/blockchain_simulator.py
```

**Expected Output:**
```
Blockchain Simulator - Component Test
Genesis block: 112a59197b55e3ce...
Sample transaction: tx_000001 -> e2fe452e70380fa3...
Blockchain simulator components loaded successfully
```

### Step 2: Run Single Configuration Test

Test with a single configuration to verify setup:

```bash
docker-compose exec test-runner python3 ./scripts/blockchain/run-blockchain-benchmark.py \
  --config test \
  --batch-size 16384 \
  --linger-ms 0 \
  --transactions 1000
```

**Expected Output:**
```
======================================================================
BLOCKCHAIN BENCHMARK: TEST
======================================================================
Configuration:
  Batch Size: 16384
  Linger MS: 0
  Compression: none
  Transactions: 1000

TEST 1: Transaction Submission (1000 transactions)
Results:
  Throughput: 2413.92 TPS
  Avg Submission Time: 62.79 ms
  P95 Submission Time: 121.34 ms

TEST 2: Block Formation (1 peer(s))
Results:
  Blocks Created: 10
  Avg Block Formation Time: 2.00 ms
  Blocks/Second: 35.70

TEST 3: End-to-End Latency (100 samples)
Results:
  Avg E2E Latency: 104.71 ms
  P50 Latency: 104.57 ms
  P95 Latency: 105.56 ms
```

### Step 3: Run Complete Benchmark Suite

Execute all 4 configuration tests (baseline, batch-optimized, high-throughput, low-latency):

```bash
./run-blockchain-benchmarks.sh 5000
```

**Duration:** ~10-15 minutes for complete suite

**Configurations Tested:**
1. **Baseline**: 16KB batch, 0ms linger, no compression
2. **Batch-Optimized**: 65KB batch, 10ms linger, no compression
3. **High-Throughput**: 131KB batch, 25ms linger, no compression
4. **Low-Latency**: 8KB batch, 0ms linger, no compression

**Expected Output:**
```
╔════════════════════════════════════════════╗
║   BLOCKCHAIN BENCHMARK SUITE               ║
╚════════════════════════════════════════════╝

Results directory: blockchain_benchmark_results_20251002_172904

▶ Running: baseline
✓ Completed: baseline

▶ Running: batch-optimized
✓ Completed: batch-optimized

▶ Running: high-throughput
✓ Completed: high-throughput

▶ Running: low-latency
✓ Completed: low-latency

╔════════════════════════════════════════════╗
║   ALL BENCHMARKS COMPLETED                 ║
╚════════════════════════════════════════════╝
```

---

## Results Analysis

### Step 4: Extract Results from Container

The results are saved inside the Docker container. Extract them to your host machine:

```bash
# Navigate to results directory
cd blockchain_benchmark_results_YYYYMMDD_HHMMSS/

# Copy JSON results from container to host
docker cp test-runner:/results/blockchain_baseline_TIMESTAMP.json ./baseline_result.json
docker cp test-runner:/results/blockchain_batch-optimized_TIMESTAMP.json ./batch-optimized_result.json
docker cp test-runner:/results/blockchain_high-throughput_TIMESTAMP.json ./high-throughput_result.json
docker cp test-runner:/results/blockchain_low-latency_TIMESTAMP.json ./low-latency_result.json

# Verify files exist
ls -la *.json
```

### Step 5: Run Analysis Script

```bash
# Return to project root
cd ..

# Run Python analysis
python3 analyze_blockchain_results.py blockchain_benchmark_results_YYYYMMDD_HHMMSS
```

**Expected Output:**
```
Blockchain Benchmark Results Analysis
====================================================================================================
Found 4 result files

====================================================================================================
BLOCKCHAIN BENCHMARK COMPARISON
====================================================================================================

Configuration        TPS        Blocks/s   Block Time   Finality     E2E P95
----------------------------------------------------------------------------------------------------
baseline               7068.9     65.36        1.80ms        0.02s    105.08ms
batch-optimized        8935.9     72.09        1.81ms        0.01s    116.25ms (+26.4%)
high-throughput        9964.8     90.22        1.84ms        0.01s    130.82ms (+41.0%)
low-latency            6450.9     54.85        1.87ms        0.02s    104.71ms (-8.7%)
====================================================================================================

BEST PERFORMING CONFIGURATIONS
Highest Throughput: high-throughput
  TPS: 9964.81
  Config: batch=131072, linger=25ms
```

### Generated Artifacts

The analysis produces:

1. **`blockchain_comparison.png`** - Visual comparison charts
2. **`BLOCKCHAIN_ANALYSIS_REPORT.md`** - Detailed markdown report
3. **Console output** - Quick summary

---

## Key Findings

### Performance Results

| Configuration | TPS | Improvement vs Baseline | E2E Latency (P95) | Block Formation |
|---------------|-----|-------------------------|-------------------|-----------------|
| **Baseline** | 7,069 | - | 105.08ms | 1.80ms |
| **Batch-Optimized** | 8,936 | +26.4% | 116.25ms | 1.81ms |
| **High-Throughput** | 9,965 | **+41.0%** | 130.82ms | 1.84ms |
| **Low-Latency** | 6,451 | -8.7% | 104.71ms | 1.87ms |

### Optimal Configuration Identified

**Winner: High-Throughput**
```properties
KAFKA_BATCH_SIZE=131072      # 128KB (8x baseline)
KAFKA_LINGER_MS=25           # 25ms batching window
KAFKA_COMPRESSION_TYPE=none  # No compression overhead
```

**Key Insights:**
- **+41% throughput improvement** over baseline
- Block formation time remains stable (~1.8ms across all configs)
- Trade-off: +25ms E2E latency for +41% throughput
- Batch size has the most significant impact on performance

---

## Troubleshooting

### Common Issues

#### 1. Docker Containers Not Starting

```bash
# Check Docker status
docker-compose ps

# View logs
docker-compose logs kafka
docker-compose logs zookeeper

# Restart environment
docker-compose down
docker-compose up -d
```

#### 2. Python Dependencies Missing

```bash
# Install required packages
pip3 install kafka-python matplotlib pandas numpy
```

#### 3. Files Not Copying from Container

```bash
# Check if files exist in container
docker-compose exec test-runner ls -la /results/

# Find correct timestamp
docker-compose exec test-runner find /results -name "blockchain_*.json"

# Use correct timestamp in copy command
docker cp test-runner:/results/blockchain_baseline_ACTUAL_TIMESTAMP.json ./baseline_result.json
```

#### 4. Port Conflicts

If ports 9092, 2181, 3000, or 9090 are in use:

```bash
# Stop conflicting services
sudo lsof -i :9092
sudo kill -9 PID

# Or modify docker-compose.yml to use different ports
```

#### 5. Low Throughput Results

- Ensure Docker has adequate resources (4GB+ RAM)
- Close other resource-intensive applications
- Check system load: `docker stats`

---

## Validation Checklist

Before considering your replication successful, verify:

- [ ] All 4 containers running (kafka, zookeeper, prometheus, grafana)
- [ ] Quick test passes successfully
- [ ] Blockchain simulator test completes without errors
- [ ] Single configuration test shows ~2,400 TPS
- [ ] Full benchmark suite completes all 4 configs
- [ ] 4 JSON result files extracted from container
- [ ] Analysis script runs without errors
- [ ] High-throughput config shows ~9,900+ TPS
- [ ] Visualization PNG generated
- [ ] Analysis report markdown created

---

## Additional Resources

### Monitoring Dashboards

While tests are running, monitor in real-time:

- **Grafana**: http://localhost:3000 (admin/admin123)
- **Prometheus**: http://localhost:9090
- **JMX Metrics**: http://localhost:8080/metrics

### Docker Resource Monitoring

```bash
# Real-time resource usage
docker stats

# Check container health
docker-compose ps
```

### Clean Up

After testing:

```bash
# Stop all containers
docker-compose down

# Remove volumes (fresh start)
docker-compose down -v

# Remove all data
docker system prune -a --volumes
```

---

## Expected Timeline

| Step | Duration |
|------|----------|
| Environment Setup | 5-10 min |
| Initial Verification Tests | 5 min |
| Single Config Test | 2-3 min |
| Full Benchmark Suite | 10-15 min |
| Results Extraction | 2 min |
| Analysis | 1-2 min |
| **Total** | **25-35 min** |

---

## Citation

If you use this benchmark methodology in your research:

```
Tucci, S. (2025). Kafka Optimization for Blockchain Consensus: 
Blockchain Simulation Benchmark Results. 
GitHub: kafka-blockchain-optimization
```

---

## Support

For issues or questions:

1. Check [GitHub Issues](https://github.com/SalvatoreTucci/kafka-blockchain-optimization/issues)
2. Review troubleshooting section above
3. Verify all prerequisites are met
4. Check Docker logs for detailed error messages

---

**Last Updated**: October 2, 2025  
**Test Environment**: Docker 20.10+, Python 3.9+  
**Kafka Version**: 7.4.0  
**Status**: ✅ Validated and Reproducible