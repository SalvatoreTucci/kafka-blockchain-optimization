# Week 2.5 Single Parameter Tests - Results Index

**Generated**: mer  8 ott 2025 00:24:39
**Total Tests**: 11
**Results Directory**: results/week2.5_single_param_20251008_002017

## Test Structure

```
results/week2.5_single_param_20251008_002017/
├── batch_16kb/
│   ├── output.log
│   ├── enhanced-stats.csv
│   └── batch_16kb_result.json
├── batch_32kb/
├── batch_65kb/
├── batch_131kb/
├── linger_0ms/
├── linger_5ms/
├── linger_10ms/
├── linger_25ms/
├── compression_none/
├── compression_lz4/
├── compression_snappy/
└── analysis/ (generated after running analyze script)
```

## Test Series

### Series 1: Batch Size Progression
- batch_16kb (baseline: 16KB, 0ms, none)
- batch_32kb (32KB, 0ms, none)
- batch_65kb (65KB, 0ms, none)
- batch_131kb (128KB, 0ms, none)

### Series 2: Linger Time Progression
- linger_0ms (65KB, 0ms, none)
- linger_5ms (65KB, 5ms, none)
- linger_10ms (65KB, 10ms, none)
- linger_25ms (65KB, 25ms, none)

### Series 3: Compression Comparison
- compression_none (65KB, 10ms, none)
- compression_lz4 (65KB, 10ms, lz4)
- compression_snappy (65KB, 10ms, snappy)

## Analysis

Run analysis with:
```bash
python3 analyze_single_param_results.py results/week2.5_single_param_20251008_002017
```

Analysis output will be saved in: results/week2.5_single_param_20251008_002017/analysis/
