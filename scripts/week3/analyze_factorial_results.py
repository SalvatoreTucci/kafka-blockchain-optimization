#!/usr/bin/env python3
"""
Factorial Design Results Analyzer (Week 3)
Analisi statistica avanzata per 2^3 factorial design con ANOVA e interaction effects
"""

import os
import re
import json
import csv
import statistics
import itertools
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass

# Import opzionali per statistiche avanzate
try:
    import numpy as np
    import pandas as pd
    import matplotlib.pyplot as plt
    import seaborn as sns
    from scipy import stats
    from scipy.stats import f_oneway
    import statsmodels.api as sm
    from statsmodels.formula.api import ols
    from statsmodels.stats.anova import anova_lm
    ADVANCED_STATS_AVAILABLE = True
except ImportError as e:
    ADVANCED_STATS_AVAILABLE = False
    print(f"Warning: Advanced statistics not available: {e}")
    print("Install with: pip install numpy pandas matplotlib seaborn scipy statsmodels")

@dataclass 
class FactorialResult:
    """Struttura dati per risultati factorial"""
    config_name: str
    batch_size: int
    linger_ms: int  
    compression: str
    run_number: int
    throughput: float
    avg_latency: float
    p95_latency: float
    p99_latency: float
    cpu_percent: float
    memory_percent: float
    status: str

