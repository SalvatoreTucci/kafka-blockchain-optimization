# Factorial Design 2³ - ANOVA Analysis Report

**Generated**: 2025-10-03 09:58:37.294683

## Design Summary

- **Design Type**: 2³ Full Factorial
- **Factors**: 3 (batch_size, linger_ms, compression)
- **Levels per factor**: 2
- **Configurations**: 8
- **Replications**: 3
- **Total tests**: 24

## Factor Levels

| Factor | Low Level | High Level |
|--------|-----------|------------|
| A: batch_size | 16KB | 128KB |
| B: linger_ms | 0ms | 25ms |
| C: compression | none | lz4 |

## Response: THROUGHPUT_TPS

**Grand Mean**: 8911.99

### Main Effects

| Factor | Effect | F-value | p-value | Significance |
|--------|--------|---------|---------|-------------|
| A | +2100.98 | 7.30 | 0.0109 | * |
| B | +390.09 | 0.25 | 0.6193 | ns |
| C | +776.67 | 1.00 | 0.3253 | ns |

### Interaction Effects

| Interaction | Effect | F-value | p-value | Significance |
|------------|--------|---------|---------|-------------|
| AB | -196.41 | 0.06 | 0.8022 | ns |
| AC | +643.19 | 0.68 | 0.4142 | ns |
| BC | +228.00 | 0.09 | 0.7712 | ns |
| ABC | -252.98 | 0.11 | 0.7470 | ns |

**R² = 0.2287** (22.87% variance explained)

## Response: AVG_LATENCY_MS

**Grand Mean**: 310.60

### Main Effects

| Factor | Effect | F-value | p-value | Significance |
|--------|--------|---------|---------|-------------|
| A | -84.82 | 2.83 | 0.1023 | ns |
| B | -35.81 | 0.50 | 0.4828 | ns |
| C | -5.13 | 0.01 | 0.9196 | ns |

### Interaction Effects

| Interaction | Effect | F-value | p-value | Significance |
|------------|--------|---------|---------|-------------|
| AB | +31.20 | 0.38 | 0.5405 | ns |
| AC | -25.47 | 0.26 | 0.6170 | ns |
| BC | -20.35 | 0.16 | 0.6892 | ns |
| ABC | +21.95 | 0.19 | 0.6664 | ns |

**R² = 0.1193** (11.93% variance explained)

## Response: E2E_P95_MS

**Grand Mean**: 117.37

### Main Effects

| Factor | Effect | F-value | p-value | Significance |
|--------|--------|---------|---------|-------------|
| A | -0.21 | 0.00 | 0.9575 | ns |
| B | +12.88 | 10.65 | 0.0026 | ** |
| C | +0.12 | 0.00 | 0.9766 | ns |

### Interaction Effects

| Interaction | Effect | F-value | p-value | Significance |
|------------|--------|---------|---------|-------------|
| AB | +0.14 | 0.00 | 0.9713 | ns |
| AC | -0.19 | 0.00 | 0.9626 | ns |
| BC | -0.11 | 0.00 | 0.9787 | ns |
| ABC | +0.16 | 0.00 | 0.9672 | ns |

**R² = 0.2498** (24.98% variance explained)

## Recommendations

Based on ANOVA results:

### Most Influential Factors (for Throughput):

1. **batch_size**: increase throughput by 2101.0 TPS

---
*Statistical significance: *** p<0.001, ** p<0.01, * p<0.05, ns not significant*
