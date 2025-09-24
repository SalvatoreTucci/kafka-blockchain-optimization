#!/usr/bin/env python3
"""
Kafka Benchmark Results Analyzer - Fixed Version
Versione corretta per Windows con gestione encoding UTF-8
"""

import os
import re
import json
import csv
import statistics
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple

# Import opzionali per grafici
try:
    import matplotlib.pyplot as plt
    import pandas as pd
    import seaborn as sns
    import numpy as np
    PLOTTING_AVAILABLE = True
    
    # Configurazione matplotlib per Windows
    plt.style.use('default')  # Usa stile default invece di seaborn
    plt.rcParams['figure.figsize'] = (12, 8)
    plt.rcParams['font.size'] = 10
    
except ImportError as e:
    PLOTTING_AVAILABLE = False
    print(f"Warning: Plotting libraries not available: {e}")
    print("Charts will be skipped. Install with: pip install matplotlib pandas seaborn numpy")

class KafkaBenchmarkAnalyzer:
    def __init__(self, results_dir: str):
        self.results_dir = Path(results_dir)
        self.analysis_dir = self.results_dir / "analysis_results"
        self.analysis_dir.mkdir(exist_ok=True)
        
        # Configurazioni colori per grafici
        self.colors = {
            'baseline': '#1f77b4',
            'batch-optimized': '#ff7f0e', 
            'compression': '#2ca02c',
            'high-throughput': '#d62728',
            'low-latency': '#9467bd'
        }
        
    def parse_producer_log(self, log_file: Path) -> Dict:
        """Estrae metriche dal log del producer"""
        metrics = {
            'total_records': 0,
            'throughput_records_sec': 0,
            'throughput_mb_sec': 0,
            'avg_latency_ms': 0,
            'max_latency_ms': 0,
            'p50_latency_ms': 0,
            'p95_latency_ms': 0,
            'p99_latency_ms': 0,
            'p99_9_latency_ms': 0,
            'batch_records': [],
            'batch_rates': [],
            'batch_latencies': []
        }
        
        if not log_file.exists():
            return metrics
            
        try:
            with open(log_file, 'r', encoding='utf-8') as f:
                lines = f.readlines()
        except UnicodeDecodeError:
            with open(log_file, 'r', encoding='latin-1') as f:
                lines = f.readlines()
            
        # Analizza ogni riga del log
        for line in lines:
            line = line.strip()
            
            # Riga finale con tutti i percentili
            final_match = re.search(
                r'(\d+) records sent, ([0-9.]+) records/sec \(([0-9.]+) MB/sec\), '
                r'([0-9.]+) ms avg latency, ([0-9.]+) ms max latency,?\s*'
                r'(?:(\d+) ms 50th,?\s*)?(?:(\d+) ms 95th,?\s*)?'
                r'(?:(\d+) ms 99th,?\s*)?(?:(\d+) ms 99\.9th)?', 
                line
            )
            
            if final_match:
                metrics['total_records'] = int(final_match.group(1))
                metrics['throughput_records_sec'] = float(final_match.group(2))
                metrics['throughput_mb_sec'] = float(final_match.group(3))
                metrics['avg_latency_ms'] = float(final_match.group(4))
                metrics['max_latency_ms'] = float(final_match.group(5))
                
                # Percentili opzionali
                if final_match.group(6): metrics['p50_latency_ms'] = float(final_match.group(6))
                if final_match.group(7): metrics['p95_latency_ms'] = float(final_match.group(7))
                if final_match.group(8): metrics['p99_latency_ms'] = float(final_match.group(8))
                if final_match.group(9): metrics['p99_9_latency_ms'] = float(final_match.group(9))
            
            # Righe batch intermedie
            batch_match = re.search(
                r'(\d+) records sent, ([0-9.]+) records/sec \(([0-9.]+) MB/sec\), '
                r'([0-9.]+) ms avg latency', 
                line
            )
            
            if batch_match:
                metrics['batch_records'].append(int(batch_match.group(1)))
                metrics['batch_rates'].append(float(batch_match.group(2)))
                metrics['batch_latencies'].append(float(batch_match.group(4)))
        
        return metrics
    
    def parse_consumer_log(self, log_file: Path) -> Dict:
        """Estrae metriche dal log del consumer"""
        metrics = {
            'data_consumed_mb': 0,
            'mb_per_sec': 0,
            'messages_consumed': 0,
            'msg_per_sec': 0,
            'rebalance_time_ms': 0,
            'fetch_time_ms': 0,
            'fetch_mb_sec': 0,
            'fetch_msg_sec': 0
        }
        
        if not log_file.exists():
            return metrics
            
        try:
            with open(log_file, 'r', encoding='utf-8') as f:
                content = f.read()
        except UnicodeDecodeError:
            with open(log_file, 'r', encoding='latin-1') as f:
                content = f.read()
            
        # Cerca la riga con i dati (formato CSV)
        lines = content.strip().split('\n')
        if len(lines) >= 2:  # Header + data
            data_line = lines[-1]  # Ultima riga con dati
            parts = data_line.split(', ')
            
            if len(parts) >= 10:
                try:
                    metrics['data_consumed_mb'] = float(parts[2])
                    metrics['mb_per_sec'] = float(parts[3])
                    metrics['messages_consumed'] = int(parts[4])
                    metrics['msg_per_sec'] = float(parts[5])
                    metrics['rebalance_time_ms'] = float(parts[6])
                    metrics['fetch_time_ms'] = float(parts[7])
                    metrics['fetch_mb_sec'] = float(parts[8])
                    metrics['fetch_msg_sec'] = float(parts[9])
                except (ValueError, IndexError):
                    pass  # Mantieni valori di default
        
        return metrics
    
    def parse_config_file(self, config_file: Path) -> Dict:
        """Estrae configurazione dal file .env"""
        config = {}
        
        if not config_file.exists():
            return config
            
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                content = f.read()
        except UnicodeDecodeError:
            with open(config_file, 'r', encoding='latin-1') as f:
                content = f.read()
                
        for line in content.split('\n'):
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                config[key] = value
                    
        return config
    
    def analyze_single_test(self, test_dir: Path) -> Dict:
        """Analizza un singolo test"""
        print(f"Analyzing test: {test_dir.name}")
        
        result = {
            'test_name': test_dir.name,
            'status': 'SUCCESS',
            'producer_metrics': {},
            'consumer_metrics': {},
            'config': {},
            'resource_usage': {}
        }
        
        # Analizza producer log
        producer_log = test_dir / "producer-test.log"
        result['producer_metrics'] = self.parse_producer_log(producer_log)
        
        # Analizza consumer log
        consumer_log = test_dir / "consumer-test.log"
        result['consumer_metrics'] = self.parse_consumer_log(consumer_log)
        
        # Analizza configurazione
        config_file = test_dir / "config-used.env"
        result['config'] = self.parse_config_file(config_file)
        
        # Analizza utilizzo risorse
        stats_file = test_dir / "final-stats.txt"
        if stats_file.exists():
            try:
                with open(stats_file, 'r', encoding='utf-8') as f:
                    content = f.read()
            except UnicodeDecodeError:
                with open(stats_file, 'r', encoding='latin-1') as f:
                    content = f.read()
                    
            # Estrai CPU e memoria usando regex
            cpu_match = re.search(r'(\d+\.\d+)%', content)
            mem_match = re.search(r'(\d+\.\d+)MiB / (\d+\.\d+)GiB\s+(\d+\.\d+)%', content)
            
            if cpu_match:
                result['resource_usage']['cpu_percent'] = float(cpu_match.group(1))
            if mem_match:
                result['resource_usage']['memory_mb'] = float(mem_match.group(1))
                result['resource_usage']['memory_limit_gb'] = float(mem_match.group(2))
                result['resource_usage']['memory_percent'] = float(mem_match.group(3))
        
        # Determina status del test
        if result['producer_metrics']['total_records'] == 0:
            result['status'] = 'FAILED'
        
        return result
    
    def analyze_all_tests(self) -> Dict:
        """Analizza tutti i test nella directory"""
        print("Starting comprehensive benchmark analysis...")
        
        all_results = {}
        test_dirs = [d for d in self.results_dir.iterdir() 
                    if d.is_dir() and d.name != 'analysis_results']
        
        if not test_dirs:
            print("No test directories found!")
            return {}
        
        for test_dir in test_dirs:
            try:
                result = self.analyze_single_test(test_dir)
                all_results[test_dir.name] = result
            except Exception as e:
                print(f"Error analyzing {test_dir.name}: {e}")
                all_results[test_dir.name] = {
                    'test_name': test_dir.name,
                    'status': 'ERROR',
                    'error': str(e)
                }
        
        return all_results
    
    def generate_performance_comparison(self, all_results: Dict) -> bool:
        """Genera grafici di confronto delle performance"""
        if not PLOTTING_AVAILABLE:
            print("Skipping charts - matplotlib not available")
            return False
            
        print("Generating performance comparison charts...")
        
        # Prepara dati per grafici
        test_names = []
        throughputs = []
        latencies = []
        cpu_usage = []
        memory_usage = []
        
        for test_name, result in all_results.items():
            if result['status'] == 'SUCCESS':
                test_names.append(test_name.replace('-', '\n'))
                throughputs.append(result['producer_metrics']['throughput_records_sec'])
                latencies.append(result['producer_metrics']['avg_latency_ms'])
                cpu_usage.append(result['resource_usage'].get('cpu_percent', 0))
                memory_usage.append(result['resource_usage'].get('memory_percent', 0))
        
        if not test_names:
            print("No successful tests to plot")
            return False
        
        # Crea figura con subplots
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(16, 12))
        fig.suptitle('Kafka Benchmark Performance Comparison', fontsize=16, fontweight='bold')
        
        # 1. Throughput comparison
        bars1 = ax1.bar(test_names, throughputs, 
                       color=[self.colors.get(name.replace('\n', '-'), '#1f77b4') for name in test_names])
        ax1.set_title('Throughput Comparison')
        ax1.set_ylabel('Records/sec')
        ax1.tick_params(axis='x', rotation=45)
        
        # Aggiungi valori sopra le barre
        for bar, value in zip(bars1, throughputs):
            if value > 0:
                ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + max(throughputs)*0.01,
                        f'{value:.0f}', ha='center', va='bottom', fontweight='bold')
        
        # 2. Latency comparison
        bars2 = ax2.bar(test_names, latencies,
                       color=[self.colors.get(name.replace('\n', '-'), '#ff7f0e') for name in test_names])
        ax2.set_title('Average Latency Comparison')
        ax2.set_ylabel('Latency (ms)')
        ax2.tick_params(axis='x', rotation=45)
        
        for bar, value in zip(bars2, latencies):
            if value > 0:
                ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + max(latencies)*0.01,
                        f'{value:.2f}', ha='center', va='bottom', fontweight='bold')
        
        # 3. CPU Usage
        bars3 = ax3.bar(test_names, cpu_usage,
                       color=[self.colors.get(name.replace('\n', '-'), '#2ca02c') for name in test_names])
        ax3.set_title('CPU Usage Comparison')
        ax3.set_ylabel('CPU %')
        ax3.tick_params(axis='x', rotation=45)
        
        for bar, value in zip(bars3, cpu_usage):
            if value > 0:
                ax3.text(bar.get_x() + bar.get_width()/2, bar.get_height() + max(cpu_usage)*0.01,
                        f'{value:.1f}%', ha='center', va='bottom', fontweight='bold')
        
        # 4. Memory Usage
        bars4 = ax4.bar(test_names, memory_usage,
                       color=[self.colors.get(name.replace('\n', '-'), '#d62728') for name in test_names])
        ax4.set_title('Memory Usage Comparison')
        ax4.set_ylabel('Memory %')
        ax4.tick_params(axis='x', rotation=45)
        
        for bar, value in zip(bars4, memory_usage):
            if value > 0:
                ax4.text(bar.get_x() + bar.get_width()/2, bar.get_height() + max(memory_usage)*0.01,
                        f'{value:.1f}%', ha='center', va='bottom', fontweight='bold')
        
        plt.tight_layout()
        chart_file = self.analysis_dir / "performance_comparison.png"
        plt.savefig(chart_file, dpi=300, bbox_inches='tight')
        plt.close()
        print(f"Performance comparison saved: {chart_file}")
        return True
    
    def export_detailed_csv(self, all_results: Dict) -> None:
        """Esporta risultati dettagliati in CSV"""
        print("Exporting detailed results to CSV...")
        
        csv_file = self.analysis_dir / "detailed_results.csv"
        
        with open(csv_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            
            # Header
            header = [
                'test_name', 'status', 'total_records', 'throughput_records_sec',
                'throughput_mb_sec', 'avg_latency_ms', 'max_latency_ms',
                'p50_latency_ms', 'p95_latency_ms', 'p99_latency_ms', 'p99_9_latency_ms',
                'consumer_mb_sec', 'consumer_msg_sec', 'cpu_percent', 'memory_percent',
                'batch_size', 'linger_ms', 'compression_type', 'buffer_memory'
            ]
            writer.writerow(header)
            
            # Dati
            for test_name, result in all_results.items():
                if result['status'] == 'SUCCESS':
                    pm = result['producer_metrics']
                    cm = result['consumer_metrics'] 
                    ru = result['resource_usage']
                    cfg = result['config']
                    
                    row = [
                        test_name, result['status'], pm['total_records'],
                        pm['throughput_records_sec'], pm['throughput_mb_sec'],
                        pm['avg_latency_ms'], pm['max_latency_ms'],
                        pm['p50_latency_ms'], pm['p95_latency_ms'], 
                        pm['p99_latency_ms'], pm['p99_9_latency_ms'],
                        cm['mb_per_sec'], cm['msg_per_sec'],
                        ru.get('cpu_percent', 0), ru.get('memory_percent', 0),
                        cfg.get('KAFKA_BATCH_SIZE', ''), cfg.get('KAFKA_LINGER_MS', ''),
                        cfg.get('KAFKA_COMPRESSION_TYPE', ''), cfg.get('KAFKA_BUFFER_MEMORY', '')
                    ]
                    writer.writerow(row)
        
        print(f"Detailed CSV exported: {csv_file}")
    
    def generate_markdown_report(self, all_results: Dict) -> None:
        """Genera report dettagliato in Markdown"""
        print("Generating detailed markdown report...")
        
        report_file = self.analysis_dir / "DETAILED_ANALYSIS_REPORT.md"
        
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write(f"""# Kafka Benchmark Detailed Analysis Report

**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  
**Total Tests Analyzed**: {len(all_results)}

## Executive Summary

""")
            
            # Trova best performers
            successful_tests = {k: v for k, v in all_results.items() if v['status'] == 'SUCCESS'}
            
            if successful_tests:
                # Miglior throughput
                best_throughput = max(successful_tests.items(), 
                                    key=lambda x: x[1]['producer_metrics']['throughput_records_sec'])
                
                # Miglior latenza
                best_latency = min(successful_tests.items(),
                                 key=lambda x: x[1]['producer_metrics']['avg_latency_ms'])
                
                # Miglior efficienza (throughput/latenza)
                best_efficiency = max(successful_tests.items(),
                                    key=lambda x: x[1]['producer_metrics']['throughput_records_sec'] / 
                                                 max(x[1]['producer_metrics']['avg_latency_ms'], 0.1))
                
                f.write(f"""### Top Performers

- **Highest Throughput**: **{best_throughput[0]}** ({best_throughput[1]['producer_metrics']['throughput_records_sec']:.1f} records/sec)
- **Lowest Latency**: **{best_latency[0]}** ({best_latency[1]['producer_metrics']['avg_latency_ms']:.2f} ms)
- **Best Efficiency**: **{best_efficiency[0]}** ({best_efficiency[1]['producer_metrics']['throughput_records_sec']/max(best_efficiency[1]['producer_metrics']['avg_latency_ms'], 0.1):.1f} records/sec/ms)

""")
            
            f.write("""## Detailed Results

| Test | Status | Throughput (rec/s) | Latency (ms) | CPU % | Memory % | Config Highlights |
|------|--------|-------------------|--------------|-------|----------|-------------------|
""")
            
            for test_name, result in all_results.items():
                if result['status'] == 'SUCCESS':
                    pm = result['producer_metrics']
                    ru = result['resource_usage']
                    cfg = result['config']
                    
                    config_summary = f"Batch: {cfg.get('KAFKA_BATCH_SIZE', 'N/A')}, " \
                                   f"Linger: {cfg.get('KAFKA_LINGER_MS', 'N/A')}ms, " \
                                   f"Compression: {cfg.get('KAFKA_COMPRESSION_TYPE', 'N/A')}"
                    
                    f.write(f"| {test_name} | SUCCESS | {pm['throughput_records_sec']:.1f} | "
                           f"{pm['avg_latency_ms']:.2f} | {ru.get('cpu_percent', 0):.1f} | "
                           f"{ru.get('memory_percent', 0):.1f} | {config_summary} |\n")
                else:
                    f.write(f"| {test_name} | {result['status']} | - | - | - | - | - |\n")
            
            # Sezione raccomandazioni
            f.write(f"""

## Recommendations

""")
            
            if successful_tests:
                f.write("Based on the analysis results:\n\n")
                
                # Raccomandazione per throughput
                if best_throughput[1]['producer_metrics']['throughput_records_sec'] > 1000:
                    f.write(f"1. **For High Throughput**: Use configuration similar to `{best_throughput[0]}` "
                           f"which achieved {best_throughput[1]['producer_metrics']['throughput_records_sec']:.0f} records/sec\n\n")
                
                # Raccomandazione per latenza
                if best_latency[1]['producer_metrics']['avg_latency_ms'] < 5:
                    f.write(f"2. **For Low Latency**: Use configuration similar to `{best_latency[0]}` "
                           f"which achieved {best_latency[1]['producer_metrics']['avg_latency_ms']:.2f}ms average latency\n\n")
                
                # Raccomandazione per efficienza
                f.write(f"3. **For Best Balance**: Consider `{best_efficiency[0]}` configuration "
                       f"for optimal throughput/latency ratio\n\n")
            
            f.write("""

---
*This report was automatically generated by the Kafka Benchmark Analyzer*
""")
        
        print(f"Detailed report saved: {report_file}")
    
    def export_json_data(self, all_results: Dict) -> None:
        """Esporta dati completi in JSON per ulteriori elaborazioni"""
        json_file = self.analysis_dir / "analysis_results.json"
        
        # Converti dati in formato JSON serializable
        json_data = {}
        for test_name, result in all_results.items():
            json_data[test_name] = result
        
        with open(json_file, 'w', encoding='utf-8') as f:
            json.dump(json_data, f, indent=2)
        
        print(f"JSON data exported: {json_file}")
    
    def run_complete_analysis(self) -> None:
        """Esegue analisi completa"""
        print("Starting complete Kafka benchmark analysis...")
        print("=" * 60)
        
        # Analizza tutti i test
        all_results = self.analyze_all_tests()
        
        if not all_results:
            print("No results to analyze!")
            return
        
        print("\nGenerating reports and visualizations...")
        print("-" * 40)
        
        # Genera tutti i report
        charts_generated = self.generate_performance_comparison(all_results)
        self.export_detailed_csv(all_results)
        self.generate_markdown_report(all_results)
        self.export_json_data(all_results)
        
        print("\nAnalysis completed successfully!")
        print("=" * 60)
        print(f"All results saved in: {self.analysis_dir}")
        print(f"Main report: {self.analysis_dir}/DETAILED_ANALYSIS_REPORT.md")
        print(f"CSV data: {self.analysis_dir}/detailed_results.csv")
        
        if charts_generated:
            print(f"Performance charts: {self.analysis_dir}/performance_comparison.png")

def main():
    """Funzione principale"""
    import sys
    
    # Determina directory dei risultati
    if len(sys.argv) > 1:
        results_dir = sys.argv[1]
    else:
        # Cerca la directory più recente con pattern kafka_benchmark_results_*
        current_dir = Path('.')
        result_dirs = sorted([d for d in current_dir.iterdir() 
                            if d.is_dir() and d.name.startswith('kafka_benchmark_results_')],
                           key=lambda x: x.stat().st_mtime, reverse=True)
        
        if result_dirs:
            results_dir = str(result_dirs[0])
            print(f"Auto-detected results directory: {results_dir}")
        else:
            print("No benchmark results directory found!")
            print("Usage: python3 analyze_benchmark_results_fixed.py [results_directory]")
            print("Or run from a directory containing kafka_benchmark_results_* folders")
            sys.exit(1)
    
    if not Path(results_dir).exists():
        print(f"Results directory not found: {results_dir}")
        sys.exit(1)
    
    # Esegui analisi
    analyzer = KafkaBenchmarkAnalyzer(results_dir)
    analyzer.run_complete_analysis()

if __name__ == "__main__":
    main()