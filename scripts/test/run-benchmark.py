#!/usr/bin/env python3
"""
Automated benchmark runner for Kafka optimization testing
"""

import argparse
import yaml
import subprocess
import time
import json
from datetime import datetime
import os

class BenchmarkRunner:
    def __init__(self, config_file="configs/parameters/test-matrix.yaml"):
        with open(config_file, 'r') as f:
            self.config = yaml.safe_load(f)
        
        self.results_dir = "results"
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    def run_baseline_test(self):
        """Run baseline Raft vs Default Kafka test"""
        print("🔬 Running baseline comparison...")
        
        # Deploy Raft configuration
        self._deploy_config("raft_baseline")
        raft_results = self._execute_workload("smallbank", duration=600)  # 10 min
        
        # Deploy Kafka default configuration  
        self._deploy_config("kafka_default")
        kafka_results = self._execute_workload("smallbank", duration=600)
        
        # Save baseline results
        baseline_results = {
            "timestamp": self.timestamp,
            "raft_baseline": raft_results,
            "kafka_default": kafka_results,
            "performance_gap": self._calculate_gap(raft_results, kafka_results)
        }
        
        self._save_results("baseline", baseline_results)
        return baseline_results
    
    def run_single_parameter_tests(self):
        """Run single parameter optimization tests"""
        print("⚙️ Running single parameter tests...")
        
        results = {}
        
        for param_name, param_config in self.config['single_parameters'].items():
            if param_config.get('priority') != 'HIGH':
                continue  # Start with high priority only
                
            print(f"Testing parameter: {param_name}")
            param_results = []
            
            for test_value in param_config['test_values']:
                print(f"  Testing {param_name}={test_value}")
                
                # Deploy configuration with single parameter change
                config = self._create_single_param_config(param_name, test_value)
                self._deploy_config("kafka_optimized", config)
                
                # Run workload
                result = self._execute_workload("smallbank", duration=300)  # 5 min
                result['parameter'] = param_name
                result['value'] = test_value
                
                param_results.append(result)
                
                # Brief cooldown
                time.sleep(60)
            
            results[param_name] = param_results
        
        self._save_results("single-param", results)
        return results
    
    def _deploy_config(self, config_type, custom_config=None):
        """Deploy specific configuration"""
        if config_type == "raft_baseline":
            cmd = ["docker-compose", "-f", "docker/fabric/docker-compose-raft.yml", "up", "-d"]
        else:
            # Update Kafka configuration
            if custom_config:
                self._update_kafka_config(custom_config)
            cmd = ["docker-compose", "up", "-d"]
        
        subprocess.run(cmd, check=True)
        time.sleep(60)  # Wait for startup
    
    def _execute_workload(self, workload_type, duration=300):
        """Execute benchmark workload"""
        start_time = time.time()
        
        if workload_type == "smallbank":
            # Use Hyperledger Caliper or custom workload generator
            cmd = [
                "docker", "exec", "test-runner", 
                "python", "/src/benchmarking/workload_generator.py",
                "--type", "smallbank",
                "--duration", str(duration),
                "--output", "/results/current_test.json"
            ]
        
        subprocess.run(cmd, check=True)
        
        # Collect metrics from monitoring
        metrics = self._collect_metrics(start_time, duration)
        
        return metrics
    
    def _collect_metrics(self, start_time, duration):
        """Collect performance and resource metrics"""
        # Query Prometheus for metrics
        end_time = start_time + duration
        
        # This would integrate with Prometheus API
        # For now, return mock structure
        return {
            "throughput_tps": 0,  # Will be populated by actual metrics
            "latency_p50": 0,
            "latency_p95": 0,
            "latency_p99": 0,
            "cpu_usage_avg": 0,
            "memory_usage_avg": 0,
            "network_bytes_sent": 0,
            "network_bytes_received": 0,
            "disk_io_read": 0,
            "disk_io_write": 0,
        }
    
    def _create_single_param_config(self, param_name, value):
        """Create configuration with single parameter modified"""
        config = {
            # Default values
            "batch_size": 16384,
            "linger_ms": 0,
            "compression_type": "none",
            "num_network_threads": 3,
            "num_io_threads": 8,
            "buffer_memory": 33554432,
        }
        
        # Override single parameter
        if param_name == "batch_size":
            config["batch_size"] = value
        elif param_name == "linger_ms":
            config["linger_ms"] = value
        elif param_name == "compression_type":
            config["compression_type"] = value
        elif param_name == "num_network_threads":
            config["num_network_threads"] = value
        # Add other parameters as needed
        
        return config
    
    def _update_kafka_config(self, config):
        """Update Kafka configuration via environment variables"""
        # This would update docker-compose environment or
        # generate new server.properties file
        pass
    
    def _save_results(self, test_type, results):
        """Save results to JSON file"""
        filename = f"{self.results_dir}/{test_type}/{self.timestamp}_results.json"
        os.makedirs(os.path.dirname(filename), exist_ok=True)
        
        with open(filename, 'w') as f:
            json.dump(results, f, indent=2)
        
        print(f"📊 Results saved to {filename}")
    
    def _calculate_gap(self, raft_results, kafka_results):
        """Calculate performance gap between Raft and Kafka"""
        if raft_results["throughput_tps"] > 0:
            throughput_gap = (kafka_results["throughput_tps"] / raft_results["throughput_tps"]) - 1
        else:
            throughput_gap = 0
            
        return {
            "throughput_gap_percent": throughput_gap * 100,
            "latency_gap_p95": kafka_results["latency_p95"] - raft_results["latency_p95"],
            "cpu_efficiency_ratio": raft_results["cpu_usage_avg"] / kafka_results["cpu_usage_avg"] if kafka_results["cpu_usage_avg"] > 0 else 0
        }

def main():
    parser = argparse.ArgumentParser(description="Run Kafka optimization benchmarks")
    parser.add_argument("--config", default="baseline", help="Test configuration to run")
    parser.add_argument("--duration", type=int, default=600, help="Test duration in seconds")
    
    args = parser.parse_args()
    
    runner = BenchmarkRunner()
    
    if args.config == "baseline":
        results = runner.run_baseline_test()
        print("📊 Baseline test completed:")
        print(f"   Throughput gap: {results['performance_gap']['throughput_gap_percent']:.1f}%")
        print(f"   Latency gap P95: {results['performance_gap']['latency_gap_p95']:.1f}ms")
        
    elif args.config == "single-param":
        results = runner.run_single_parameter_tests()
        print("📊 Single parameter tests completed")
        
        # Find best performer for each parameter
        for param_name, param_results in results.items():
            best_result = max(param_results, key=lambda x: x['throughput_tps'])
            print(f"   Best {param_name}: {best_result['value']} -> {best_result['throughput_tps']:.1f} TPS")

if __name__ == "__main__":
    main()