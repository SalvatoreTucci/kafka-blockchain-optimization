# Blockchain Benchmark Analysis Report

**Generated**: 2025-10-02 17:35:29

## Executive Summary

**Best Overall Configuration**: high-throughput
**Performance Improvement**: +41.0% vs baseline

## Detailed Results

| Configuration | TPS | Blocks/s | Block Time (ms) | Finality (s) | E2E P95 (ms) |
|---------------|-----|----------|-----------------|--------------|-------------|
| baseline | 7068.9 | 65.36 | 1.80 | 0.02 | 105.08 |
| batch-optimized | 8935.9 | 72.09 | 1.81 | 0.01 | 116.25 |
| high-throughput | 9964.8 | 90.22 | 1.84 | 0.01 | 130.82 |
| low-latency | 6450.9 | 54.85 | 1.87 | 0.02 | 104.71 |

## Configuration Details

### baseline
- Batch Size: 16384 bytes
- Linger Time: 0 ms
- Compression: none

### batch-optimized
- Batch Size: 65536 bytes
- Linger Time: 10 ms
- Compression: none

### high-throughput
- Batch Size: 131072 bytes
- Linger Time: 25 ms
- Compression: none

### low-latency
- Batch Size: 8192 bytes
- Linger Time: 0 ms
- Compression: none

## Recommendations

**For Maximum Throughput**: Use `high-throughput` configuration

**For Fastest Finality**: Use `high-throughput` configuration

## Research Validation

This blockchain-aware testing demonstrates that Kafka parameter optimization significantly impacts consensus performance, validating the hypothesis that default configurations are suboptimal for blockchain ordering services.
