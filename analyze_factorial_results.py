#!/usr/bin/env python3
"""
Factorial Design ANOVA Analysis
Statistical analysis of 2³ factorial design results
"""

import json
import sys
import pandas as pd
import numpy as np
from pathlib import Path
from itertools import product

try:
    import matplotlib.pyplot as plt
    import seaborn as sns
    from scipy import stats
    PLOTTING = True
except ImportError:
    PLOTTING = False
    print("Warning: matplotlib/seaborn not available")

class FactorialAnalysis:
    def __init__(self, results_dir):
        self.results_dir = Path(results_dir)
        self.data = []
        
    def load_results(self):
        """Load all factorial design results"""
        print("Loading factorial design results...")
        
        json_files = list(self.results_dir.glob('*/config_*_result.json'))
        
        if not json_files:
            print(f"No result files found in {self.results_dir}")
            return False
        
        print(f"Found {len(json_files)} result files")
        
        for file in json_files:
            try:
                with open(file, 'r') as f:
                    result = json.load(f)
                    
                # Extract config name and replication
                config_full = result['config_name']
                config_parts = config_full.split('_')
                
                config_num = int(config_parts[1])
                replication = int(config_parts[2].replace('rep', ''))
                
                # Extract performance metrics
                metrics = result['metrics']
                tx_sub = metrics['transaction_submission']
                e2e = metrics['end_to_end_latency']
                
                # Decode factorial factors from config number
                factors = self._decode_config(config_num)
                
                data_point = {
                    'config': config_num,
                    'replication': replication,
                    'batch_size': factors['batch_size'],
                    'linger_ms': factors['linger_ms'],
                    'compression': factors['compression'],
                    'throughput_tps': tx_sub['throughput_tps'],
                    'avg_latency_ms': tx_sub['avg_submission_time_ms'],
                    'e2e_p95_ms': e2e['p95_latency_ms']
                }
                
                self.data.append(data_point)
                
            except Exception as e:
                print(f"Error loading {file}: {e}")
        
        print(f"Loaded {len(self.data)} data points")
        return len(self.data) > 0
    
    def _decode_config(self, config_num):
        """Decode config number to factorial factors"""
        configs = {
            1: {'batch_size': 16384, 'linger_ms': 0, 'compression': 'none'},
            2: {'batch_size': 16384, 'linger_ms': 0, 'compression': 'lz4'},
            3: {'batch_size': 16384, 'linger_ms': 25, 'compression': 'none'},
            4: {'batch_size': 16384, 'linger_ms': 25, 'compression': 'lz4'},
            5: {'batch_size': 131072, 'linger_ms': 0, 'compression': 'none'},
            6: {'batch_size': 131072, 'linger_ms': 0, 'compression': 'lz4'},
            7: {'batch_size': 131072, 'linger_ms': 25, 'compression': 'none'},
            8: {'batch_size': 131072, 'linger_ms': 25, 'compression': 'lz4'},
        }
        return configs.get(config_num, {})
    
    def compute_anova(self):
        """Perform ANOVA analysis"""
        print("\n" + "="*70)
        print("ANOVA ANALYSIS - 2³ FACTORIAL DESIGN")
        print("="*70)
        
        df = pd.DataFrame(self.data)
        
        # Convert to coded factors (-1, +1)
        df['A'] = df['batch_size'].map({16384: -1, 131072: 1})
        df['B'] = df['linger_ms'].map({0: -1, 25: 1})
        df['C'] = df['compression'].map({'none': -1, 'lz4': 1})
        
        # Response variables
        responses = ['throughput_tps', 'avg_latency_ms', 'e2e_p95_ms']
        
        results = {}
        
        for response in responses:
            print(f"\n{'='*70}")
            print(f"RESPONSE: {response.upper()}")
            print(f"{'='*70}")
            
            # Grand mean
            grand_mean = df[response].mean()
            
            # Main effects
            effect_A = (df[df['A'] == 1][response].mean() - 
                       df[df['A'] == -1][response].mean()) / 2
            effect_B = (df[df['B'] == 1][response].mean() - 
                       df[df['B'] == -1][response].mean()) / 2
            effect_C = (df[df['C'] == 1][response].mean() - 
                       df[df['C'] == -1][response].mean()) / 2
            
            # Interaction effects
            effect_AB = self._compute_interaction(df, 'A', 'B', response)
            effect_AC = self._compute_interaction(df, 'A', 'C', response)
            effect_BC = self._compute_interaction(df, 'B', 'C', response)
            effect_ABC = self._compute_three_way_interaction(df, response)
            
            # Sum of squares
            n_reps = df.groupby(['A', 'B', 'C']).size().iloc[0]
            n_total = len(df)
            
            SS_A = 2 * n_reps * effect_A**2
            SS_B = 2 * n_reps * effect_B**2
            SS_C = 2 * n_reps * effect_C**2
            SS_AB = 2 * n_reps * effect_AB**2
            SS_AC = 2 * n_reps * effect_AC**2
            SS_BC = 2 * n_reps * effect_BC**2
            SS_ABC = 2 * n_reps * effect_ABC**2
            
            SS_total = ((df[response] - grand_mean)**2).sum()
            SS_model = SS_A + SS_B + SS_C + SS_AB + SS_AC + SS_BC + SS_ABC
            SS_error = SS_total - SS_model
            
            # Degrees of freedom
            df_model = 7
            df_error = n_total - 8
            df_total = n_total - 1
            
            # Mean squares
            MS_A = SS_A / 1
            MS_B = SS_B / 1
            MS_C = SS_C / 1
            MS_AB = SS_AB / 1
            MS_AC = SS_AC / 1
            MS_BC = SS_BC / 1
            MS_ABC = SS_ABC / 1
            MS_error = SS_error / df_error
            
            # F-statistics
            F_A = MS_A / MS_error
            F_B = MS_B / MS_error
            F_C = MS_C / MS_error
            F_AB = MS_AB / MS_error
            F_AC = MS_AC / MS_error
            F_BC = MS_BC / MS_error
            F_ABC = MS_ABC / MS_error
            
            # P-values
            p_A = 1 - stats.f.cdf(F_A, 1, df_error)
            p_B = 1 - stats.f.cdf(F_B, 1, df_error)
            p_C = 1 - stats.f.cdf(F_C, 1, df_error)
            p_AB = 1 - stats.f.cdf(F_AB, 1, df_error)
            p_AC = 1 - stats.f.cdf(F_AC, 1, df_error)
            p_BC = 1 - stats.f.cdf(F_BC, 1, df_error)
            p_ABC = 1 - stats.f.cdf(F_ABC, 1, df_error)
            
            # R-squared
            r_squared = SS_model / SS_total
            
            # Print ANOVA table
            print(f"\nGrand Mean: {grand_mean:.2f}")
            print(f"\nMain Effects:")
            print(f"  A (batch_size):   {effect_A:+.2f}  F={F_A:.2f}  p={p_A:.4f} {'***' if p_A < 0.001 else '**' if p_A < 0.01 else '*' if p_A < 0.05 else 'ns'}")
            print(f"  B (linger_ms):    {effect_B:+.2f}  F={F_B:.2f}  p={p_B:.4f} {'***' if p_B < 0.001 else '**' if p_B < 0.01 else '*' if p_B < 0.05 else 'ns'}")
            print(f"  C (compression):  {effect_C:+.2f}  F={F_C:.2f}  p={p_C:.4f} {'***' if p_C < 0.001 else '**' if p_C < 0.01 else '*' if p_C < 0.05 else 'ns'}")
            
            print(f"\nInteraction Effects:")
            print(f"  AB: {effect_AB:+.2f}  F={F_AB:.2f}  p={p_AB:.4f} {'***' if p_AB < 0.001 else '**' if p_AB < 0.01 else '*' if p_AB < 0.05 else 'ns'}")
            print(f"  AC: {effect_AC:+.2f}  F={F_AC:.2f}  p={p_AC:.4f} {'***' if p_AC < 0.001 else '**' if p_AC < 0.01 else '*' if p_AC < 0.05 else 'ns'}")
            print(f"  BC: {effect_BC:+.2f}  F={F_BC:.2f}  p={p_BC:.4f} {'***' if p_BC < 0.001 else '**' if p_BC < 0.01 else '*' if p_BC < 0.05 else 'ns'}")
            print(f"  ABC: {effect_ABC:+.2f}  F={F_ABC:.2f}  p={p_ABC:.4f} {'***' if p_ABC < 0.001 else '**' if p_ABC < 0.01 else '*' if p_ABC < 0.05 else 'ns'}")
            
            print(f"\nModel Statistics:")
            print(f"  R² = {r_squared:.4f} ({r_squared*100:.2f}% variance explained)")
            print(f"  SS_model = {SS_model:.2f}")
            print(f"  SS_error = {SS_error:.2f}")
            print(f"  SS_total = {SS_total:.2f}")
            
            results[response] = {
                'grand_mean': grand_mean,
                'effects': {
                    'A': effect_A, 'B': effect_B, 'C': effect_C,
                    'AB': effect_AB, 'AC': effect_AC, 'BC': effect_BC, 'ABC': effect_ABC
                },
                'f_values': {
                    'A': F_A, 'B': F_B, 'C': F_C,
                    'AB': F_AB, 'AC': F_AC, 'BC': F_BC, 'ABC': F_ABC
                },
                'p_values': {
                    'A': p_A, 'B': p_B, 'C': p_C,
                    'AB': p_AB, 'AC': p_AC, 'BC': p_BC, 'ABC': p_ABC
                },
                'r_squared': r_squared
            }
        
        return df, results
    
    def _compute_interaction(self, df, factor1, factor2, response):
        """Compute two-way interaction effect"""
        hh = df[(df[factor1] == 1) & (df[factor2] == 1)][response].mean()
        hl = df[(df[factor1] == 1) & (df[factor2] == -1)][response].mean()
        lh = df[(df[factor1] == -1) & (df[factor2] == 1)][response].mean()
        ll = df[(df[factor1] == -1) & (df[factor2] == -1)][response].mean()
        
        return (hh + ll - hl - lh) / 4
    
    def _compute_three_way_interaction(self, df, response):
        """Compute three-way interaction effect"""
        vals = []
        for a, b, c in product([1, -1], repeat=3):
            val = df[(df['A'] == a) & (df['B'] == b) & (df['C'] == c)][response].mean()
            sign = a * b * c
            vals.append(sign * val)
        
        return sum(vals) / 8
    
    def plot_main_effects(self, df, results):
        """Plot main effects"""
        if not PLOTTING:
            return
        
        print("\nGenerating main effects plots...")
        
        fig, axes = plt.subplots(3, 3, figsize=(15, 12))
        fig.suptitle('Main Effects Plots - Factorial Design 2³', 
                     fontsize=16, fontweight='bold')
        
        responses = ['throughput_tps', 'avg_latency_ms', 'e2e_p95_ms']
        factors = [('A', 'batch_size', [16384, 131072]), 
                   ('B', 'linger_ms', [0, 25]),
                   ('C', 'compression', ['none', 'lz4'])]
        
        for i, response in enumerate(responses):
            for j, (factor_code, factor_name, levels) in enumerate(factors):
                ax = axes[i, j]
                
                # Compute means at each level
                means = []
                for level_code in [-1, 1]:
                    mean_val = df[df[factor_code] == level_code][response].mean()
                    means.append(mean_val)
                
                # Plot
                ax.plot([0, 1], means, marker='o', linewidth=2, markersize=10)
                ax.set_xticks([0, 1])
                ax.set_xticklabels([str(levels[0]), str(levels[1])])
                ax.set_xlabel(factor_name, fontweight='bold')
                
                if j == 0:
                    ax.set_ylabel(response.replace('_', ' ').title(), fontweight='bold')
                
                # Add effect size annotation
                effect = results[response]['effects'][factor_code]
                p_val = results[response]['p_values'][factor_code]
                sig = '***' if p_val < 0.001 else '**' if p_val < 0.01 else '*' if p_val < 0.05 else 'ns'
                
                ax.text(0.5, max(means), f'Effect: {effect:+.1f}\np={p_val:.4f} {sig}',
                       ha='center', va='bottom', fontsize=8,
                       bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
                
                ax.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(self.results_dir / 'main_effects_plot.png', dpi=300, bbox_inches='tight')
        print(f"Saved: {self.results_dir / 'main_effects_plot.png'}")
    
    def plot_interaction_effects(self, df):
        """Plot interaction effects"""
        if not PLOTTING:
            return
        
        print("\nGenerating interaction plots...")
        
        fig, axes = plt.subplots(2, 3, figsize=(15, 10))
        fig.suptitle('Interaction Effects - Factorial Design 2³', 
                     fontsize=16, fontweight='bold')
        
        responses = ['throughput_tps', 'avg_latency_ms']
        interactions = [('A', 'B'), ('A', 'C'), ('B', 'C')]
        
        for i, response in enumerate(responses):
            for j, (f1, f2) in enumerate(interactions):
                ax = axes[i, j]
                
                # Plot interaction
                for level in [-1, 1]:
                    means = []
                    x_vals = [-1, 1]
                    for x_val in x_vals:
                        mean_val = df[(df[f1] == x_val) & (df[f2] == level)][response].mean()
                        means.append(mean_val)
                    
                    label = f"{f2}={'High' if level == 1 else 'Low'}"
                    ax.plot([0, 1], means, marker='o', label=label, linewidth=2, markersize=8)
                
                ax.set_xticks([0, 1])
                ax.set_xticklabels(['Low', 'High'])
                ax.set_xlabel(f'Factor {f1}', fontweight='bold')
                
                if j == 0:
                    ax.set_ylabel(response.replace('_', ' ').title(), fontweight='bold')
                
                ax.legend()
                ax.grid(True, alpha=0.3)
                ax.set_title(f'{f1} × {f2}')
        
        plt.tight_layout()
        plt.savefig(self.results_dir / 'interaction_plots.png', dpi=300, bbox_inches='tight')
        print(f"Saved: {self.results_dir / 'interaction_plots.png'}")
    
    def generate_report(self, results):
        """Generate markdown report"""
        print("\nGenerating ANOVA report...")
        
        report_file = self.results_dir / 'FACTORIAL_ANALYSIS_REPORT.md'
        
        with open(report_file, 'w') as f:
            f.write("# Factorial Design 2³ - ANOVA Analysis Report\n\n")
            f.write(f"**Generated**: {pd.Timestamp.now()}\n\n")
            
            f.write("## Design Summary\n\n")
            f.write("- **Design Type**: 2³ Full Factorial\n")
            f.write("- **Factors**: 3 (batch_size, linger_ms, compression)\n")
            f.write("- **Levels per factor**: 2\n")
            f.write("- **Configurations**: 8\n")
            f.write("- **Replications**: 3\n")
            f.write("- **Total tests**: 24\n\n")
            
            f.write("## Factor Levels\n\n")
            f.write("| Factor | Low Level | High Level |\n")
            f.write("|--------|-----------|------------|\n")
            f.write("| A: batch_size | 16KB | 128KB |\n")
            f.write("| B: linger_ms | 0ms | 25ms |\n")
            f.write("| C: compression | none | lz4 |\n\n")
            
            for response, res in results.items():
                f.write(f"## Response: {response.upper()}\n\n")
                
                f.write(f"**Grand Mean**: {res['grand_mean']:.2f}\n\n")
                
                f.write("### Main Effects\n\n")
                f.write("| Factor | Effect | F-value | p-value | Significance |\n")
                f.write("|--------|--------|---------|---------|-------------|\n")
                
                for factor in ['A', 'B', 'C']:
                    effect = res['effects'][factor]
                    f_val = res['f_values'][factor]
                    p_val = res['p_values'][factor]
                    sig = '***' if p_val < 0.001 else '**' if p_val < 0.01 else '*' if p_val < 0.05 else 'ns'
                    f.write(f"| {factor} | {effect:+.2f} | {f_val:.2f} | {p_val:.4f} | {sig} |\n")
                
                f.write("\n### Interaction Effects\n\n")
                f.write("| Interaction | Effect | F-value | p-value | Significance |\n")
                f.write("|------------|--------|---------|---------|-------------|\n")
                
                for inter in ['AB', 'AC', 'BC', 'ABC']:
                    effect = res['effects'][inter]
                    f_val = res['f_values'][inter]
                    p_val = res['p_values'][inter]
                    sig = '***' if p_val < 0.001 else '**' if p_val < 0.01 else '*' if p_val < 0.05 else 'ns'
                    f.write(f"| {inter} | {effect:+.2f} | {f_val:.2f} | {p_val:.4f} | {sig} |\n")
                
                f.write(f"\n**R² = {res['r_squared']:.4f}** ({res['r_squared']*100:.2f}% variance explained)\n\n")
            
            f.write("## Recommendations\n\n")
            f.write("Based on ANOVA results:\n\n")
            
            # Identify significant factors
            sig_factors = []
            for factor in ['A', 'B', 'C']:
                if results['throughput_tps']['p_values'][factor] < 0.05:
                    effect = results['throughput_tps']['effects'][factor]
                    sig_factors.append((factor, effect))
            
            sig_factors.sort(key=lambda x: abs(x[1]), reverse=True)
            
            f.write("### Most Influential Factors (for Throughput):\n\n")
            for i, (factor, effect) in enumerate(sig_factors, 1):
                factor_names = {'A': 'batch_size', 'B': 'linger_ms', 'C': 'compression'}
                direction = 'increase' if effect > 0 else 'decrease'
                f.write(f"{i}. **{factor_names[factor]}**: {direction} throughput by {abs(effect):.1f} TPS\n")
            
            f.write("\n---\n*Statistical significance: *** p<0.001, ** p<0.01, * p<0.05, ns not significant*\n")
        
        print(f"Report saved: {report_file}")
    
    def run_complete_analysis(self):
        """Run complete factorial analysis"""
        print("\nStarting factorial design analysis...")
        
        if not self.load_results():
            return
        
        df, results = self.compute_anova()
        
        self.plot_main_effects(df, results)
        self.plot_interaction_effects(df)
        
        self.generate_report(results)
        
        print("\n" + "="*70)
        print("FACTORIAL ANALYSIS COMPLETE")
        print("="*70)
        print(f"\nAll results saved in: {self.results_dir}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_factorial_results.py <results_directory>")
        sys.exit(1)
    
    results_dir = sys.argv[1]
    
    analyzer = FactorialAnalysis(results_dir)
    analyzer.run_complete_analysis()

if __name__ == "__main__":
    main()