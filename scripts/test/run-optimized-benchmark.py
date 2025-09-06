#!/usr/bin/env python3
"""
Optimized Benchmark for Kafka-Blockchain Research
Tests optimized Kafka producer configuration
"""

import time
import json
import statistics
from kafka import KafkaProducer, KafkaConsumer
from kafka.errors import KafkaError
import threading
from datetime import datetime

class OptimizedBlockchainBenchmark:
    def __init__(self, bootstrap_servers='kafka:29092', config_name='optimized_v1'):
        self.bootstrap_servers = bootstrap_servers
        self.topic = 'blockchain-benchmark'
        self.config_name = config_name
        self.results = {
            'test_start': datetime.now().isoformat(),
            'configuration': config_name,
            'throughput': {},
            'latency': {},
            'errors': []
        }
        
    def create_blockchain_message(self, tx_id):
        """Simulate a blockchain transaction message"""
        return {
            'transaction_id': tx_id,
            'timestamp': time.time(),
            'from_address': f'0x{tx_id:040x}',
            'to_address': f'0x{(tx_id+1):040x}',
            'amount': 100.50,
            'gas_fee': 0.001,
            'block_number': tx_id // 100,
            'nonce': tx_id,
            'data': 'blockchain_test_data_' + 'x' * 100  # ~120 bytes
        }
    
    def get_optimized_config(self):
        """Return optimized producer configuration"""
        configs = {
            'optimized_v1': {
                'batch_size': 65536,  # 4x larger batches
                'linger_ms': 10,      # Small batching delay
                'compression_type': 'snappy'  # Compression for blockchain data
            },
            'optimized_v2': {
                'batch_size': 131072,  # 8x larger batches  
                'linger_ms': 25,       # Longer batching
                'compression_type': 'lz4'  # Different compression
            },
            'optimized_v3': {
                'batch_size': 262144,  # 16x larger batches
                'linger_ms': 50,       # Much longer batching
                'compression_type': 'gzip'  # High compression
            }
        }
        return configs.get(self.config_name, configs['optimized_v1'])
    
    def producer_test(self, num_messages=500):
        """Test message production with optimized settings"""
        print(f"Starting OPTIMIZED producer test: {num_messages} messages")
        
        optimized_params = self.get_optimized_config()
        print(f"Optimizations: {optimized_params}")
        
        # Optimized producer config
        producer_config = {
            'bootstrap_servers': [self.bootstrap_servers],
            'value_serializer': lambda v: json.dumps(v).encode('utf-8'),
            'key_serializer': lambda v: str(v).encode('utf-8') if v else None,
            'acks': 'all',
            'retries': 3,
            **optimized_params  # Add optimization parameters
        }
        
        producer = KafkaProducer(**producer_config)
        
        latencies = []
        sent_count = 0
        error_count = 0
        
        start_time = time.time()
        
        for i in range(num_messages):
            message = self.create_blockchain_message(i)
            key = f"tx_{i}"
            
            send_start = time.time()
            
            try:
                future = producer.send(self.topic, key=key, value=message)
                future.get(timeout=10)  # Wait for confirmation
                
                send_end = time.time()
                latencies.append((send_end - send_start) * 1000)  # ms
                sent_count += 1
                
                if (i + 1) % 100 == 0:
                    print(f"Sent {i + 1}/{num_messages} messages")
                    
            except KafkaError as e:
                error_count += 1
                self.results['errors'].append({
                    'type': 'producer_error',
                    'message': str(e),
                    'tx_id': i
                })
        
        producer.flush()
        producer.close()
        
        end_time = time.time()
        duration = end_time - start_time
        
        # Calculate metrics
        throughput = sent_count / duration if duration > 0 else 0
        avg_latency = statistics.mean(latencies) if latencies else 0
        p95_latency = statistics.quantiles(latencies, n=20)[18] if len(latencies) > 20 else 0
        p99_latency = statistics.quantiles(latencies, n=100)[98] if len(latencies) > 100 else 0
        
        self.results['throughput']['producer'] = {
            'messages_per_second': throughput,
            'total_messages': sent_count,
            'duration_seconds': duration,
            'errors': error_count,
            'optimization_params': optimized_params
        }
        
        self.results['latency']['producer'] = {
            'avg_ms': avg_latency,
            'p95_ms': p95_latency,
            'p99_ms': p99_latency,
            'min_ms': min(latencies) if latencies else 0,
            'max_ms': max(latencies) if latencies else 0
        }
        
        print(f"OPTIMIZED Producer Results:")
        print(f"  Throughput: {throughput:.2f} msgs/sec")
        print(f"  Avg Latency: {avg_latency:.2f} ms")
        print(f"  P95 Latency: {p95_latency:.2f} ms")
        print(f"  Errors: {error_count}")
        
        return throughput, avg_latency
        
    def consumer_test(self, expected_messages=500):
        """Test message consumption (same as baseline)"""
        print(f"Starting consumer test: expecting {expected_messages} messages")
        
        consumer_config = {
            'bootstrap_servers': [self.bootstrap_servers],
            'value_deserializer': lambda v: json.loads(v.decode('utf-8')),
            'key_deserializer': lambda v: v.decode('utf-8') if v else None,
            'group_id': f'benchmark_consumer_{int(time.time())}',  # Unique group
            'auto_offset_reset': 'latest',  # Only new messages
            'enable_auto_commit': True
        }
        
        consumer = KafkaConsumer(self.topic, **consumer_config)
        
        consumed_count = 0
        processing_times = []
        end_to_end_latencies = []
        
        start_time = time.time()
        timeout_start = time.time()
        
        print("Consuming messages...")
        
        for message in consumer:
            process_start = time.time()
            
            # Simulate blockchain transaction processing
            tx_data = message.value
            tx_timestamp = tx_data.get('timestamp', 0)
            
            # Calculate end-to-end latency
            if tx_timestamp > 0:
                e2e_latency = (process_start - tx_timestamp) * 1000  # ms
                end_to_end_latencies.append(e2e_latency)
            
            # Simulate processing time
            time.sleep(0.001)  # 1ms processing time
            
            process_end = time.time()
            processing_times.append((process_end - process_start) * 1000)
            
            consumed_count += 1
            
            if consumed_count % 100 == 0:
                print(f"Consumed {consumed_count}/{expected_messages} messages")
            
            if consumed_count >= expected_messages:
                break
                
            # Timeout safety
            if time.time() - timeout_start > 60:  # 60 second timeout
                print("Consumer timeout reached")
                break
        
        consumer.close()
        end_time = time.time()
        duration = end_time - start_time
        
        # Calculate metrics
        throughput = consumed_count / duration if duration > 0 else 0
        avg_processing = statistics.mean(processing_times) if processing_times else 0
        avg_e2e_latency = statistics.mean(end_to_end_latencies) if end_to_end_latencies else 0
        
        self.results['throughput']['consumer'] = {
            'messages_per_second': throughput,
            'total_messages': consumed_count,
            'duration_seconds': duration
        }
        
        self.results['latency']['consumer'] = {
            'avg_processing_ms': avg_processing,
            'avg_end_to_end_ms': avg_e2e_latency,
            'p95_e2e_ms': statistics.quantiles(end_to_end_latencies, n=20)[18] if len(end_to_end_latencies) > 20 else 0
        }
        
        print(f"Consumer Results:")
        print(f"  Throughput: {throughput:.2f} msgs/sec")
        print(f"  Processing Time: {avg_processing:.2f} ms")
        print(f"  End-to-End Latency: {avg_e2e_latency:.2f} ms")
        
        return throughput
        
    def run_comparison_benchmark(self, num_messages=500):
        """Run optimized benchmark and compare with baseline"""
        print("=" * 70)
        print(f"KAFKA OPTIMIZATION BENCHMARK - {self.config_name.upper()}")
        print("=" * 70)
        
        print(f"Configuration: {self.config_name}")
        print(f"Messages: {num_messages}")
        print(f"Bootstrap servers: {self.bootstrap_servers}")
        print()
        
        # Run producer test
        prod_throughput, prod_latency = self.producer_test(num_messages)
        
        print("\nWaiting 3 seconds before consumer test...")
        time.sleep(3)
        
        # Run consumer test  
        cons_throughput = self.consumer_test(num_messages)
        
        # Save results
        self.save_results()
        
        # Show comparison with baseline
        self.show_comparison(prod_throughput, prod_latency)
        
        print("\n" + "=" * 70)
        print("OPTIMIZATION BENCHMARK COMPLETE")
        print("=" * 70)
        
    def show_comparison(self, prod_throughput, prod_latency):
        """Compare with baseline results"""
        print("\n" + "=" * 50)
        print("PERFORMANCE COMPARISON")
        print("=" * 50)
        
        # Baseline numbers from your test
        baseline_throughput = 288.35
        baseline_latency = 3.45
        
        throughput_improvement = ((prod_throughput - baseline_throughput) / baseline_throughput) * 100
        latency_change = ((prod_latency - baseline_latency) / baseline_latency) * 100
        
        print(f"Throughput:")
        print(f"  Baseline:  {baseline_throughput:.2f} msgs/sec")
        print(f"  Optimized: {prod_throughput:.2f} msgs/sec")
        print(f"  Change:    {throughput_improvement:+.1f}%")
        
        print(f"\nLatency:")
        print(f"  Baseline:  {baseline_latency:.2f} ms")
        print(f"  Optimized: {prod_latency:.2f} ms")
        print(f"  Change:    {latency_change:+.1f}%")
        
        if throughput_improvement > 10:
            print(f"\n🎉 SIGNIFICANT IMPROVEMENT: +{throughput_improvement:.1f}% throughput!")
        elif throughput_improvement > 0:
            print(f"\n✅ Improvement: +{throughput_improvement:.1f}% throughput")
        else:
            print(f"\n⚠️  Performance regression: {throughput_improvement:.1f}% throughput")
            
    def save_results(self):
        """Save benchmark results to file"""
        self.results['test_end'] = datetime.now().isoformat()
        
        filename = f"/results/{self.config_name}_benchmark_{int(time.time())}.json"
        
        try:
            with open(filename, 'w') as f:
                json.dump(self.results, f, indent=2)
            print(f"Results saved to: {filename}")
        except Exception as e:
            print(f"Failed to save results: {e}")

if __name__ == "__main__":
    import sys
    
    # Allow choosing optimization config
    config_name = sys.argv[1] if len(sys.argv) > 1 else 'optimized_v1'
    
    benchmark = OptimizedBlockchainBenchmark(config_name=config_name)
    benchmark.run_comparison_benchmark(num_messages=500)