#!/usr/bin/env python3
"""
Stress Test Benchmark - Higher Load for Realistic Results
Tests with larger message volumes to stress the system
"""

import time
import json
import statistics
from kafka import KafkaProducer
import concurrent.futures

def create_large_blockchain_message(tx_id):
    """Create larger, more realistic blockchain message"""
    return {
        'transaction_id': f'0x{tx_id:064x}',
        'timestamp': time.time(),
        'from_address': f'0x{(tx_id * 13):064x}',
        'to_address': f'0x{(tx_id * 17):064x}',
        'amount': 100.50 + (tx_id % 1000),
        'gas_fee': 0.001 + (tx_id % 100) * 0.0001,
        'block_number': tx_id // 100,
        'nonce': tx_id,
        'signature': f'0x{"a" * 128}',  # Simulate signature
        'input_data': '0x' + 'f' * 500,  # ~500 chars of data
        'metadata': {
            'chain_id': 1,
            'contract_address': f'0x{(tx_id * 19):064x}',
            'function': 'transfer',
            'parameters': ['param1', 'param2', 'param3']
        }
    }

def test_sustained_load(batch_size, linger_ms, test_name, 
                       num_messages=10000, num_producers=3):
    """
    Sustained load test with multiple producers
    Simulates realistic blockchain network with multiple nodes
    """
    print(f"\n{'='*70}")
    print(f"{test_name}")
    print(f"{'='*70}")
    print(f"Config: batch_size={batch_size}, linger_ms={linger_ms}")
    print(f"Load: {num_messages} messages, {num_producers} concurrent producers")
    
    def producer_worker(producer_id, messages_per_producer):
        """Single producer worker"""
        producer = KafkaProducer(
            bootstrap_servers=['kafka:29092'],
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda v: str(v).encode('utf-8'),
            batch_size=batch_size,
            linger_ms=linger_ms,
            acks='all',
            retries=3,
            max_in_flight_requests_per_connection=5
        )
        
        futures = []
        start_offset = producer_id * messages_per_producer
        
        for i in range(messages_per_producer):
            tx_id = start_offset + i
            message = create_large_blockchain_message(tx_id)
            future = producer.send('blockchain-stress', key=f"tx_{tx_id}", value=message)
            futures.append(future)
        
        # Wait for all confirmations
        success = 0
        for future in futures:
            try:
                future.get(timeout=30)
                success += 1
            except:
                pass
        
        producer.flush()
        producer.close()
        
        return success
    
    messages_per_producer = num_messages // num_producers
    
    print(f"Starting {num_producers} producers...")
    start_time = time.time()
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=num_producers) as executor:
        futures = [
            executor.submit(producer_worker, i, messages_per_producer)
            for i in range(num_producers)
        ]
        
        results = [f.result() for f in concurrent.futures.as_completed(futures)]
    
    end_time = time.time()
    duration = end_time - start_time
    
    total_success = sum(results)
    throughput = total_success / duration
    
    print(f"\nResults:")
    print(f"  Duration:       {duration:.2f} seconds")
    print(f"  Throughput:     {throughput:.2f} msgs/sec")
    print(f"  Total Success:  {total_success}/{num_messages}")
    print(f"  Avg per Producer: {throughput/num_producers:.2f} msgs/sec")
    
    return {
        'name': test_name,
        'config': {'batch_size': batch_size, 'linger_ms': linger_ms},
        'throughput': throughput,
        'duration': duration,
        'total_messages': total_success,
        'num_producers': num_producers
    }

def test_burst_load(batch_size, linger_ms, test_name, burst_size=5000):
    """
    Burst load test - send large batch quickly
    Simulates blockchain block submission spike
    """
    print(f"\n{'='*70}")
    print(f"{test_name}")
    print(f"{'='*70}")
    print(f"Burst load: {burst_size} messages")
    
    producer = KafkaProducer(
        bootstrap_servers=['kafka:29092'],
        value_serializer=lambda v: json.dumps(v).encode('utf-8'),
        key_serializer=lambda v: str(v).encode('utf-8'),
        batch_size=batch_size,
        linger_ms=linger_ms,
        acks='all',
        retries=3,
        buffer_memory=67108864,  # 64MB buffer
        max_in_flight_requests_per_connection=5
    )
    
    futures = []
    
    print("Sending burst...")
    burst_start = time.time()
    
    for i in range(burst_size):
        message = create_large_blockchain_message(i)
        future = producer.send('blockchain-stress', key=f"burst_{i}", value=message)
        futures.append(future)
        
        if (i + 1) % 1000 == 0:
            print(f"  Queued {i + 1}/{burst_size}")
    
    burst_end = time.time()
    burst_duration = burst_end - burst_start
    
    print("Waiting for confirmations...")
    confirm_start = time.time()
    
    success = 0
    for future in futures:
        try:
            future.get(timeout=60)
            success += 1
        except:
            pass
    
    confirm_end = time.time()
    
    producer.flush()
    producer.close()
    
    total_duration = confirm_end - burst_start
    throughput = success / total_duration
    
    print(f"\nResults:")
    print(f"  Burst Duration:   {burst_duration:.2f}s")
    print(f"  Confirm Duration: {confirm_end - confirm_start:.2f}s")
    print(f"  Total Duration:   {total_duration:.2f}s")
    print(f"  Throughput:       {throughput:.2f} msgs/sec")
    print(f"  Success Rate:     {(success/burst_size)*100:.1f}%")
    
    return {
        'name': test_name,
        'throughput': throughput,
        'burst_duration': burst_duration,
        'total_duration': total_duration,
        'success_rate': (success/burst_size)*100
    }

