#!/usr/bin/env python3
"""
Baseline Benchmark for Kafka-Blockchain Research
Tests default Kafka configuration performance
"""

import time
import json
import statistics
from kafka import KafkaProducer, KafkaConsumer
from kafka.errors import KafkaError
import threading
from datetime import datetime

class BlockchainBenchmark:
    def __init__(self, bootstrap_servers='kafka:29092'):
        self.bootstrap_servers = bootstrap_servers
        self.topic = 'blockchain-benchmark'
        self.results = {
            'test_start': datetime.now().isoformat(),
            'configuration': 'default',
            'throughput': {},
            'latency': {},
            'errors': []
        }
        
    def setup_topic(self):
        """Create benchmark topic"""
        print("Setting up benchmark topic...")
        # This would use kafka-python admin client in production
        # For now, we'll assume topic exists
        
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
    
    def producer_test(self, num_messages=1000, batch_test=False):
        """Test message production throughput"""
        print(f"Starting producer test: {num_messages} messages")
        
        # Default producer config (baseline)
        producer_config = {
            'bootstrap_servers': [self.bootstrap_servers],
            'value_serializer': lambda v: json.dumps(v).encode('utf-8'),
            'key_serializer': lambda v: str(v).encode('utf-8') if v else None,
            # Default configs (will be optimized later)
            'batch_size': 16384,
            'linger_ms': 0,
            'compression_type': None,
            'acks': 'all',
            'retries': 3
            # Note: enable_idempotence removed due to kafka-python version compatibility
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
            'errors': error_count
        }
        
        self.results['latency']['producer'] = {
            'avg_ms': avg_latency,
            'p95_ms': p95_latency,
            'p99_ms': p99_latency,
            'min_ms': min(latencies) if latencies else 0,
            'max_ms': max(latencies) if latencies else 0
        }
        
        print(f"Producer Results:")
        print(f"  Throughput: {throughput:.2f} msgs/sec")
        print(f"  Avg Latency: {avg_latency:.2f} ms")
        print(f"  P95 Latency: {p95_latency:.2f} ms")
        print(f"  Errors: {error_count}")
        
    def consumer_test(self, expected_messages=1000):
        """Test message consumption"""
        print(f"Starting consumer test: expecting {expected_messages} messages")
        
        consumer_config = {
            'bootstrap_servers': [self.bootstrap_servers],
            'value_deserializer': lambda v: json.loads(v.decode('utf-8')),
            'key_deserializer': lambda v: v.decode('utf-8') if v else None,
            'group_id': 'benchmark_consumer',
            'auto_offset_reset': 'earliest',
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
        
    def run_benchmark(self, num_messages=1000):
        """Run complete benchmark suite"""
        print("=" * 60)
        print("KAFKA BLOCKCHAIN BASELINE BENCHMARK")
        print("=" * 60)
        
        print("Configuration: Default Kafka settings")
        print(f"Messages: {num_messages}")
        print(f"Bootstrap servers: {self.bootstrap_servers}")
        print()
        
        # Run producer test
        self.producer_test(num_messages)
        
        print("\nWaiting 5 seconds before consumer test...")
        time.sleep(5)
        
        # Run consumer test
        self.consumer_test(num_messages)
        
        # Save results
        self.save_results()
        
        print("\n" + "=" * 60)
        print("BENCHMARK COMPLETE")
        print("=" * 60)
        
    def save_results(self):
        """Save benchmark results to file"""
        self.results['test_end'] = datetime.now().isoformat()
        
        filename = f"/results/baseline_benchmark_{int(time.time())}.json"
        
        try:
            with open(filename, 'w') as f:
                json.dump(self.results, f, indent=2)
            print(f"Results saved to: {filename}")
        except Exception as e:
            print(f"Failed to save results: {e}")
            print("Results:", json.dumps(self.results, indent=2))

if __name__ == "__main__":
    benchmark = BlockchainBenchmark()
    
    # Start with smaller test, can increase later
    benchmark.run_benchmark(num_messages=500)