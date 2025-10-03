# Week 2.5: Single Parameter Analysis Report

**Generated**: 2025-10-03 02:26:21.911287

## Executive Summary

Systematic testing of individual Kafka parameters to isolate effects before multi-parameter factorial design.

## Test Series Overview

1. **Batch Size Progression**: 16KB → 32KB → 65KB → 131KB
2. **Linger Time Progression**: 0ms → 5ms → 10ms → 25ms
3. **Compression Comparison**: none vs lz4 vs snappy

## Key Findings

### Batch Size Impact

- **Range tested**: 16KB to 131KB (8x increase)
- **Throughput improvement**: +35.7%
- **Conclusion**: Larger batches significantly improve throughput

### Linger Time Impact

- **Range tested**: 0ms to 25ms
- **Throughput improvement**: +5.6%
- **Latency increase**: +25.8%
- **Trade-off**: Longer linger improves throughput but increases latency

## Recommendations for Factorial Design

Based on single parameter testing:

1. **Batch size**: Test 16KB (low) vs 131KB (high) in factorial
2. **Linger time**: Test 0ms (low) vs 25ms (high) in factorial
3. **Compression**: Test none (low) vs lz4 (high) in factorial

These ranges showed significant effects and will maximize factorial design sensitivity.
