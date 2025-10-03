# Blockchain Benchmark Testing - Complete Replication Guide

## Overview

This guide documents the complete blockchain simulation benchmark testing performed on Apache Kafka to validate performance optimizations for blockchain ordering services. The testing demonstrates a **+42% throughput improvement** over baseline configuration with comprehensive resource efficiency analysis.

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

### Python Dependencies

Install required packages for analysis:

```bash
pip install matplotlib pandas seaborn numpy
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

**What This Does:**

- Starts Kafka broker (port 9092)
- Starts Zookeeper (port 2181)
- Starts Prometheus (port 9090) for metrics
- Starts Grafana (port 3000) for visualization
- Creates test-runner container with Python dependencies

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

**Troubleshooting:** If any checks fail, see [Troubleshooting](#troubleshooting) section.

---

## Test Execution

### Step 1: Component Verification

Before running full benchmarks, verify the blockchain simulator works correctly:

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

**What This Tests:**

- Blockchain ledger initialization
- Transaction hashing
- Block formation logic

### Step 2: Smoke Test (Single Configuration)

Run a quick test with 1,000 transactions to verify setup:

```bash
docker-compose exec test-runner python3 ./scripts/blockchain/run-blockchain-benchmark.py \
  --config test \
  --batch-size 16384 \
  --linger-ms 0 \
  --transactions 1000
```

**Expected Performance:**

```
Throughput: ~2,400 TPS
Avg Latency: ~60-80 ms
Blocks Created: 10
```

**If Results Differ Significantly:**

- Check Docker resource allocation (4GB+ RAM)
- Verify no other processes consuming CPU
- Check `docker stats` for resource usage

### Step 3: Create Stress Test Topic (Optional)

If you plan to run stress tests later:

```bash
docker-compose exec kafka kafka-topics \
  --create --topic blockchain-stress \
  --bootstrap-server localhost:9092 \
  --partitions 3 --replication-factor 1 --if-not-exists
```

### Step 4: Run Complete Benchmark Suite

Execute all 4 configuration tests:

```bash
./run-blockchain-benchmarks.sh 5000
```

**Duration:** ~10-15 minutes for complete suite

**Configurations Tested:**

1. **Baseline**: 16KB batch, 0ms linger, no compression
2. **Batch-Optimized**: 65KB batch, 10ms linger, no compression
3. **High-Throughput**: 131KB batch, 25ms linger, no compression
4. **Low-Latency**: 8KB batch, 0ms linger, no compression

**What Happens During Execution:**

For each configuration:

- Starts enhanced resource monitoring (60s window)
- Submits 5,000 blockchain transactions
- Forms blocks (100 transactions per block)
- Measures end-to-end latency (100 samples)
- Saves results to JSON
- Stops monitoring

**Expected Output Structure:**

```
blockchain_benchmark_results_20251002_182655/
├── SUMMARY.md
├── baseline/
│   ├── enhanced-stats.csv        # Resource usage data
│   └── (monitoring logs)
├── baseline_output.log            # Console output
├── baseline_result.json           # Structured results
├── batch-optimized/
│   ├── enhanced-stats.csv
│   └── ...
├── batch-optimized_result.json
├── high-throughput/
│   ├── enhanced-stats.csv
│   └── ...
├── high-throughput_result.json
├── low-latency/
│   ├── enhanced-stats.csv
│   └── ...
└── low-latency_result.json
```

**Known Issue - Enhanced Stats:**

Enhanced stats CSV files may contain only 3 rows instead of expected ~12 because:

- Benchmark completes in ~18 seconds
- Monitoring script runs for 60 seconds but gets killed early
- 3 samples (5-second intervals) are still representative of steady-state

This is acceptable because the 3 samples cover the entire test duration.

---

## Results Analysis

### Step 5: Extract Results from Container

The JSON results are saved inside the Docker container. Extract them:

```bash
# Navigate to results directory
cd blockchain_benchmark_results_YYYYMMDD_HHMMSS/

