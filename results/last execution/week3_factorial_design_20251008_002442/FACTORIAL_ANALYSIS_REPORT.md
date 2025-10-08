# Factorial Design 2³ - ANOVA Analysis Report

**Generated**: 2025-10-08 00:50:55.637645

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

**Grand Mean**: 9143.35

### Main Effects

| Factor | Effect | F-value | p-value | Significance |
|--------|--------|---------|---------|-------------|
| A | +1785.15 | 7.53 | 0.0099 | ** |
| B | +20.39 | 0.00 | 0.9752 | ns |
| C | +990.99 | 2.32 | 0.1375 | ns |

### Interaction Effects

| Interaction | Effect | F-value | p-value | Significance |
|------------|--------|---------|---------|-------------|
| AB | +128.62 | 0.04 | 0.8445 | ns |
| AC | +371.56 | 0.33 | 0.5719 | ns |
| BC | -92.01 | 0.02 | 0.8884 | ns |
| ABC | +34.71 | 0.00 | 0.9578 | ns |

**R² = 0.2424** (24.24% variance explained)

## Response: AVG_LATENCY_MS

**Grand Mean**: 281.28

### Main Effects

| Factor | Effect | F-value | p-value | Significance |
|--------|--------|---------|---------|-------------|
| A | -53.37 | 7.56 | 0.0097 | ** |
| B | -0.61 | 0.00 | 0.9749 | ns |
| C | -28.22 | 2.11 | 0.1557 | ns |

### Interaction Effects

| Interaction | Effect | F-value | p-value | Significance |
|------------|--------|---------|---------|-------------|
| AB | -4.67 | 0.06 | 0.8115 | ns |
| AC | -1.21 | 0.00 | 0.9507 | ns |
| BC | +5.18 | 0.07 | 0.7911 | ns |
| ABC | -3.18 | 0.03 | 0.8711 | ns |

**R² = 0.2351** (23.51% variance explained)

## Response: E2E_P95_MS

**Grand Mean**: 117.33

### Main Effects

| Factor | Effect | F-value | p-value | Significance |
|--------|--------|---------|---------|-------------|
| A | -0.17 | 0.00 | 0.9664 | ns |
| B | +13.00 | 10.66 | 0.0026 | ** |
| C | -0.06 | 0.00 | 0.9883 | ns |

### Interaction Effects

| Interaction | Effect | F-value | p-value | Significance |
|------------|--------|---------|---------|-------------|
| AB | +0.04 | 0.00 | 0.9926 | ns |
| AC | +0.04 | 0.00 | 0.9925 | ns |
| BC | +0.02 | 0.00 | 0.9958 | ns |
| ABC | +0.00 | 0.00 | 0.9999 | ns |

**R² = 0.2499** (24.99% variance explained)

## Recommendations

Based on ANOVA results:

### Most Influential Factors (for Throughput):

1. **batch_size**: increase throughput by 1785.2 TPS

---
*Statistical significance: *** p<0.001, ** p<0.01, * p<0.05, ns not significant*
