#!/usr/bin/env python3
"""
Simple results analyzer for Kafka performance tests
Analyzes basic Kafka producer/consumer performance without blockchain complexity
"""

import json
import os
import sys
import re
from pathlib import Path
from datetime import datetime

class SimpleKafkaAnalyzer:
    def __init__(self, results_dir):
        self.results_dir = Path(results_dir)
        self.config = self._load_config()
        
    def _load_config(self):
        """Load test configuration"""
        config_file = self.results_dir / 'config-used.env'
        config = {}
        
        if config_file.exists():
            with open(config_file, 'r') as f:
                for line in f:
                    if '=' in line and not line.startswith('#'):
                        key, value = line.strip().split('=', 1)
                        config[key] = value
        return config
    
    def parse_producer_results(self):
        """Parse producer performance test results"""
        producer_log = self.results_dir / 'producer-test.log'
        results = {}
        
        if not producer_log.exists():
            return results
            
        with open(producer_log, 'r') as f:
            content = f.read()
            
        # Parse producer metrics
        # Example: "100000 records sent, 9950.248756 records/sec (9.72 MB/sec), 2.1 ms avg latency, 156.0 ms max latency"
        pattern = r'(\d+) records sent, ([\d.]+) records/sec \(([\d.]+) MB/sec\), ([\d.]+) ms avg latency, ([\d.]+) ms max latency'
        matches = re.findall(pattern, content)
        
        if matches:
            last_match = matches[-1]  # Get the final result
            results = {
                'records_sent': int(last_match[0]),
                'records_per_sec': float(last_match[1]),
                'mb_per_sec': float(last_match[2]),
                'avg_latency_ms': float(last_match[3]),
                'max_latency_ms': float(last_match[4])
            }
            
        return results
    
    def parse_consumer_results(self):
        """Parse consumer performance test results"""
        consumer_log = self.results_dir / 'consumer-test.log'
        results = {}
        
        if not consumer_log.exists():
            return results
            
        with open(consumer_log, 'r') as f:
            content = f.read()
            
        # Parse consumer metrics
        # Example: "start.time, end.time, data.consumed.in.MB, MB.sec, data.consumed.in.nMsg, nMsg.sec"
        lines = content.strip().split('\n')
        if len(lines) >= 2:  # Header + data line
            data_line = lines[-1]  # Last line with actual data
            parts = data_line.split(',')
            
            if len(parts) >= 6:
                try:
                    results = {
                        'start_time': parts[0].strip(),
                        'end_time': parts[1].strip(),
                        'data_consumed_mb': float(parts[2].strip()),
                        'mb_per_sec': float(parts[3].strip()),
                        'messages_consumed': int(parts[4].strip()),
                        'messages_per_sec': float(parts[5].strip())
                    }
                except (ValueError, IndexError):
                    pass
                    
        return results
    
    def parse_docker_stats(self):
        """Parse Docker container resource usage"""
        stats_file = self.results_dir / 'final-stats.txt'
        results = {}
        
        if not stats_file.exists():
            return results
            
        with open(stats_file, 'r') as f:
            lines = f.readlines()
            
        # Parse Docker stats format
        # CONTAINER   CPU %     MEM USAGE / LIMIT     MEM %     NET I/O           BLOCK I/O         PIDS
        for line in lines:
            if 'kafka' in line.lower() and '%' in line:
                parts = line.split()
                if len(parts) >= 6:
                    try:
                        results = {
                            'container_name': parts[0],
                            'cpu_percent': parts[1].replace('%', ''),
                            'memory_usage': parts[2],
                            'memory_limit': parts[4],
                            'memory_percent': parts[5].replace('%', ''),
                            'network_io': parts[6] if len(parts) > 6 else 'N/A',
                            'block_io': parts[8] if len(parts) > 8 else 'N/A'
                        }
                    except (ValueError, IndexError):
                        pass
                        
        return results
    
    def analyze_configuration_impact(self):
        """Analyze the impact of configuration parameters"""
        analysis = {}
        
        # Extract key parameters
        batch_size = int(self.config.get('KAFKA_BATCH_SIZE', '16384'))
        linger_ms = int(self.config.get('KAFKA_LINGER_MS', '0'))
        compression = self.config.get('KAFKA_COMPRESSION_TYPE', 'none')
        buffer_memory = int(self.config.get('KAFKA_BUFFER_MEMORY', '33554432'))
        
        # Analyze batch size impact
        if batch_size > 32768:
            analysis['batch_size'] = "Large batch size may improve throughput but increase latency"
        elif batch_size < 16384:
            analysis['batch_size'] = "Small batch size may reduce latency but limit throughput"
        else:
            analysis['batch_size'] = "Standard batch size configuration"
            
        # Analyze linger time
        if linger_ms > 0:
            analysis['linger_ms'] = f"Linger time of {linger_ms}ms enables batching for better throughput"
        else:
            analysis['linger_ms'] = "Zero linger time prioritizes low latency over throughput"
            
        # Analyze compression
        if compression != 'none':
            analysis['compression'] = f"{compression} compression reduces network usage but increases CPU load"
        else:
            analysis['compression'] = "No compression - prioritizes CPU efficiency over network bandwidth"
            
        return analysis
    
    def generate_recommendations(self, producer_results, consumer_results, docker_stats):
        """Generate optimization recommendations"""
        recommendations = []
        
        # Throughput analysis
        if producer_results.get('records_per_sec', 0) < 1000:
            recommendations.append("Low throughput detected - consider increasing batch.size or adding linger.ms")
            
        # Latency analysis  
        if producer_results.get('avg_latency_ms', 0) > 100:
            recommendations.append("High latency detected - consider reducing batch.size or linger.ms")
            
        # Resource utilization
        if docker_stats.get('cpu_percent'):
            try:
                cpu_usage = float(docker_stats['cpu_percent'])
                if cpu_usage > 80:
                    recommendations.append("High CPU usage - consider enabling compression or reducing load")
                elif cpu_usage < 20:
                    recommendations.append("Low CPU usage - opportunity to increase throughput")
            except ValueError:
                pass
                
        # Configuration-specific recommendations
        current_batch = int(self.config.get('KAFKA_BATCH_SIZE', '16384'))
        current_linger = int(self.config.get('KAFKA_LINGER_MS', '0'))
        
        if current_batch == 16384 and current_linger == 0:
            recommendations.append("Testing with larger batch size (64KB) and linger time (10ms) may improve throughput")
            
        if not recommendations:
            recommendations.append("Current configuration appears well-balanced for this workload")
            
        return recommendations
    
    def compare_with_baseline(self, baseline_results):
        """Compare results with baseline configuration"""
        # This would compare with a known baseline
        # For now, we'll use Paper 3 baseline as reference
        paper3_baseline = {
            'target_tps': 1000,
            'expected_latency': 50,  # ms
            'cpu_efficiency_target': 65  # Based on Paper 3 Raft being 35% more efficient
        }
        
        return paper3_baseline
    
    def generate_report(self):
        """Generate comprehensive analysis report"""
        producer_results = self.parse_producer_results()
        consumer_results = self.parse_consumer_results()
        docker_stats = self.parse_docker_stats()
        config_analysis = self.analyze_configuration_impact()
        recommendations = self.generate_recommendations(producer_results, consumer_results, docker_stats)
        
        report = []
        report.append("=" * 60)
        report.append("SIMPLIFIED KAFKA PERFORMANCE ANALYSIS REPORT")
        report.append("=" * 60)
        report.append(f"Results Directory: {self.results_dir}")
        report.append(f"Analysis Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append("")
        
        # Configuration section
        report.append("CONFIGURATION TESTED:")
        report.append("-" * 25)
        key_params = [
            'KAFKA_BATCH_SIZE', 'KAFKA_LINGER_MS', 'KAFKA_COMPRESSION_TYPE',
            'KAFKA_BUFFER_MEMORY', 'KAFKA_NUM_NETWORK_THREADS', 'KAFKA_NUM_IO_THREADS'
        ]
        
        for param in key_params:
            if param in self.config:
                report.append(f"{param:25}: {self.config[param]}")
        report.append("")
        
        # Producer Performance
        report.append("PRODUCER PERFORMANCE:")
        report.append("-" * 25)
        if producer_results:
            report.append(f"Records Sent:     {producer_results.get('records_sent', 'N/A'):,}")
            report.append(f"Throughput:       {producer_results.get('records_per_sec', 'N/A'):,.1f} records/sec")
            report.append(f"Data Rate:        {producer_results.get('mb_per_sec', 'N/A'):.2f} MB/sec")
            report.append(f"Average Latency:  {producer_results.get('avg_latency_ms', 'N/A'):.1f} ms")
            report.append(f"Maximum Latency:  {producer_results.get('max_latency_ms', 'N/A'):.1f} ms")
        else:
            report.append("Producer results not available")
        report.append("")
        
        # Consumer Performance
        report.append("CONSUMER PERFORMANCE:")
        report.append("-" * 25)
        if consumer_results:
            report.append(f"Messages Consumed: {consumer_results.get('messages_consumed', 'N/A'):,}")
            report.append(f"Throughput:        {consumer_results.get('messages_per_sec', 'N/A'):,.1f} records/sec")
            report.append(f"Data Rate:         {consumer_results.get('mb_per_sec', 'N/A'):.2f} MB/sec")
            report.append(f"Total Data:        {consumer_results.get('data_consumed_mb', 'N/A'):.2f} MB")
        else:
            report.append("Consumer results not available")
        report.append("")
        
        # Resource Utilization
        report.append("RESOURCE UTILIZATION:")
        report.append("-" * 25)
        if docker_stats:
            report.append(f"CPU Usage:        {docker_stats.get('cpu_percent', 'N/A')}%")
            report.append(f"Memory Usage:     {docker_stats.get('memory_usage', 'N/A')}")
            report.append(f"Memory Limit:     {docker_stats.get('memory_limit', 'N/A')}")
            report.append(f"Memory Percent:   {docker_stats.get('memory_percent', 'N/A')}%")
            report.append(f"Network I/O:      {docker_stats.get('network_io', 'N/A')}")
        else:
            report.append("Resource stats not available")
        report.append("")
        
        # Configuration Analysis
        report.append("CONFIGURATION ANALYSIS:")
        report.append("-" * 30)
        for param, analysis in config_analysis.items():
            report.append(f"• {param.replace('_', ' ').title()}: {analysis}")
        report.append("")
        
        # Paper Comparison
        report.append("COMPARISON WITH LITERATURE:")
        report.append("-" * 35)
        if producer_results:
            tps = producer_results.get('records_per_sec', 0)
            latency = producer_results.get('avg_latency_ms', 0)
            
            report.append(f"Measured Throughput: {tps:,.0f} TPS")
            report.append("Paper 2 Baseline:   ~1000 TPS (target)")
            report.append("Paper 3 Finding:    Raft 35% more CPU efficient than default Kafka")
            
            if tps >= 1000:
                improvement = ((tps - 1000) / 1000) * 100
                report.append(f"Performance:        +{improvement:.1f}% vs baseline target")
            else:
                gap = ((1000 - tps) / 1000) * 100
                report.append(f"Performance Gap:    -{gap:.1f}% vs baseline target")
                
            if latency <= 50:
                report.append(f"Latency:            {latency:.1f}ms (✓ Good)")
            else:
                report.append(f"Latency:            {latency:.1f}ms (⚠ High)")
        report.append("")
        
        # Recommendations
        report.append("OPTIMIZATION RECOMMENDATIONS:")
        report.append("-" * 35)
        for i, rec in enumerate(recommendations, 1):
            report.append(f"{i}. {rec}")
        report.append("")
        
        # Next Steps
        report.append("NEXT STEPS:")
        report.append("-" * 15)
        report.append("1. Test alternative configurations based on recommendations")
        report.append("2. Compare results across different parameter combinations")
        report.append("3. Identify optimal configuration for target workload")
        report.append("4. Document best practices for production deployment")
        
        return "\n".join(report)

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 analyze-simple-results.py <results_directory>")
        sys.exit(1)
    
    results_dir = sys.argv[1]
    
    if not os.path.exists(results_dir):
        print(f"Error: Results directory not found: {results_dir}")
        sys.exit(1)
    
    # Initialize analyzer
    analyzer = SimpleKafkaAnalyzer(results_dir)
    
    # Generate report
    report = analyzer.generate_report()
    
    # Save report
    output_file = Path(results_dir) / 'analysis_report.txt'
    with open(output_file, 'w') as f:
        f.write(report)
    
    print(f"✓ Analysis report saved: {output_file}")
    print("\n" + "="*60)
    print(report)
    print("="*60)
    
    print(f"\n✓ Analysis complete! Report saved in: {results_dir}")

if __name__ == "__main__":
    main()