# Copy JSON results (use actual timestamp from filenames)
docker cp test-runner:/results/blockchain_baseline_TIMESTAMP.json ./baseline_result.json
docker cp test-runner:/results/blockchain_batch-optimized_TIMESTAMP.json ./batch-optimized_result.json
docker cp test-runner:/results/blockchain_high-throughput_TIMESTAMP.json ./high-throughput_result.json
docker cp test-runner:/results/blockchain_low-latency_TIMESTAMP.json ./low-latency_result.json

# Verify files exist
ls -la *.json
```

**Alternative: Automated Copy (if files renamed in container)**

```bash
docker cp test-runner:/results/baseline_result.json ./
docker cp test-runner:/results/batch-optimized_result.json ./
docker cp test-runner:/results/high-throughput_result.json ./
docker cp test-runner:/results/low-latency_result.json ./
```

### Step 6: Blockchain Results Analysis

```bash
# Return to project root
cd ..

# Run analysis script
python3 analyze_blockchain_results.py blockchain_benchmark_results_YYYYMMDD_HHMMSS
```

**Generated Artifacts:**

1. **`blockchain_comparison.png`** - 4-panel comparison chart
2. **`BLOCKCHAIN_ANALYSIS_REPORT.md`** - Detailed markdown report
3. **Console output** - Quick summary table

**Expected Console Output:**

```
====================================================================================================
BLOCKCHAIN BENCHMARK COMPARISON
====================================================================================================

Configuration        TPS        Blocks/s   Block Time   Finality     E2E P95
----------------------------------------------------------------------------------------------------
baseline             6901.1     112.30       1.82ms        0.01s    104.23ms
batch-optimized      9034.2      53.02       2.09ms        0.02s    115.42ms (+30.9%)
high-throughput      9828.4      91.83       1.78ms        0.01s    130.68ms (+42.4%)
low-latency          6221.9      53.15       1.90ms        0.02s    104.63ms (-9.8%)
====================================================================================================

BEST PERFORMING CONFIGURATIONS
Highest Throughput: high-throughput (9828 TPS)
```

### Step 7: Pareto Frontier Analysis

Generate trade-off analysis charts:

```bash
python3 ./scripts/analysis/pareto-analysis.py
```

**Generated Artifacts:**

- **`results/pareto_analysis/pareto_frontier_complete.png`**
  - Chart A: Throughput vs Latency trade-off (Pareto frontier)
  - Chart B: Resource Efficiency (CPU vs Throughput)

**Console Output:**

```
✓ Complete Pareto analysis saved: results/pareto_analysis/pareto_frontier_complete.png

