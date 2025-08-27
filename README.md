# Tesi-Magistrale-Apache-Kafka-applicato-ad-una-blockchain
Apache Kafka per il miglioramento delle performance nell'implementazione di una blockchain

# Kafka Optimization for Blockchain Consensus: Bridging the Performance Gap

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-20.10+-blue.svg)](https://www.docker.com/)
[![Python](https://img.shields.io/badge/Python-3.8+-green.svg)](https://www.python.org/)

## 🎯 Research Objective

This research addresses a critical gap in blockchain consensus performance: **no previous study has systematically optimized Apache Kafka parameters for blockchain workloads**. While studies consistently show Raft outperforming Kafka in blockchain scenarios, these comparisons use default Kafka configurations, ignoring dozens of performance-critical parameters.

### Key Hypothesis
*"Properly optimized Kafka can outperform Raft in blockchain scenarios, especially for high-throughput workloads."*

## 📊 Research Gap Identified

Based on analysis of recent papers:
- **Raft vs Kafka studies use default Kafka configurations** (confirmed across 3+ papers)
- **Raft consumes 35% fewer CPU cycles** - but with unoptimized Kafka
- **Kafka consumes less network bandwidth** - suggesting architectural efficiency
- **No systematic parameter optimization** for blockchain workloads

## 🚀 Quick Start

```bash
# Clone and setup
git clone https://github.com/[your-username]/kafka-blockchain-optimization
cd kafka-blockchain-optimization

# Deploy baseline environment
./scripts/deploy/deploy-baseline.sh

# Run first benchmark
python scripts/test/run-benchmark.py --config baseline

# View results
open http://localhost:3000  # Grafana dashboard