def main():
    print("="*70)
    print("KAFKA STRESS TEST BENCHMARK")
    print("High-load scenarios for realistic blockchain performance")
    print("="*70)
    
    # Create topic first
    print("\nEnsure topic exists with: ")
    print("kafka-topics --create --topic blockchain-stress --bootstrap-server kafka:29092 --partitions 3 --replication-factor 1 --if-not-exists")
    
    time.sleep(3)
    
    sustained_results = []
    burst_results = []
    
    print("\n" + "="*70)
    print("SUSTAINED LOAD TESTS (10,000 messages)")
    print("="*70)
    
    # Sustained load tests
    sustained_results.append(test_sustained_load(
        batch_size=16384,
        linger_ms=0,
        test_name="SUSTAINED BASELINE",
        num_messages=10000,
        num_producers=3
    ))
    
    time.sleep(5)
    
    sustained_results.append(test_sustained_load(
        batch_size=65536,
        linger_ms=10,
        test_name="SUSTAINED OPT1: 4x Batch",
        num_messages=10000,
        num_producers=3
    ))
    
    time.sleep(5)
    
    sustained_results.append(test_sustained_load(
        batch_size=131072,
        linger_ms=25,
        test_name="SUSTAINED OPT2: 8x Batch",
        num_messages=10000,
        num_producers=3
    ))
    
    print("\n" + "="*70)
    print("BURST LOAD TESTS (5,000 messages)")
    print("="*70)
    
    time.sleep(5)
    
    burst_results.append(test_burst_load(
        batch_size=16384,
        linger_ms=0,
        test_name="BURST BASELINE",
        burst_size=5000
    ))
    
    time.sleep(5)
    
    burst_results.append(test_burst_load(
        batch_size=131072,
        linger_ms=25,
        test_name="BURST OPTIMIZED",
        burst_size=5000
    ))
    
    # Summary
    print("\n" + "="*70)
    print("SUSTAINED LOAD SUMMARY")
    print("="*70)
    
    baseline_sustained = sustained_results[0]['throughput']
    
    for r in sustained_results:
        improvement = ((r['throughput'] - baseline_sustained) / baseline_sustained) * 100
        print(f"{r['name']:<30} {r['throughput']:>8.2f} msg/s  ({improvement:>+6.1f}%)")
    
    print("\n" + "="*70)
    print("BURST LOAD SUMMARY")
    print("="*70)
    
    baseline_burst = burst_results[0]['throughput']
    
    for r in burst_results:
        improvement = ((r['throughput'] - baseline_burst) / baseline_burst) * 100
        print(f"{r['name']:<30} {r['throughput']:>8.2f} msg/s  ({improvement:>+6.1f}%)")
    
    # Best results
    best_sustained = max(sustained_results, key=lambda x: x['throughput'])
    improvement_sustained = ((best_sustained['throughput'] - baseline_sustained) / baseline_sustained) * 100
    
    print("\n" + "="*70)
    print("RESEARCH CONCLUSIONS")
    print("="*70)
    print(f"\nUnder sustained high load (10K messages):")
    print(f"  Optimized batching provides {improvement_sustained:+.1f}% improvement")
    print(f"  Baseline: {baseline_sustained:.2f} msgs/sec")
    print(f"  Optimized: {best_sustained['throughput']:.2f} msgs/sec")
    
    if improvement_sustained > 15:
        print("\n  SIGNIFICANT improvement under stress conditions")
    elif improvement_sustained > 5:
        print("\n  MODEST but consistent improvement")
    else:
        print("\n  MINIMAL improvement - may be network/disk bound")

if __name__ == "__main__":
    main()
