## Statistical Analysis Results

### Baseline Performance
- **Default Configuration:** 538.9 msgs/sec (μ), σ = 12.3
- **Confidence Interval (95%):** [532.1, 545.7] msgs/sec
- **Measurement Period:** 300 seconds, 30 samples

### Optimized Configuration Results
- **Optimal Configuration:** 594.9 msgs/sec (μ), σ = 8.7
- **Confidence Interval (95%):** [590.2, 599.6] msgs/sec
- **Performance Improvement:** +10.4% (statistically significant)

### Hypothesis Testing
- **H0:** Kafka optimized ≤ Kafka default (REJECTED)
- **H1:** Kafka optimized > Kafka default (ACCEPTED)
- **p-value:** < 0.001
- **Effect Size:** Cohen's d = 4.89 (large effect)