# Blockchain Benchmark Analysis Report

**Generated**: 2025-10-02 01:51:30

## Executive Summary

**Best Overall Configuration**: high-throughput
**Performance Improvement**: +34.2% vs baseline

## Detailed Results

| Configuration | TPS | Blocks/s | Block Time (ms) | Finality (s) | E2E P95 (ms) |
|---------------|-----|----------|-----------------|--------------|-------------|
| baseline | 7249.5 | 113.76 | 1.79 | 0.01 | 105.24 |
| batch-optimized | 9372.2 | 56.84 | 1.75 | 0.02 | 116.19 |
| high-throughput | 9727.2 | 108.26 | 1.86 | 0.01 | 132.59 |
| low-latency | 6369.0 | 45.26 | 1.75 | 0.02 | 104.85 |

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
