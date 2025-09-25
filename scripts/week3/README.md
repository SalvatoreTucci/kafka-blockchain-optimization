# Week 3: Factorial Design Scripts

Directory contenente tutti gli script per l'implementazione del factorial design 2³.

## Struttura Directory

```
scripts/week3/
├── README.md                           # Questo file
├── setup-week3-factorial.sh           # Setup automatico dipendenze
├── kafka-factorial-benchmark.sh       # Benchmark factorial design 2³
├── analyze_factorial_results.py       # Analisi statistica ANOVA
└── templates/
    ├── factorial-config-template.env  # Template configurazioni
    └── anova-requirements.txt          # Lista dipendenze Python
```

## Quick Start

```bash
# 1. Setup completo ambiente
./scripts/week3/setup-week3-factorial.sh

# 2. Esegui factorial design (8 config × 3 runs)
./scripts/week3/kafka-factorial-benchmark.sh 3 300 1000

# 3. Analizza risultati
python3 scripts/week3/analyze_factorial_results.py factorial_results_TIMESTAMP
```

## Factor Levels

**Factorial Design 2³:**
- **Factor A (Batch Size):** 16KB (low), 65KB (high)
- **Factor B (Linger Time):** 0ms (low), 10ms (high)
- **Factor C (Compression):** none (low), lz4 (high)

## Dependencies

**Python Packages Required:**
```
matplotlib>=3.5.0
pandas>=1.3.0
seaborn>=0.11.0
numpy>=1.21.0
scipy>=1.7.0
statsmodels>=0.13.0
```

## Timing Estimates

- **Setup:** ~3 minutes
- **Factorial Benchmark:** ~2-3 hours (8 configs × 3 runs × 5 min)
- **Statistical Analysis:** ~10 minutes
- **Total Week 3:** ~3-4 hours
