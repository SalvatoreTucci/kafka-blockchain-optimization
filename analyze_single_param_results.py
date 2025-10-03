#!/usr/bin/env python3
"""
Week 2.5 Analysis: Single Parameter Effects
Shows progression and isolates individual parameter impacts
"""

import json
import sys
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path

class SingleParamAnalyzer:
    def __init__(self, results_dir):
        self.results_dir = Path(results_dir)
        self.output_dir = self.results_dir / 'analysis'
        self.output_dir.mkdir(exist_ok=True)
        
    def load_results(self):
        """Load all single parameter test results"""
        print("Loading single parameter test results...")
        
        data = []
        for json_file in self.results_dir.glob('*/*_result.json'):
            with open(json_file, 'r') as f:
                result = json.load(f)
                
                config_name = result['config_name']
                metrics = result['metrics']
                config = result['config']
                
                # Load CPU stats
                stats_file = json_file.parent / 'enhanced-stats.csv'
                cpu_avg = 0
                if stats_file.exists():
                    cpu_df = pd.read_csv(stats_file)
                    cpu_avg = cpu_df['cpu_percent'].mean()
                
                data.append({
                    'test': config_name,
                    'batch_size': config['batch_size'],
                    'linger_ms': config['linger_ms'],
                    'compression': config['compression_type'],
                    'throughput': metrics['transaction_submission']['throughput_tps'],
                    'latency_p95': metrics['end_to_end_latency']['p95_latency_ms'],
                    'cpu_avg': cpu_avg
                })
        
        return pd.DataFrame(data)
    
    def analyze_batch_progression(self, df):
        """Analyze batch size progression"""
        print("\n" + "="*70)
        print("BATCH SIZE PROGRESSION ANALYSIS")
        print("="*70)
        
        # Filter batch series (linger=0, compression=none)
        batch_series = df[
            (df['linger_ms'] == 0) & 
            (df['compression'] == 'none')
        ].sort_values('batch_size')
        
        if len(batch_series) == 0:
            print("No batch series data found")
            return
        
        print("\n| Batch Size | TPS | Latency P95 | CPU % | TPS/CPU% | vs Baseline |")
        print("|------------|-----|-------------|-------|----------|-------------|")
        
        baseline = batch_series.iloc[0]
        baseline_tps = baseline['throughput']
        
        for _, row in batch_series.iterrows():
            batch_kb = row['batch_size'] // 1024
            tps = row['throughput']
            lat = row['latency_p95']
            cpu = row['cpu_avg']
            efficiency = tps / cpu if cpu > 0 else 0
            improvement = ((tps - baseline_tps) / baseline_tps) * 100
            
            print(f"| {batch_kb:3d}KB | {tps:7.0f} | {lat:8.1f}ms | {cpu:5.2f} | "
                  f"{efficiency:8.0f} | {improvement:+6.1f}% |")
        
        # Plot
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))
        
        batch_labels = [f"{b//1024}KB" for b in batch_series['batch_size']]
        
        # Throughput
        ax1.plot(batch_labels, batch_series['throughput'], 
                marker='o', linewidth=2, markersize=10, color='steelblue')
        ax1.set_xlabel('Batch Size', fontweight='bold')
        ax1.set_ylabel('Throughput (TPS)', fontweight='bold')
        ax1.set_title('Batch Size vs Throughput', fontweight='bold')
        ax1.grid(True, alpha=0.3)
        
        for i, (label, tps) in enumerate(zip(batch_labels, batch_series['throughput'])):
            ax1.text(i, tps + 200, f'{tps:.0f}', ha='center', fontweight='bold')
        
        # Latency
        ax2.plot(batch_labels, batch_series['latency_p95'],
                marker='s', linewidth=2, markersize=10, color='coral')
        ax2.set_xlabel('Batch Size', fontweight='bold')
        ax2.set_ylabel('Latency P95 (ms)', fontweight='bold')
        ax2.set_title('Batch Size vs Latency', fontweight='bold')
        ax2.grid(True, alpha=0.3)
        
        for i, (label, lat) in enumerate(zip(batch_labels, batch_series['latency_p95'])):
            ax2.text(i, lat + 2, f'{lat:.1f}', ha='center', fontweight='bold')
        
        plt.tight_layout()
        plt.savefig(self.output_dir / 'batch_progression.png', dpi=300, bbox_inches='tight')
        print(f"\n✓ Saved: {self.output_dir / 'batch_progression.png'}")
    
    def analyze_linger_progression(self, df):
        """Analyze linger time progression"""
        print("\n" + "="*70)
        print("LINGER TIME PROGRESSION ANALYSIS")
        print("="*70)
        
        # Filter linger series (batch=65KB, compression=none)
        linger_series = df[
            (df['batch_size'] == 65536) & 
            (df['compression'] == 'none')
        ].sort_values('linger_ms')
        
        if len(linger_series) == 0:
            print("No linger series data found")
            return
        
        print("\n| Linger MS | TPS | Latency P95 | CPU % | vs Baseline |")
        print("|-----------|-----|-------------|-------|-------------|")
        
        baseline = linger_series.iloc[0]
        baseline_tps = baseline['throughput']
        
        for _, row in linger_series.iterrows():
            linger = row['linger_ms']
            tps = row['throughput']
            lat = row['latency_p95']
            cpu = row['cpu_avg']
            improvement = ((tps - baseline_tps) / baseline_tps) * 100
            
            print(f"| {linger:4d}ms | {tps:7.0f} | {lat:8.1f}ms | {cpu:5.2f} | {improvement:+6.1f}% |")
        
        # Plot
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))
        
        linger_labels = [f"{l}ms" for l in linger_series['linger_ms']]
        
        # Throughput
        ax1.plot(linger_labels, linger_series['throughput'],
                marker='o', linewidth=2, markersize=10, color='green')
        ax1.set_xlabel('Linger Time', fontweight='bold')
        ax1.set_ylabel('Throughput (TPS)', fontweight='bold')
        ax1.set_title('Linger Time vs Throughput', fontweight='bold')
        ax1.grid(True, alpha=0.3)
        
        # Latency
        ax2.plot(linger_labels, linger_series['latency_p95'],
                marker='s', linewidth=2, markersize=10, color='orange')
        ax2.set_xlabel('Linger Time', fontweight='bold')
        ax2.set_ylabel('Latency P95 (ms)', fontweight='bold')
        ax2.set_title('Linger Time vs Latency', fontweight='bold')
        ax2.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(self.output_dir / 'linger_progression.png', dpi=300, bbox_inches='tight')
        print(f"\n✓ Saved: {self.output_dir / 'linger_progression.png'}")
    
    def analyze_compression(self, df):
        """Analyze compression comparison"""
        print("\n" + "="*70)
        print("COMPRESSION TYPE COMPARISON")
        print("="*70)
        
        # Filter compression series (batch=65KB, linger=10ms)
        comp_series = df[
            (df['batch_size'] == 65536) & 
            (df['linger_ms'] == 10)
        ]
        
        if len(comp_series) == 0:
            print("No compression series data found")
            return
        
        print("\n| Compression | TPS | Latency P95 | CPU % | vs None |")
        print("|-------------|-----|-------------|-------|---------|")
        
        baseline_row = comp_series[comp_series['compression'] == 'none']
        baseline_tps = baseline_row['throughput'].iloc[0] if len(baseline_row) > 0 else 0
        
        for _, row in comp_series.iterrows():
            comp = row['compression']
            tps = row['throughput']
            lat = row['latency_p95']
            cpu = row['cpu_avg']
            improvement = ((tps - baseline_tps) / baseline_tps) * 100 if baseline_tps > 0 else 0
            
            print(f"| {comp:11s} | {tps:7.0f} | {lat:8.1f}ms | {cpu:5.2f} | {improvement:+6.1f}% |")
        
        print("\n💡 INSIGHT: Compression typically adds CPU overhead with minimal")
        print("   throughput benefit for blockchain workloads (already compact transactions)")
    
    def generate_report(self, df):
        """Generate markdown report"""
        print("\nGenerating comprehensive report...")
        
        report_file = self.output_dir / 'SINGLE_PARAM_ANALYSIS.md'
        
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write("# Week 2.5: Single Parameter Analysis Report\n\n")
            f.write(f"**Generated**: {pd.Timestamp.now()}\n\n")
            
            f.write("## Executive Summary\n\n")
            f.write("Systematic testing of individual Kafka parameters to isolate effects ")
            f.write("before multi-parameter factorial design.\n\n")
            
            f.write("## Test Series Overview\n\n")
            f.write("1. **Batch Size Progression**: 16KB → 32KB → 65KB → 131KB\n")
            f.write("2. **Linger Time Progression**: 0ms → 5ms → 10ms → 25ms\n")
            f.write("3. **Compression Comparison**: none vs lz4 vs snappy\n\n")
            
            f.write("## Key Findings\n\n")
            
            # Batch size findings
            batch_series = df[(df['linger_ms'] == 0) & (df['compression'] == 'none')].sort_values('batch_size')
            if len(batch_series) > 1:
                min_tps = batch_series['throughput'].min()
                max_tps = batch_series['throughput'].max()
                improvement = ((max_tps - min_tps) / min_tps) * 100
                
                f.write(f"### Batch Size Impact\n\n")
                f.write(f"- **Range tested**: 16KB to 131KB (8x increase)\n")
                f.write(f"- **Throughput improvement**: +{improvement:.1f}%\n")
                f.write(f"- **Conclusion**: Larger batches significantly improve throughput\n\n")
            
            # Linger time findings
            linger_series = df[(df['batch_size'] == 65536) & (df['compression'] == 'none')].sort_values('linger_ms')
            if len(linger_series) > 1:
                baseline_tps = linger_series.iloc[0]['throughput']
                baseline_lat = linger_series.iloc[0]['latency_p95']
                max_tps = linger_series['throughput'].max()
                max_lat = linger_series['latency_p95'].max()
                tps_improvement = ((max_tps - baseline_tps) / baseline_tps) * 100
                lat_increase = ((max_lat - baseline_lat) / baseline_lat) * 100
                
                f.write(f"### Linger Time Impact\n\n")
                f.write(f"- **Range tested**: 0ms to 25ms\n")
                f.write(f"- **Throughput improvement**: +{tps_improvement:.1f}%\n")
                f.write(f"- **Latency increase**: +{lat_increase:.1f}%\n")
                f.write(f"- **Trade-off**: Longer linger improves throughput but increases latency\n\n")
            
            f.write("## Recommendations for Factorial Design\n\n")
            f.write("Based on single parameter testing:\n\n")
            f.write("1. **Batch size**: Test 16KB (low) vs 131KB (high) in factorial\n")
            f.write("2. **Linger time**: Test 0ms (low) vs 25ms (high) in factorial\n")
            f.write("3. **Compression**: Test none (low) vs lz4 (high) in factorial\n\n")
            f.write("These ranges showed significant effects and will maximize ")
            f.write("factorial design sensitivity.\n")
        
        print(f"✓ Report saved: {report_file}")
    
    def run_analysis(self):
        """Run complete analysis"""
        print("\n" + "="*70)
        print("WEEK 2.5: SINGLE PARAMETER ANALYSIS")
        print("="*70)
        
        df = self.load_results()
        
        if len(df) == 0:
            print("No data to analyze!")
            return
        
        self.analyze_batch_progression(df)
        self.analyze_linger_progression(df)
        self.analyze_compression(df)
        self.generate_report(df)
        
        print("\n" + "="*70)
        print("ANALYSIS COMPLETE")
        print("="*70)
        print(f"\nResults saved in: {self.output_dir}/")

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_single_param_results.py <results_directory>")
        sys.exit(1)
    
    results_dir = sys.argv[1]
    analyzer = SingleParamAnalyzer(results_dir)
    analyzer.run_analysis()

if __name__ == "__main__":
    main()