class FactorialAnalyzer:
    def __init__(self, results_dir: str):
        self.results_dir = Path(results_dir)
        self.analysis_dir = self.results_dir / "factorial_analysis"
        self.analysis_dir.mkdir(exist_ok=True)
        
        # Mapping factor levels
        self.factor_levels = {
            'batch_size': {16384: 'low', 65536: 'high'},
            'linger_ms': {0: 'low', 10: 'high'}, 
            'compression': {'none': 'low', 'lz4': 'high'}
        }
        
        if ADVANCED_STATS_AVAILABLE:
            plt.style.use('default')
            plt.rcParams['figure.figsize'] = (12, 8)
            plt.rcParams['font.size'] = 10

    def parse_single_run(self, run_dir: Path) -> Optional[FactorialResult]:
        """Parse risultati di un singolo run"""
        
        # Extract config info dal path
        config_name = run_dir.parent.name
        run_number = int(run_dir.name.replace('run_', ''))
        
        # Parse config factors dal nome
        # config_000 = batch_low + linger_low + compression_low
        if len(config_name) >= 10:  # config_xxx format
            factors = config_name[-3:]  # últimi 3 caratteri
            batch_size = 16384 if factors[0] == '0' else 65536
            linger_ms = 0 if factors[1] == '0' else 10
            compression = 'none' if factors[2] == '0' else 'lz4'
        else:
            return None
            
        # Parse producer log
        producer_log = run_dir / "producer-test.log"
        if not producer_log.exists():
            return None
            
        try:
            with open(producer_log, 'r', encoding='utf-8') as f:
                content = f.read()
        except UnicodeDecodeError:
            with open(producer_log, 'r', encoding='latin-1') as f:
                content = f.read()
                
        # Extract metrics
        throughput = 0
        avg_latency = 0
        p95_latency = 0
        p99_latency = 0
        
        # Final line parsing
        final_match = re.search(
            r'(\d+) records sent, ([0-9.]+) records/sec.*?([0-9.]+) ms avg latency.*?'
            r'(?:(\d+) ms 95th.*?)?(?:(\d+) ms 99th)?', content, re.DOTALL
        )
        
        if final_match:
            throughput = float(final_match.group(2))
            avg_latency = float(final_match.group(3))
            if final_match.group(4): p95_latency = float(final_match.group(4))
            if final_match.group(5): p99_latency = float(final_match.group(5))
        
        # Parse resource usage
        cpu_percent = 0
        memory_percent = 0
        stats_file = run_dir / "final-stats.txt"
        if stats_file.exists():
            try:
                with open(stats_file, 'r', encoding='utf-8') as f:
                    stats_content = f.read()
                    cpu_match = re.search(r'(\d+\.\d+)%', stats_content)
                    mem_match = re.search(r'(\d+\.\d+)%.*?(\d+\.\d+)%', stats_content)
                    if cpu_match: cpu_percent = float(cpu_match.group(1))
                    if mem_match: memory_percent = float(mem_match.group(2))
            except:
                pass
        
        status = "SUCCESS" if throughput > 0 else "FAILED"
        
        return FactorialResult(
            config_name=config_name,
            batch_size=batch_size,
            linger_ms=linger_ms,
            compression=compression,
            run_number=run_number,
            throughput=throughput,
            avg_latency=avg_latency,
            p95_latency=p95_latency,
            p99_latency=p99_latency,
            cpu_percent=cpu_percent,
            memory_percent=memory_percent,
            status=status
        )

    def collect_all_results(self) -> List[FactorialResult]:
        """Raccoglie tutti i risultati factorial"""
        print("Collecting factorial design results...")
        
        all_results = []
        config_dirs = [d for d in self.results_dir.iterdir() 
                      if d.is_dir() and d.name.startswith('config_')]
        
        for config_dir in config_dirs:
            print(f"Processing {config_dir.name}...")
            run_dirs = [d for d in config_dir.iterdir() 
                       if d.is_dir() and d.name.startswith('run_')]
            
            for run_dir in run_dirs:
                result = self.parse_single_run(run_dir)
                if result:
                    all_results.append(result)
                    
        print(f"Collected {len(all_results)} factorial results")
        return all_results

    def create_dataframe(self, results: List[FactorialResult]) -> 'pd.DataFrame':
        """Crea DataFrame per analisi statistica"""
        if not ADVANCED_STATS_AVAILABLE:
            return None
            
        data = []
        for result in results:
            if result.status == "SUCCESS":
                data.append({
                    'config': result.config_name,
                    'batch_size': result.batch_size,
                    'linger_ms': result.linger_ms,
                    'compression': result.compression,
                    'batch_level': self.factor_levels['batch_size'][result.batch_size],
                    'linger_level': self.factor_levels['linger_ms'][result.linger_ms],
                    'compression_level': self.factor_levels['compression'][result.compression],
                    'run': result.run_number,
                    'throughput': result.throughput,
                    'avg_latency': result.avg_latency,
                    'p95_latency': result.p95_latency,
                    'p99_latency': result.p99_latency,
                    'cpu_percent': result.cpu_percent,
                    'memory_percent': result.memory_percent
                })
                
        return pd.DataFrame(data)

    def perform_anova_analysis(self, df: 'pd.DataFrame') -> Dict:
        """Esegue ANOVA per main effects e interactions"""
        if not ADVANCED_STATS_AVAILABLE:
            return {}
            
        print("Performing ANOVA analysis...")
        
        anova_results = {}
        
        # ANOVA per throughput
        try:
            model_throughput = ols(
                'throughput ~ C(batch_level) * C(linger_level) * C(compression_level)', 
                data=df
            ).fit()
            anova_throughput = anova_lm(model_throughput, typ=2)
            anova_results['throughput'] = {
                'model': model_throughput,
                'anova': anova_throughput,
                'r_squared': model_throughput.rsquared
            }
        except Exception as e:
            print(f"ANOVA throughput failed: {e}")
            
        # ANOVA per latency
        try:
            model_latency = ols(
                'avg_latency ~ C(batch_level) * C(linger_level) * C(compression_level)', 
                data=df
            ).fit()
            anova_latency = anova_lm(model_latency, typ=2)
            anova_results['avg_latency'] = {
                'model': model_latency,
                'anova': anova_latency,
                'r_squared': model_latency.rsquared
            }
        except Exception as e:
            print(f"ANOVA latency failed: {e}")
            
        return anova_results

    def generate_main_effects_plot(self, df: 'pd.DataFrame') -> None:
        """Genera plot main effects"""
        if not ADVANCED_STATS_AVAILABLE:
            return
            
        print("Generating main effects plots...")
        
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(16, 12))
        fig.suptitle('Factorial Design: Main Effects Analysis', fontsize=16, fontweight='bold')
        
        # Main effect batch_size su throughput
        batch_throughput = df.groupby('batch_level')['throughput'].agg(['mean', 'std'])
        ax1.errorbar(batch_throughput.index, batch_throughput['mean'], 
                    yerr=batch_throughput['std'], marker='o', linewidth=2, markersize=8)
        ax1.set_title('Batch Size Effect on Throughput')
        ax1.set_ylabel('Throughput (records/sec)')
        ax1.grid(True, alpha=0.3)
        
        # Main effect batch_size su latency
        batch_latency = df.groupby('batch_level')['avg_latency'].agg(['mean', 'std'])
        ax2.errorbar(batch_latency.index, batch_latency['mean'], 
                    yerr=batch_latency['std'], marker='o', linewidth=2, markersize=8, color='red')
        ax2.set_title('Batch Size Effect on Latency')
        ax2.set_ylabel('Avg Latency (ms)')
        ax2.grid(True, alpha=0.3)
        
        # Main effect linger su latency
        linger_latency = df.groupby('linger_level')['avg_latency'].agg(['mean', 'std'])
        ax3.errorbar(linger_latency.index, linger_latency['mean'], 
                    yerr=linger_latency['std'], marker='s', linewidth=2, markersize=8, color='green')
        ax3.set_title('Linger Time Effect on Latency')
        ax3.set_ylabel('Avg Latency (ms)')
        ax3.grid(True, alpha=0.3)
        
        # Main effect compression su latency
        compression_latency = df.groupby('compression_level')['avg_latency'].agg(['mean', 'std'])
        ax4.errorbar(compression_latency.index, compression_latency['mean'], 
                    yerr=compression_latency['std'], marker='^', linewidth=2, markersize=8, color='purple')
        ax4.set_title('Compression Effect on Latency')
        ax4.set_ylabel('Avg Latency (ms)')
        ax4.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plot_file = self.analysis_dir / "main_effects.png"
        plt.savefig(plot_file, dpi=300, bbox_inches='tight')
        plt.close()
        print(f"Main effects plot saved: {plot_file}")

    def generate_interaction_plot(self, df: 'pd.DataFrame') -> None:
        """Genera plot interaction effects"""
        if not ADVANCED_STATS_AVAILABLE:
            return
            
        print("Generating interaction effects plots...")
        
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(16, 12))
        fig.suptitle('Factorial Design: Interaction Effects', fontsize=16, fontweight='bold')
        
        # Interaction batch × linger su latency
        interaction_data = df.groupby(['batch_level', 'linger_level'])['avg_latency'].mean().unstack()
        interaction_data.plot(kind='line', marker='o', ax=ax1, linewidth=2, markersize=8)
        ax1.set_title('Batch Size × Linger Time Interaction (Latency)')
        ax1.set_ylabel('Avg Latency (ms)')
        ax1.legend(title='Linger Level')
        ax1.grid(True, alpha=0.3)
        
        # Interaction batch × compression su latency
        interaction_data2 = df.groupby(['batch_level', 'compression_level'])['avg_latency'].mean().unstack()
        interaction_data2.plot(kind='line', marker='s', ax=ax2, linewidth=2, markersize=8)
        ax2.set_title('Batch Size × Compression Interaction (Latency)')
        ax2.set_ylabel('Avg Latency (ms)')
        ax2.legend(title='Compression Level')
        ax2.grid(True, alpha=0.3)
        
        # Interaction linger × compression su latency
        interaction_data3 = df.groupby(['linger_level', 'compression_level'])['avg_latency'].mean().unstack()
        interaction_data3.plot(kind='line', marker='^', ax=ax3, linewidth=2, markersize=8)
        ax3.set_title('Linger Time × Compression Interaction (Latency)')
        ax3.set_ylabel('Avg Latency (ms)')
        ax3.legend(title='Compression Level')
        ax3.grid(True, alpha=0.3)
        
        # Heatmap tutte le configurazioni
        heatmap_data = df.groupby(['batch_level', 'linger_level', 'compression_level'])['avg_latency'].mean()
        heatmap_matrix = heatmap_data.unstack(level=2).fillna(0)
        
        if len(heatmap_matrix) > 0:
            sns.heatmap(heatmap_matrix, annot=True, fmt='.2f', cmap='RdYlBu_r', ax=ax4)
            ax4.set_title('Configuration Heatmap (Avg Latency)')
        
        plt.tight_layout()
        plot_file = self.analysis_dir / "interaction_effects.png"
        plt.savefig(plot_file, dpi=300, bbox_inches='tight')
        plt.close()
        print(f"Interaction effects plot saved: {plot_file}")

    def identify_pareto_optimal(self, df: 'pd.DataFrame') -> List[str]:
        """Identifica configurazioni Pareto-optimal (throughput vs latency)"""
        if not ADVANCED_STATS_AVAILABLE:
            return []
            
        print("Identifying Pareto-optimal configurations...")
        
        # Raggruppa per configurazione
        config_means = df.groupby('config').agg({
            'throughput': 'mean',
            'avg_latency': 'mean'
        }).reset_index()
        
        pareto_configs = []
        
        for i, row_i in config_means.iterrows():
            is_pareto = True
            for j, row_j in config_means.iterrows():
                if i != j:
                    # row_j domina row_i se ha throughput >= E latency <=
                    if (row_j['throughput'] >= row_i['throughput'] and 
                        row_j['avg_latency'] <= row_i['avg_latency'] and
                        (row_j['throughput'] > row_i['throughput'] or 
                         row_j['avg_latency'] < row_i['avg_latency'])):
                        is_pareto = False
                        break
            
            if is_pareto:
                pareto_configs.append(row_i['config'])
                
        return pareto_configs

    def generate_comprehensive_report(self, results: List[FactorialResult], 
                                    anova_results: Dict, pareto_configs: List[str]) -> None:
        """Genera report completo"""
        print("Generating comprehensive factorial report...")
        
        report_file = self.analysis_dir / "FACTORIAL_ANALYSIS_REPORT.md"
        
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write(f"""# Factorial Design Analysis Report (Week 3)

**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  
**Design**: 2³ Factorial (batch.size × linger.ms × compression.type)  
**Total Results Analyzed**: {len(results)}

## Experimental Design Summary

**Factor Levels:**
- **Factor A (Batch Size)**: 16KB (low), 65KB (high)  
- **Factor B (Linger Time)**: 0ms (low), 10ms (high)
- **Factor C (Compression)**: none (low), lz4 (high)

**Configurations Tested**: 8 (2³)
**Runs per Configuration**: 3
**Total Tests**: {len(results)}

## Statistical Analysis Results

""")
            
            # Analisi descrittiva
            successful_results = [r for r in results if r.status == "SUCCESS"]
            if successful_results:
                throughputs = [r.throughput for r in successful_results]
                latencies = [r.avg_latency for r in successful_results]
                
                f.write(f"""### Descriptive Statistics

**Throughput:**
- Mean: {statistics.mean(throughputs):.2f} records/sec
- Std Dev: {statistics.stdev(throughputs) if len(throughputs) > 1 else 0:.2f}
- Range: {min(throughputs):.2f} - {max(throughputs):.2f}

**Average Latency:**
- Mean: {statistics.mean(latencies):.2f} ms
- Std Dev: {statistics.stdev(latencies) if len(latencies) > 1 else 0:.2f}
- Range: {min(latencies):.2f} - {max(latencies):.2f} ms

""")
            
            # ANOVA Results
            if anova_results and ADVANCED_STATS_AVAILABLE:
                f.write("### ANOVA Results\n\n")
                
                for metric, result in anova_results.items():
                    f.write(f"#### {metric.title()} Analysis\n")
                    f.write(f"**R-squared**: {result['r_squared']:.4f}\n\n")
                    
                    # Significative effects
                    anova_table = result['anova']
                    significant_effects = anova_table[anova_table['PR(>F)'] < 0.05]
                    
                    if len(significant_effects) > 0:
                        f.write("**Significant Effects (p < 0.05):**\n")
                        for effect in significant_effects.index:
                            p_value = significant_effects.loc[effect, 'PR(>F)']
                            f_value = significant_effects.loc[effect, 'F']
                            f.write(f"- {effect}: F = {f_value:.2f}, p = {p_value:.4f}\n")
                        f.write("\n")
                    else:
                        f.write("**No significant effects found at α = 0.05**\n\n")
            
            # Configuration Rankings
            f.write("## Configuration Performance Ranking\n\n")
            
            # Raggruppa per configurazione
            config_stats = {}
            for config in set(r.config_name for r in successful_results):
                config_results = [r for r in successful_results if r.config_name == config]
                if config_results:
                    config_stats[config] = {
                        'mean_throughput': statistics.mean([r.throughput for r in config_results]),
                        'mean_latency': statistics.mean([r.avg_latency for r in config_results]),
                        'std_latency': statistics.stdev([r.avg_latency for r in config_results]) if len(config_results) > 1 else 0,
                        'runs': len(config_results)
                    }
            
            # Tabella risultati
            f.write("| Config | Batch | Linger | Compression | Avg Throughput | Avg Latency | Latency Std | Runs |\n")
            f.write("|--------|-------|--------|-------------|----------------|-------------|-------------|------|\n")
            
            # Ordina per latenza crescente
            sorted_configs = sorted(config_stats.items(), key=lambda x: x[1]['mean_latency'])
            
            for config, stats in sorted_configs:
                # Parse config factors
                factors = config[-3:] if len(config) >= 10 else "000"
                batch = "16KB" if factors[0] == '0' else "65KB"
                linger = "0ms" if factors[1] == '0' else "10ms"  
                compression = "none" if factors[2] == '0' else "lz4"
                
                f.write(f"| {config} | {batch} | {linger} | {compression} | "
                       f"{stats['mean_throughput']:.1f} | {stats['mean_latency']:.2f} | "
                       f"{stats['std_latency']:.2f} | {stats['runs']} |\n")
            
            # Pareto Analysis
            if pareto_configs:
                f.write(f"\n## Pareto-Optimal Configurations\n\n")
                f.write("Configurations that are not dominated by any other in throughput vs latency trade-off:\n\n")
                for config in pareto_configs:
                    if config in config_stats:
                        stats = config_stats[config]
                        f.write(f"- **{config}**: {stats['mean_throughput']:.1f} records/sec, "
                               f"{stats['mean_latency']:.2f}ms latency\n")
                f.write("\n")
            
            # Main Effects Summary
            f.write("## Main Effects Summary\n\n")
            if ADVANCED_STATS_AVAILABLE and successful_results:
                # Calculate main effects manually se ANOVA non disponibile
                batch_low = [r.avg_latency for r in successful_results if r.batch_size == 16384]
                batch_high = [r.avg_latency for r in successful_results if r.batch_size == 65536]
                
                linger_low = [r.avg_latency for r in successful_results if r.linger_ms == 0]
                linger_high = [r.avg_latency for r in successful_results if r.linger_ms == 10]
                
                compression_none = [r.avg_latency for r in successful_results if r.compression == 'none']
                compression_lz4 = [r.avg_latency for r in successful_results if r.compression == 'lz4']
                
                if batch_low and batch_high:
                    batch_effect = statistics.mean(batch_high) - statistics.mean(batch_low)
                    f.write(f"**Batch Size Effect**: +{batch_effect:.2f}ms (high vs low)\n")
                
                if linger_low and linger_high:
                    linger_effect = statistics.mean(linger_high) - statistics.mean(linger_low)
                    f.write(f"**Linger Time Effect**: +{linger_effect:.2f}ms (high vs low)\n")
                
                if compression_none and compression_lz4:
                    compression_effect = statistics.mean(compression_lz4) - statistics.mean(compression_none)
                    f.write(f"**Compression Effect**: +{compression_effect:.2f}ms (lz4 vs none)\n")
                
                f.write("\n")
            
            # Recommendations
            f.write("## Optimization Recommendations\n\n")
            
            if sorted_configs:
                best_config = sorted_configs[0][0]
                best_stats = sorted_configs[0][1]
                
                f.write(f"### Recommended Configuration: {best_config}\n")
                f.write(f"- **Performance**: {best_stats['mean_throughput']:.1f} records/sec, "
                       f"{best_stats['mean_latency']:.2f}ms latency\n")
                f.write(f"- **Consistency**: ±{best_stats['std_latency']:.2f}ms latency deviation\n")
                f.write(f"- **Statistical Support**: {best_stats['runs']} experimental runs\n\n")
                
                # Parse best config factors
                factors = best_config[-3:] if len(best_config) >= 10 else "000"
                batch = 16384 if factors[0] == '0' else 65536
                linger = 0 if factors[1] == '0' else 10
                compression = 'none' if factors[2] == '0' else 'lz4'
                
                f.write("**Configuration Parameters:**\n")
                f.write(f"```\n")
                f.write(f"KAFKA_BATCH_SIZE={batch}\n")
                f.write(f"KAFKA_LINGER_MS={linger}\n")
                f.write(f"KAFKA_COMPRESSION_TYPE={compression}\n")
                f.write(f"```\n\n")
            
            # Week 4 Preparation
            f.write("## Preparation for Week 4\n\n")
            f.write("Based on factorial analysis results:\n\n")
            f.write("1. **Best Configuration Identified**: Ready for validation testing\n")
            f.write("2. **Statistical Significance**: Factor effects quantified\n")
            f.write("3. **Pareto Analysis**: Trade-off optimization completed\n")
            f.write("4. **Next Steps**: \n")
            f.write("   - Robustness testing with best configuration\n")
            f.write("   - Comparison with literature baselines\n")
            f.write("   - Network perturbation validation\n")
            f.write("   - Final production recommendations\n\n")
            
            f.write("## Files Generated\n\n")
            f.write("- `main_effects.png` - Main effects visualization\n")
            f.write("- `interaction_effects.png` - Interaction effects analysis\n")
            f.write("- `factorial_results.csv` - Complete numerical data\n")
            f.write("- `pareto_analysis.json` - Pareto-optimal configurations\n\n")
            
            f.write("---\n")
            f.write("*Generated by Factorial Design Analyzer*\n")
        
        print(f"Comprehensive report saved: {report_file}")

    def export_factorial_csv(self, results: List[FactorialResult]) -> None:
        """Export risultati in CSV per analisi esterne"""
        csv_file = self.analysis_dir / "factorial_results.csv"
        
        with open(csv_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            
            # Header
            writer.writerow([
                'config_name', 'batch_size', 'linger_ms', 'compression',
                'run_number', 'throughput', 'avg_latency', 'p95_latency', 
                'p99_latency', 'cpu_percent', 'memory_percent', 'status'
            ])
            
            # Data
            for result in results:
                writer.writerow([
                    result.config_name, result.batch_size, result.linger_ms,
                    result.compression, result.run_number, result.throughput,
                    result.avg_latency, result.p95_latency, result.p99_latency,
                    result.cpu_percent, result.memory_percent, result.status
                ])
        
        print(f"Factorial CSV exported: {csv_file}")

    def run_complete_factorial_analysis(self) -> None:
        """Esegue analisi completa factorial design"""
        print("Starting complete factorial design analysis...")
        print("=" * 60)
        
        # Collect all results
        all_results = self.collect_all_results()
        
        if not all_results:
            print("No factorial results found!")
            return
        
        successful_results = [r for r in all_results if r.status == "SUCCESS"]
        print(f"Successful results: {len(successful_results)}/{len(all_results)}")
        
        if not successful_results:
            print("No successful results to analyze!")
            return
        
        # Export CSV
        self.export_factorial_csv(all_results)
        
        anova_results = {}
        pareto_configs = []
        
        if ADVANCED_STATS_AVAILABLE:
            # Create DataFrame
            df = self.create_dataframe(successful_results)
            
            if df is not None and len(df) > 0:
                print(f"DataFrame created with {len(df)} rows")
                
                # ANOVA Analysis  
                anova_results = self.perform_anova_analysis(df)
                
                # Generate plots
                self.generate_main_effects_plot(df)
                self.generate_interaction_plot(df)
                
                # Pareto Analysis
                pareto_configs = self.identify_pareto_optimal(df)
                print(f"Pareto-optimal configs: {pareto_configs}")
                
                # Export Pareto results
                pareto_file = self.analysis_dir / "pareto_analysis.json"
                with open(pareto_file, 'w', encoding='utf-8') as f:
                    json.dump({
                        'pareto_configs': pareto_configs,
                        'analysis_timestamp': datetime.now().isoformat()
                    }, f, indent=2)
        else:
            print("Advanced statistics not available - basic analysis only")
        
        # Generate comprehensive report
        self.generate_comprehensive_report(all_results, anova_results, pareto_configs)
        
        print("\nFactorial analysis completed successfully!")
        print("=" * 60)
        print(f"Results saved in: {self.analysis_dir}")
        print(f"Main report: {self.analysis_dir}/FACTORIAL_ANALYSIS_REPORT.md")
        
        if ADVANCED_STATS_AVAILABLE:
            print(f"Visualizations: {self.analysis_dir}/main_effects.png")
            print(f"Interactions: {self.analysis_dir}/interaction_effects.png")

def main():
    """Funzione principale"""
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_factorial_results.py <factorial_results_directory>")
        print("Example: python3 analyze_factorial_results.py factorial_results_20250925_143022")
        sys.exit(1)
    
    results_dir = sys.argv[1]
    
    if not Path(results_dir).exists():
        print(f"Results directory not found: {results_dir}")
        sys.exit(1)
    
    # Run factorial analysis
    analyzer = FactorialAnalyzer(results_dir)
    analyzer.run_complete_factorial_analysis()

if __name__ == "__main__":
    main()