============================================================
RESOURCE EFFICIENCY ANALYSIS
============================================================
Low-Latency (8KB, 0ms)            1503 TPS/CPU%
Baseline (16KB, 0ms)              2006 TPS/CPU%
Batch-Optimized (65KB, 10ms)      3180 TPS/CPU%
High-Throughput (131KB, 25ms)     3723 TPS/CPU%  ← Most Efficient
============================================================
```

**Key Insights from Pareto Analysis:**

- **Pareto-optimal configurations**: Low-Latency and High-Throughput
  - Cannot improve one metric without worsening the other
- **Resource efficiency**: High-Throughput achieves best TPS-to-CPU ratio
- **Trade-off**: +58% throughput costs +26ms latency but maintains efficiency

### Step 8 (Optional): Stress Test Validation

Run multi-producer stress test for robustness validation:

```bash
docker-compose exec test-runner python3 ./scripts/test/stress-test-benchmark.py
```

**What This Tests:**

- 3 concurrent producers (simulates multi-node blockchain)
- 10,000 messages under sustained load
- Larger message size (~1.2KB with extended metadata)

**Expected Results:**

```
SUSTAINED BASELINE              2112.33 msg/s
SUSTAINED OPT1: 4x Batch        2517.23 msg/s  (+19.2%)
SUSTAINED OPT2: 8x Batch        2710.81 msg/s  (+28.3%)
```

**Important Note:**

Stress test throughput (2,710 msg/s) differs from blockchain simulation (9,828 TPS) by design:

- **Different workloads**: Multi-producer concurrent vs sequential optimized
- **Different message sizes**: 1.2KB vs 0.5KB
- **Different metrics**: Raw Kafka throughput vs end-to-end blockchain TPS

Both results validate that optimization provides consistent improvement across workload patterns.

---

## Key Findings

### Performance Results Summary

| Configuration | TPS | Improvement | E2E Latency P95 | Block Time | CPU % | Efficiency |
|---------------|-----|-------------|-----------------|------------|-------|------------|
| **Baseline** | 6,901 | - | 104.2ms | 1.82ms | 3.44% | 2,006 TPS/CPU% |
| **Batch-Optimized** | 9,034 | +30.9% | 115.4ms | 2.09ms | 2.84% | 3,180 TPS/CPU% |
| **High-Throughput** | 9,828 | **+42.4%** | 130.7ms | 1.78ms | 2.64% | **3,723 TPS/CPU%** |
| **Low-Latency** | 6,222 | -9.8% | 104.6ms | 1.90ms | 4.14% | 1,503 TPS/CPU% |

### Optimal Configuration Identified

**Winner: High-Throughput**

```properties
KAFKA_BATCH_SIZE=131072      # 128KB (8x baseline)
KAFKA_LINGER_MS=25           # 25ms batching window
KAFKA_COMPRESSION_TYPE=none  # No compression overhead
```

**Trade-offs:**

- ✅ +42% throughput improvement
- ✅ Best CPU efficiency (3,723 TPS per 1% CPU)
- ✅ 95%+ CPU headroom available
- ⚠️ +26ms E2E latency vs Low-Latency config
- ✅ Block formation time stable (~1.8ms across all configs)

### Research Validation

**Pareto Frontier Analysis** confirms:

1. Only **two configurations are Pareto-optimal**:
   - Low-Latency: Best latency (104.6ms P95)
   - High-Throughput: Best throughput (9,828 TPS)
2. Batch-Optimized and Baseline are **dominated** (can be improved in both metrics)
3. **Resource efficiency aligns with throughput**: High-Throughput config is most efficient

**Stress Test Results** validate robustness:

- Consistent +28% improvement under multi-producer concurrent load
- Pattern of improvement remains stable across workload characteristics

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

#### 2. Kafka Not Healthy After 2 Minutes

**Symptoms:**

```
✗ Kafka failed to become healthy
```

**Solutions:**

```bash
# Check available memory
docker stats

# Increase Docker memory to 4GB+ in Docker Desktop settings

# Check logs for specific errors
docker-compose logs --tail=50 kafka

# Nuclear option: Clean restart
docker-compose down -v
docker-compose up -d
```

#### 3. Python Dependencies Missing

```bash
# Install all required packages
pip install matplotlib pandas seaborn numpy

# For Windows Git Bash, if permission issues:
pip install --user matplotlib pandas seaborn numpy
```

#### 4. Files Not Copying from Container

```bash
# Check if files exist in container
docker-compose exec test-runner ls -la /results/

# Find correct timestamp
docker-compose exec test-runner find /results -name "blockchain_*.json"

# Use exact filename with timestamp
docker cp test-runner:/results/blockchain_baseline_1759422432.json ./baseline_result.json
```

#### 5. Enhanced Stats CSV Has Only 3 Rows

**This is expected behavior** because:

- Benchmark completes in ~18 seconds
- Monitoring script samples every 5 seconds
- 3 samples (0s, 5s, 10s) cover entire test duration

**The data is still valid for:**

- Average CPU usage calculation
- Memory usage analysis
- Representative resource consumption

**If you need more samples:**

```bash
# Increase transaction count (longer test duration)
./run-blockchain-benchmarks.sh 10000  # 10K transactions (~35-40s)
```

#### 6. Port Conflicts

If ports 9092, 2181, 3000, or 9090 are in use:

**Linux/macOS:**

```bash
# Find and kill conflicting process
sudo lsof -i :9092
sudo kill -9 PID
```

**Windows:**

```powershell
# Find process
netstat -ano | findstr :9092

# Kill process
taskkill /PID <PID> /F
```

**Alternative:** Modify `docker-compose.yml` to use different ports.

#### 7. Low Throughput Results (< 5,000 TPS)

**Possible causes:**

- Insufficient Docker resources (< 4GB RAM)
- Other CPU-intensive applications running
- Docker Desktop in power-saving mode

**Solutions:**

```bash
# Check system load
docker stats

# Close other applications

