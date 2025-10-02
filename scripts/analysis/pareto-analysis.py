#!/usr/bin/env python3
"""
Enhanced Pareto Frontier Analysis per Kafka Blockchain Optimization
1. Throughput vs Latency con Pareto-optimal corretta
2. Resource Efficiency (CPU vs Throughput) 
"""

import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path

# Configurazioni testate
configs = [
    {
        'name': 'Low-Latency\n(8KB, 0ms)', 
        'throughput': 6221.9,
        'latency': 104.63,
        'cpu': 4.14,
        'color': '#9467bd', 
        'marker': 'o'
    },
    {
        'name': 'Baseline\n(16KB, 0ms)', 
        'throughput': 6901.1,
        'latency': 104.23,
        'cpu': 3.44,
        'color': '#1f77b4', 
        'marker': 's'
    },
    {
        'name': 'Batch-Optimized\n(65KB, 10ms)', 
        'throughput': 9034.2,
        'latency': 115.42,
        'cpu': 2.84,
        'color': '#ff7f0e', 
        'marker': '^'
    },
    {
        'name': 'High-Throughput\n(131KB, 25ms)', 
        'throughput': 9828.4,
        'latency': 130.68,
        'cpu': 2.64,
        'color': '#d62728', 
        'marker': 'D'
    },
]

# Crea figura con 2 subplot
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(18, 8))

# ============================================================
# GRAFICO A: Throughput vs Latency
# ============================================================

for cfg in configs:
    ax1.scatter(cfg['latency'], cfg['throughput'], 
               s=300, c=cfg['color'], marker=cfg['marker'],
               edgecolors='black', linewidths=2, alpha=0.8,
               label=cfg['name'], zorder=3)

# Pareto-optimal: Low-Latency e High-Throughput
pareto_optimal_configs = [configs[0], configs[3]]
pareto_x = [pareto_optimal_configs[0]['latency'], pareto_optimal_configs[1]['latency']]
pareto_y = [pareto_optimal_configs[0]['throughput'], pareto_optimal_configs[1]['throughput']]

ax1.plot(pareto_x, pareto_y, 'k--', linewidth=2, alpha=0.5, 
         label='Pareto Frontier', zorder=2)

for cfg in pareto_optimal_configs:
    circle = plt.Circle((cfg['latency'], cfg['throughput']), 
                        radius=2, color='gold', fill=False, 
                        linewidth=3, zorder=4)
    ax1.add_patch(circle)

# Annotazioni
for cfg in configs:
    offset_x = 3 if cfg['name'].startswith('High') else -8
    offset_y = 200 if cfg['name'].startswith('Batch') else -200
    
    ax1.annotate(f"{cfg['throughput']:.0f} TPS\n{cfg['latency']:.1f}ms",
                 xy=(cfg['latency'], cfg['throughput']),
                 xytext=(cfg['latency'] + offset_x, cfg['throughput'] + offset_y),
                 fontsize=9, ha='center',
                 bbox=dict(boxstyle='round,pad=0.5', facecolor='white', alpha=0.8),
                 arrowprops=dict(arrowstyle='->', connectionstyle='arc3,rad=0.2', 
                                lw=1.5, color='gray'))

# Styling
ax1.set_xlabel('End-to-End Latency P95 (ms)', fontsize=13, fontweight='bold')
ax1.set_ylabel('Throughput (TPS)', fontsize=13, fontweight='bold')
ax1.set_title('(A) Throughput vs Latency Trade-off', fontsize=14, fontweight='bold', pad=15)
ax1.grid(True, alpha=0.3, linestyle='--')
ax1.legend(loc='upper left', fontsize=9, framealpha=0.95)

# Zone di preferenza
ax1.axhspan(9000, 10500, alpha=0.1, color='green')
ax1.axvspan(100, 108, alpha=0.1, color='blue')

