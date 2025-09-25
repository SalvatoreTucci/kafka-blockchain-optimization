#!/usr/bin/env python3
"""
Week 4 Validation Results Analyzer
Confronta risultati ottimali con baseline e calcola improvements
"""

import statistics
import json
from pathlib import Path

def analyze_validation_results():
    print("Week 4 Validation Analysis")
    print("=" * 40)
    
    # Baseline da Week 2/3 (config_000)
    baseline = {
        'throughput': 1000.1,
        'latency': 2.57,
        'config': 'config_000 (16KB, 0ms, none)'
    }
    
    # Optimal da Week 3 (config_100)
    optimal = {
        'throughput': 1000.1, 
        'latency': 2.00,
        'config': 'config_100 (65KB, 0ms, none)'
    }
    
    print(f"Baseline Performance: {baseline['throughput']:.1f} TPS, {baseline['latency']:.2f}ms")
    print(f"Optimal Performance:  {optimal['throughput']:.1f} TPS, {optimal['latency']:.2f}ms")
    print()
    
    # Calcola improvements
    latency_improvement = ((baseline['latency'] - optimal['latency']) / baseline['latency']) * 100
    
    print(f"Latency Improvement: {latency_improvement:.1f}%")
    print(f"Throughput Maintained: {optimal['throughput']:.1f} TPS")
    print()
    
    print("Production Recommendation: config_100")
    print("- Batch Size: 65KB (large batch efficiency)")
    print("- Linger Time: 0ms (no batching delay)")  
    print("- Compression: none (no overhead)")

if __name__ == "__main__":
    analyze_validation_results()