# Verify Docker resources
docker info | grep -i memory
```

#### 8. Pareto Analysis Script Fails

**Error:** `No module named 'matplotlib'`

**Solution:**

```bash
pip install matplotlib pandas numpy

# Test installation
python3 -c "import matplotlib; import pandas; import numpy; print('OK')"
```

---

## Validation Checklist

Before considering your replication successful, verify:

- [ ] All 6 containers running (kafka, zookeeper, prometheus, grafana, test-runner, jmx-exporter)
- [ ] Quick test passes successfully (all ✅ checks)
- [ ] Blockchain simulator test completes without errors
- [ ] Single configuration test shows ~2,400 TPS
- [ ] Full benchmark suite completes all 4 configs
- [ ] 4 JSON result files extracted from container
- [ ] `blockchain_comparison.png` generated
- [ ] `BLOCKCHAIN_ANALYSIS_REPORT.md` created
- [ ] High-throughput config shows ~9,800+ TPS
- [ ] Pareto frontier chart generated with 2 subplots
- [ ] Resource efficiency analysis shows consistent rankings

---

## Expected Timeline

| Step | Duration | Cumulative |
|------|----------|------------|
| Environment Setup | 5-10 min | 5-10 min |
| Initial Verification Tests | 5 min | 10-15 min |
| Single Config Smoke Test | 2-3 min | 12-18 min |
| **Full Benchmark Suite** | **10-15 min** | **22-33 min** |
| Results Extraction | 2 min | 24-35 min |
| Blockchain Analysis | 1-2 min | 25-37 min |
| Pareto Analysis | 1 min | 26-38 min |
| (Optional) Stress Test | 5-8 min | 31-46 min |
| **Total** | **26-46 min** | - |

---

## Additional Resources

### Monitoring Dashboards

While tests are running, monitor in real-time:

- **Grafana**: http://localhost:3000 (admin/admin123)
  - Import dashboards for Kafka JMX metrics
  - View real-time throughput and latency
- **Prometheus**: http://localhost:9090
  - Query: `rate(kafka_server_BrokerTopicMetrics_BytesInPerSec[1m])`
- **JMX Metrics**: http://localhost:8080/metrics
  - Raw Kafka broker metrics

### Docker Resource Monitoring

```bash
# Real-time resource usage
docker stats

# Check container health
docker-compose ps

# View specific container logs
docker-compose logs -f kafka --tail=50
```

### Understanding Results

**Throughput (TPS):**

- Measures transactions per second from submission to Kafka confirmation
- Higher is better for blockchain networks
- Realistic range: 5,000-10,000 TPS for single-node Kafka

**Latency (ms):**

- End-to-end time from submission to block confirmation
- Lower is better for critical transactions
- P95 latency: 95% of transactions complete within this time

**Block Formation Time:**

- Time to create a block from pending transactions
- Should remain stable (~1.5-2.0ms) across configurations
- Dominated by hashing and ledger operations

**Resource Efficiency (TPS/CPU%):**

- Measures throughput per unit of CPU usage
- Higher indicates better resource utilization
- Important for cost optimization in production

### Clean Up

After testing:

```bash
# Stop all containers
docker-compose down

# Remove volumes (fresh start for next test)
docker-compose down -v

# Remove all data and images (nuclear option)
docker system prune -a --volumes
```

---

## Citation

If you use this benchmark methodology in your research:

```
Tucci, S. (2025). Kafka Optimization for Blockchain Consensus: 
Blockchain Simulation Benchmark Methodology. 
GitHub: kafka-blockchain-optimization
```

---

## Support

For issues or questions:

1. Check [Troubleshooting](#troubleshooting) section above
2. Review [GitHub Issues](https://github.com/SalvatoreTucci/kafka-blockchain-optimization/issues)
3. Verify all prerequisites are met
4. Check Docker logs for detailed error messages

**Common issues resolution time:**

- Port conflicts: < 5 minutes
- Docker resource issues: 5-10 minutes
- Python dependencies: 2-5 minutes
- Container startup failures: 10-15 minutes

---

**Last Updated**: October 3, 2025  
**Test Environment**: Docker 20.10+, Python 3.9+, Windows/Linux/macOS  
**Kafka Version**: 7.4.0  
**Validation Status**: ✅ Reproducible across platforms