# Week 3 Factorial Design 2³ - Design Matrix

**Generated**: $(date)

## Factorial Design Matrix

| Config | A: Batch | B: Linger | C: Compression | Coded | Replications |
|--------|----------|-----------|----------------|-------|--------------|
| config_1 | 16KB | 0ms | none | (-, -, -) | rep1, rep2, rep3 |
| config_2 | 16KB | 0ms | lz4 | (-, -, +) | rep1, rep2, rep3 |
| config_3 | 16KB | 25ms | none | (-, +, -) | rep1, rep2, rep3 |
| config_4 | 16KB | 25ms | lz4 | (-, +, +) | rep1, rep2, rep3 |
| config_5 | 128KB | 0ms | none | (+, -, -) | rep1, rep2, rep3 |
| config_6 | 128KB | 0ms | lz4 | (+, -, +) | rep1, rep2, rep3 |
| config_7 | 128KB | 25ms | none | (+, +, -) | rep1, rep2, rep3 |
| config_8 | 128KB | 25ms | lz4 | (+, +, +) | rep1, rep2, rep3 |

## Analysis

Run ANOVA with:
```bash
python3 analyze_factorial_results.py ./results/week3_factorial_design_*/
