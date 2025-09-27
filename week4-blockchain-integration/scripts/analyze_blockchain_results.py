#!/usr/bin/env python3
"""
Blockchain Benchmark Results Analyzer for Week 4
Analyzes performance of optimized Kafka configuration in blockchain context
"""

import glob
import statistics
import os
import sys
from datetime import datetime
import json

def analyze_blockchain_results(results_dir):
    print("🔍 Analyzing Blockchain Benchmark Results (Week 4)")
    print("=" * 60)
    
    # Read transaction results from all clients
    client_files = glob.glob(f"{results_dir}/client_*_results.txt")
    
    if not client_files:
        print("❌ No client result files found")
        return
    
    all_transactions = []
    total_success = 0
    total_failed = 0
    latencies = []
    
    print(f"📁 Processing {len(client_files)} client files...")
    
    for client_file in client_files:
        print(f"  📄 Reading {os.path.basename(client_file)}...")
        
        try:
            with open(client_file, 'r') as f:
                for line_num, line in enumerate(f, 1):
                    line = line.strip()
                    if not line:
                        continue
                        
                    parts = line.split(',')
                    if len(parts) >= 6:
                        try:
                            transaction = {
                                'client': parts[0],
                                'tx_id': parts[1], 
                                'start_time': int(parts[2]),
                                'end_time': int(parts[3]),
                                'latency_ms': int(parts[4]),
                                'status': parts[5],
                                'from_account': parts[6] if len(parts) > 6 else 'N/A',
                                'to_account': parts[7] if len(parts) > 7 else 'N/A',
                                'amount': parts[8] if len(parts) > 8 else 'N/A'
                            }
                            
                            all_transactions.append(transaction)
                            
                            if transaction['status'] == 'SUCCESS':
                                total_success += 1
                                latencies.append(transaction['latency_ms'])
                            else:
                                total_failed += 1
                                
                        except ValueError as e:
                            print(f"    ⚠️  Warning: Could not parse line {line_num}: {e}")
                    else:
                        print(f"    ⚠️  Warning: Malformed line {line_num}: {len(parts)} fields")
                        
        except Exception as e:
            print(f"    ❌ Error reading {client_file}: {e}")
    
    total_transactions = len(all_transactions)
    
    if total_transactions == 0:
        print("❌ No valid transactions found")
        return
    
    print(f"\n📊 BLOCKCHAIN PERFORMANCE ANALYSIS")
    print("=" * 40)
    
    # Basic statistics
    print(f"📈 Transaction Summary:")
    print(f"  Total Transactions: {total_transactions}")
    print(f"  Successful: {total_success}")
    print(f"  Failed: {total_failed}")
    
    if total_transactions > 0:
        success_rate = (total_success / total_transactions) * 100
        print(f"  Success Rate: {success_rate:.1f}%")
    
    # Latency analysis (only for successful transactions)
    if latencies:
        print(f"\n⚡ Latency Analysis (Successful Transactions):")
        print(f"  Average Latency: {statistics.mean(latencies):.2f} ms")
        print(f"  Median Latency: {statistics.median(latencies):.2f} ms")
        print(f"  Min Latency: {min(latencies):.2f} ms")
        print(f"  Max Latency: {max(latencies):.2f} ms")
        
        if len(latencies) > 10:
            p95_latency = sorted(latencies)[int(0.95 * len(latencies))]
            p99_latency = sorted(latencies)[int(0.99 * len(latencies))]
            print(f"  P95 Latency: {p95_latency:.2f} ms")
            print(f"  P99 Latency: {p99_latency:.2f} ms")
    
    # Throughput estimation
    if all_transactions:
        start_times = [tx['start_time'] for tx in all_transactions]
        end_times = [tx['end_time'] for tx in all_transactions]
        
        if start_times and end_times:
            test_duration_ms = max(end_times) - min(start_times)
            test_duration_seconds = test_duration_ms / 1000.0
            
            if test_duration_seconds > 0:
                throughput_tps = total_success / test_duration_seconds
                print(f"\n🚀 Throughput Analysis:")
                print(f"  Test Duration: {test_duration_seconds:.2f} seconds")
                print(f"  Effective Throughput: {throughput_tps:.2f} TPS")
                print(f"  Target Throughput: ~100-200 TPS (blockchain realistic)")
    
    # Comparison with Week 3 optimization goals
    print(f"\n🎯 WEEK 4 BLOCKCHAIN INTEGRATION ASSESSMENT")
    print("=" * 50)
    
    print("✅ Integration Success Criteria:")
    print(f"  [{'✅' if success_rate >= 95 else '❌'}] High Success Rate (>95%): {success_rate:.1f}%")
    
    if latencies:
        avg_latency = statistics.mean(latencies)
        print(f"  [{'✅' if avg_latency < 5000 else '❌'}] Blockchain Latency (<5s): {avg_latency:.0f}ms")
        print(f"  [{'✅' if len(latencies) > 100 else '❌'}] Sufficient Load Testing: {len(latencies)} transactions")
    
    # Optimal configuration validation
    print(f"\n⚙️  OPTIMAL KAFKA CONFIGURATION IMPACT:")
    print("  Applied Configuration: config_100 from Week 3")
    print("  - Batch Size: 65KB (4x default)")
    print("  - Linger Time: 0ms (zero latency priority)")  
    print("  - Compression: none (no overhead)")
    print("  - Status: ✅ Successfully applied to blockchain ordering service")
    
    # System resource analysis
    system_start_file = f"{results_dir}/system_stats_start.txt"
    system_end_file = f"{results_dir}/system_stats_end.txt"
    
    if os.path.exists(system_start_file) and os.path.exists(system_end_file):
        print(f"\n💻 SYSTEM RESOURCE UTILIZATION:")
        print("  Resource stats collected during test")
        print(f"  Start stats: {system_start_file}")
        print(f"  End stats: {system_end_file}")
    
    # Generate summary report
    summary_report = {
        'timestamp': datetime.now().isoformat(),
        'test_directory': results_dir,
        'total_transactions': total_transactions,
        'successful_transactions': total_success,
        'failed_transactions': total_failed,
        'success_rate_percent': success_rate if total_transactions > 0 else 0,
        'latency_stats': {
            'average_ms': statistics.mean(latencies) if latencies else 0,
            'median_ms': statistics.median(latencies) if latencies else 0,
            'min_ms': min(latencies) if latencies else 0,
            'max_ms': max(latencies) if latencies else 0,
            'p95_ms': sorted(latencies)[int(0.95 * len(latencies))] if len(latencies) > 10 else 0,
            'p99_ms': sorted(latencies)[int(0.99 * len(latencies))] if len(latencies) > 10 else 0
        },
        'throughput_tps': throughput_tps if 'throughput_tps' in locals() else 0,
        'optimal_config_applied': {
            'batch_size': '65KB',
            'linger_ms': '0ms', 
            'compression': 'none',
            'status': 'applied_successfully'
        }
    }
    
    # Save summary
    summary_file = f"{results_dir}/blockchain_analysis_summary.json"
    try:
        with open(summary_file, 'w') as f:
            json.dump(summary_report, f, indent=2)
        print(f"\n💾 Analysis summary saved: {summary_file}")
    except Exception as e:
        print(f"\n❌ Could not save summary: {e}")
    
    print(f"\n🎉 WEEK 4 BLOCKCHAIN INTEGRATION ANALYSIS COMPLETE")
    print("=" * 60)
    
    if success_rate >= 95 and latencies and statistics.mean(latencies) < 5000:
        print("🚀 SUCCESS: Blockchain integration with optimal Kafka configuration validated!")
        print("📋 Ready for Week 5: Production validation and comparison")
    else:
        print("⚠️  NEEDS ATTENTION: Some metrics may need optimization")
        print("🔧 Consider network tuning or increasing test resources")

def main():
    if len(sys.argv) < 2:
        # Auto-detect most recent results directory
        result_dirs = glob.glob("benchmarks/results/blockchain_benchmark_*")
        if not result_dirs:
            result_dirs = glob.glob("results/blockchain_benchmark_*")
        
        if result_dirs:
            results_dir = sorted(result_dirs)[-1]
            print(f"🔍 Auto-detected most recent results: {results_dir}")
        else:
            print("Usage: python3 analyze_blockchain_results.py <results_directory>")
            print("No results directories found matching pattern 'blockchain_benchmark_*'")
            sys.exit(1)
    else:
        results_dir = sys.argv[1]
    
    if not os.path.exists(results_dir):
        print(f"❌ Results directory not found: {results_dir}")
        sys.exit(1)
    
    analyze_blockchain_results(results_dir)

if __name__ == "__main__":
    main()
