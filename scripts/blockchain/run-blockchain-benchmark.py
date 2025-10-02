#!/usr/bin/env python3
"""
Complete Blockchain Benchmark Suite
Tests Kafka ordering service performance in blockchain context
"""

import time
import json
import statistics
import sys
import os
from concurrent.futures import ThreadPoolExecutor, as_completed

# Import blockchain simulator
sys.path.insert(0, os.path.dirname(__file__))
from blockchain_simulator import (
    OrderingService, BlockchainPeer, create_sample_transaction,
    Transaction
)

class BlockchainBenchmark:
    """Comprehensive blockchain benchmark"""
    
    def __init__(self, config_name='baseline', batch_size=16384, 
                 linger_ms=0, compression_type=None):
        self.config_name = config_name
        self.batch_size = batch_size
        self.linger_ms = linger_ms
        self.compression_type = compression_type
        
        self.ordering_service = OrderingService(
            bootstrap_servers='kafka:29092',
            batch_size=batch_size,
            linger_ms=linger_ms,
            compression_type=compression_type
        )
        
        self.results = {
            'config_name': config_name,
            'config': {
                'batch_size': batch_size,
                'linger_ms': linger_ms,
                'compression_type': compression_type or 'none'
            },
            'test_timestamp': time.time(),
            'metrics': {}
        }
    
    def test_transaction_submission(self, num_transactions=5000):
        """Test 1: Transaction submission through ordering service"""
        print(f"\n{'='*70}")
        print(f"TEST 1: Transaction Submission ({num_transactions} transactions)")
        print(f"{'='*70}")
        
        self.ordering_service.connect_producer()
        
        futures = []
        submission_times = []
        
        print("Submitting transactions...")
        start_time = time.time()
        
        for i in range(num_transactions):
            tx = create_sample_transaction(i)
            
            submit_start = time.time()
            future = self.ordering_service.submit_transaction(tx)
            futures.append((future, submit_start))
            
            if (i + 1) % 1000 == 0:
                print(f"  Submitted {i+1}/{num_transactions}")
        
        # Wait for all confirmations
        print("Waiting for Kafka confirmations...")
        confirmed = 0
        for future, submit_start in futures:
            try:
                future.get(timeout=30)
                submission_times.append((time.time() - submit_start) * 1000)
                confirmed += 1
            except Exception as e:
                pass
        
        end_time = time.time()
        duration = end_time - start_time
        
        # Calculate metrics
        throughput = confirmed / duration
        avg_submission_time = statistics.mean(submission_times) if submission_times else 0
        p95_submission_time = statistics.quantiles(submission_times, n=20)[18] if len(submission_times) > 20 else 0
        
        self.results['metrics']['transaction_submission'] = {
            'total_transactions': num_transactions,
            'confirmed_transactions': confirmed,
            'duration_seconds': duration,
            'throughput_tps': throughput,
            'avg_submission_time_ms': avg_submission_time,
            'p95_submission_time_ms': p95_submission_time
        }
        
        print(f"\nResults:")
        print(f"  Throughput: {throughput:.2f} TPS")
        print(f"  Avg Submission Time: {avg_submission_time:.2f} ms")
        print(f"  P95 Submission Time: {p95_submission_time:.2f} ms")
        
        return confirmed
    
    def test_block_formation(self, expected_transactions=5000, 
                            block_size=100, block_timeout=3.0,
                            num_peers=1):
        """Test 2: Block formation and consensus"""
        print(f"\n{'='*70}")
        print(f"TEST 2: Block Formation ({num_peers} peer(s))")
        print(f"{'='*70}")
        
        peers = []
        for i in range(num_peers):
            peer = BlockchainPeer(
                peer_id=f"peer{i}",
                ordering_service=self.ordering_service,
                block_size=block_size,
                block_timeout=block_timeout
            )
            peers.append(peer)
        
        print(f"Processing transactions with {num_peers} peer(s)...")
        start_time = time.time()
        
        # Process transactions
        def process_peer(peer):
            peer.process_ordered_transactions(max_messages=expected_transactions)
            return peer.get_metrics()
        
        if num_peers == 1:
            # Single peer
            peers[0].process_ordered_transactions(max_messages=expected_transactions)
            peer_metrics = [peers[0].get_metrics()]
        else:
            # Multiple peers concurrently
            with ThreadPoolExecutor(max_workers=num_peers) as executor:
                future_to_peer = {executor.submit(process_peer, peer): peer 
                                for peer in peers}
                peer_metrics = []
                for future in as_completed(future_to_peer):
                    peer_metrics.append(future.result())
        
        end_time = time.time()
        duration = end_time - start_time
        
        # Aggregate metrics
        total_blocks = sum(m['blocks_created'] for m in peer_metrics)
        total_txs = sum(m['transactions_processed'] for m in peer_metrics)
        avg_block_time = statistics.mean([m['avg_block_formation_time_ms'] 
                                          for m in peer_metrics])
        
        # Calculate transaction finality time
        # (time from submission to being in committed block)
        tx_finality_time = duration / (total_blocks if total_blocks > 0 else 1)
        
        self.results['metrics']['block_formation'] = {
            'num_peers': num_peers,
            'total_blocks_created': total_blocks,
            'total_transactions_processed': total_txs,
            'duration_seconds': duration,
            'avg_block_formation_time_ms': avg_block_time,
            'avg_tx_finality_time_seconds': tx_finality_time,
            'blocks_per_second': total_blocks / duration,
            'peer_metrics': peer_metrics
        }
        
        print(f"\nResults:")
        print(f"  Blocks Created: {total_blocks}")
        print(f"  Transactions Processed: {total_txs}")
        print(f"  Avg Block Formation Time: {avg_block_time:.2f} ms")
        print(f"  Avg Transaction Finality: {tx_finality_time:.2f} seconds")
        print(f"  Blocks/Second: {total_blocks/duration:.2f}")
        
        return total_blocks
    
    def test_end_to_end_latency(self, num_samples=100):
        """Test 3: End-to-end transaction latency"""
        print(f"\n{'='*70}")
        print(f"TEST 3: End-to-End Latency ({num_samples} samples)")
        print(f"{'='*70}")
        
        self.ordering_service.connect_producer()
        peer = BlockchainPeer(
            peer_id="latency_peer",
            ordering_service=self.ordering_service,
            block_size=10,  # Small blocks for quick finality
            block_timeout=1.0
        )
        
        # Start peer in background
        import threading
        peer_thread = threading.Thread(
            target=peer.process_ordered_transactions,
            kwargs={'max_messages': num_samples}
        )
        peer_thread.daemon = True
        peer_thread.start()
        
        # Submit transactions and measure end-to-end time
        e2e_latencies = []
        
        print("Measuring end-to-end latency...")
        for i in range(num_samples):
            tx = create_sample_transaction(i)
            tx_start = time.time()
            
            # Submit transaction
            future = self.ordering_service.submit_transaction(tx)
            future.get(timeout=10)
            
            # Wait a bit for block formation
            time.sleep(0.1)
            
            # Check if transaction is in a block
            # (simplified: assume it's in a block after confirmation)
            tx_end = time.time()
            e2e_latencies.append((tx_end - tx_start) * 1000)
            
            if (i + 1) % 20 == 0:
                print(f"  Measured {i+1}/{num_samples} samples")
        
        peer_thread.join(timeout=10)
        
        # Calculate metrics
        avg_e2e = statistics.mean(e2e_latencies)
        p50_e2e = statistics.median(e2e_latencies)
        p95_e2e = statistics.quantiles(e2e_latencies, n=20)[18] if len(e2e_latencies) > 20 else 0
        p99_e2e = statistics.quantiles(e2e_latencies, n=100)[98] if len(e2e_latencies) > 100 else 0
        
        self.results['metrics']['end_to_end_latency'] = {
            'num_samples': num_samples,
            'avg_latency_ms': avg_e2e,
            'p50_latency_ms': p50_e2e,
            'p95_latency_ms': p95_e2e,
            'p99_latency_ms': p99_e2e,
            'min_latency_ms': min(e2e_latencies),
            'max_latency_ms': max(e2e_latencies)
        }
        
        print(f"\nResults:")
        print(f"  Avg E2E Latency: {avg_e2e:.2f} ms")
        print(f"  P50 Latency: {p50_e2e:.2f} ms")
        print(f"  P95 Latency: {p95_e2e:.2f} ms")
        print(f"  P99 Latency: {p99_e2e:.2f} ms")
    
    def run_complete_benchmark(self, num_transactions=5000):
        """Run all benchmark tests"""
        print(f"\n{'='*70}")
        print(f"BLOCKCHAIN BENCHMARK: {self.config_name.upper()}")
        print(f"{'='*70}")
        print(f"Configuration:")
        print(f"  Batch Size: {self.batch_size}")
        print(f"  Linger MS: {self.linger_ms}")
        print(f"  Compression: {self.compression_type or 'none'}")
        print(f"  Transactions: {num_transactions}")
        
        try:
            # Test 1: Transaction submission
            confirmed = self.test_transaction_submission(num_transactions)
            
            time.sleep(2)
            
            # Test 2: Block formation
            self.test_block_formation(
                expected_transactions=confirmed,
                block_size=100,
                num_peers=1
            )
            
            time.sleep(2)
            
            # Test 3: End-to-end latency (smaller sample)
            self.test_end_to_end_latency(num_samples=100)
            
        finally:
            self.ordering_service.close()
        
        # Save results
        self.save_results()
        
        print(f"\n{'='*70}")
        print("BENCHMARK COMPLETE")
        print(f"{'='*70}")
        
        return self.results
    
    def save_results(self):
        """Save benchmark results to file"""
        filename = f"/results/blockchain_{self.config_name}_{int(time.time())}.json"
        
        try:
            with open(filename, 'w') as f:
                json.dump(self.results, f, indent=2)
            print(f"\nResults saved: {filename}")
        except Exception as e:
            print(f"Failed to save results: {e}")
            print(json.dumps(self.results, indent=2))

def main():
    """Run benchmark with configuration from command line"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Blockchain Benchmark Suite')
    parser.add_argument('--config', default='baseline', help='Configuration name')
    parser.add_argument('--batch-size', type=int, default=16384, help='Kafka batch size')
    parser.add_argument('--linger-ms', type=int, default=0, help='Kafka linger ms')
    parser.add_argument('--compression', default=None, help='Compression type')
    parser.add_argument('--transactions', type=int, default=5000, help='Number of transactions')
    
    args = parser.parse_args()
    
    benchmark = BlockchainBenchmark(
        config_name=args.config,
        batch_size=args.batch_size,
        linger_ms=args.linger_ms,
        compression_type=args.compression
    )
    
    benchmark.run_complete_benchmark(num_transactions=args.transactions)

if __name__ == "__main__":
    main()