# Annotazione Pareto-optimal
ax1.text(0.98, 0.02, 
         'Gold circles: Pareto-optimal\n(cannot improve one metric\nwithout worsening the other)',
         transform=ax1.transAxes, fontsize=8, style='italic',
         verticalalignment='bottom', horizontalalignment='right',
         bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

# ============================================================
# GRAFICO B: Resource Efficiency
# ============================================================

for cfg in configs:
    ax2.scatter(cfg['cpu'], cfg['throughput'], 
               s=300, c=cfg['color'], marker=cfg['marker'],
               edgecolors='black', linewidths=2, alpha=0.8,
               label=cfg['name'], zorder=3)

cpu_sorted = sorted(configs, key=lambda x: x['cpu'])
efficiency_x = [c['cpu'] for c in cpu_sorted]
efficiency_y = [c['throughput'] for c in cpu_sorted]

ax2.plot(efficiency_x, efficiency_y, 'g--', linewidth=2, alpha=0.5, 
         label='Efficiency Curve', zorder=2)

# Annotazioni con efficiency ratio
for cfg in configs:
    efficiency = cfg['throughput'] / cfg['cpu']
    offset_x = 0.15 if cfg['name'].startswith('High') else -0.3
    offset_y = 200 if cfg['name'].startswith('Batch') else -200
    
    ax2.annotate(f"{cfg['throughput']:.0f} TPS\n{efficiency:.0f} TPS/CPU%",
                 xy=(cfg['cpu'], cfg['throughput']),
                 xytext=(cfg['cpu'] + offset_x, cfg['throughput'] + offset_y),
                 fontsize=9, ha='center',
                 bbox=dict(boxstyle='round,pad=0.5', facecolor='lightgreen', alpha=0.8),
                 arrowprops=dict(arrowstyle='->', connectionstyle='arc3,rad=0.2', 
                                lw=1.5, color='gray'))

# Styling
ax2.set_xlabel('CPU Usage (%)', fontsize=13, fontweight='bold')
ax2.set_ylabel('Throughput (TPS)', fontsize=13, fontweight='bold')
ax2.set_title('(B) Resource Efficiency: CPU vs Throughput', fontsize=14, fontweight='bold', pad=15)
ax2.grid(True, alpha=0.3, linestyle='--')
ax2.legend(loc='upper left', fontsize=9, framealpha=0.95)

# Headroom zone
ax2.axvspan(0, 5, alpha=0.1, color='green')
ax2.text(2.5, 9500, '95%+ CPU\nHeadroom', fontsize=10, ha='center', 
         fontweight='bold',
         bbox=dict(boxstyle='round', facecolor='lightgreen', alpha=0.6))

# Calcola best efficiency
best_config = max(configs, key=lambda x: x['throughput'] / x['cpu'])
ax2.text(0.98, 0.02, 
         f"Most Efficient: {best_config['name'].strip()}\n" +
         f"{best_config['throughput']/best_config['cpu']:.0f} TPS per 1% CPU\n" +
         f"(Best throughput-to-resource ratio)",
         transform=ax2.transAxes, fontsize=8, style='italic',
         verticalalignment='bottom', horizontalalignment='right',
         bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

# Suptitle
fig.suptitle('Pareto Frontier Analysis: Kafka Blockchain Optimization', 
             fontsize=16, fontweight='bold', y=0.98)

plt.tight_layout(rect=[0, 0, 1, 0.96])

# Salva
output_dir = Path('results/pareto_analysis')
output_dir.mkdir(parents=True, exist_ok=True)
output_file = output_dir / 'pareto_frontier_complete.png'
plt.savefig(output_file, dpi=300, bbox_inches='tight')
print(f"✓ Complete Pareto analysis saved: {output_file}")

# Stampa statistiche
print("\n" + "="*60)
print("RESOURCE EFFICIENCY ANALYSIS")
print("="*60)
for cfg in configs:
    efficiency = cfg['throughput'] / cfg['cpu']
    print(f"{cfg['name'].strip():30s} {efficiency:7.0f} TPS/CPU%")
print("="*60)

plt.show()