# Blockchain Benchmark Analysis Report

**Generated**: 2025-10-02 19:17:18

## Executive Summary

**Best Overall Configuration**: high-throughput
**Performance Improvement**: +42.4% vs baseline

## Detailed Results

| Configuration | TPS | Blocks/s | Block Time (ms) | Finality (s) | E2E P95 (ms) |
|---------------|-----|----------|-----------------|--------------|-------------|
| baseline | 6901.1 | 112.30 | 1.82 | 0.01 | 104.23 |
| batch-optimized | 9034.2 | 53.02 | 2.09 | 0.02 | 115.42 |
| high-throughput | 9828.4 | 91.83 | 1.78 | 0.01 | 130.68 |
| low-latency | 6221.9 | 53.15 | 1.90 | 0.02 | 104.63 |

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

**For Fastest Finality**: Use `baseline` configuration

## Research Validation

This blockchain-aware testing demonstrates that Kafka parameter optimization significantly impacts consensus performance, validating the hypothesis that default configurations are suboptimal for blockchain ordering services.
