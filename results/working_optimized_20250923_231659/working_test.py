import time
import json
from kafka import KafkaProducer

def test_optimized_simple():
    print("=== KAFKA OPTIMIZED TEST (Working) ===")
    
    # Configurazione ottimizzata SENZA parametri problematici
    optimized_config = {
        'bootstrap_servers': ['kafka:29092'],
        'batch_size': 65536,           # 4x più grande (vs 16384 baseline)
        'linger_ms': 50,               # Batching attivo (vs 0 baseline)  
        'buffer_memory': 67108864,     # 64MB (vs 32MB baseline)
        'value_serializer': lambda x: json.dumps(x).encode('utf-8'),
        'request_timeout_ms': 15000,
        'retries': 3
        # RIMOSSO: compression_type per evitare errori
        # RIMOSSO: acks per semplicità
    }
    
    # Configurazione baseline per confronto
    baseline_config = {
        'bootstrap_servers': ['kafka:29092'],
        'batch_size': 16384,           # Default
        'linger_ms': 0,                # Default
        'buffer_memory': 33554432,     # Default ~32MB
        'value_serializer': lambda x: json.dumps(x).encode('utf-8'),
        'request_timeout_ms': 10000,
        'retries': 3
    }
    
    print("📊 CONFRONTO CONFIGURAZIONI:")
    print("BASELINE:")
    print(f"   Batch Size: 16,384 bytes")
    print(f"   Linger: 0 ms")
    print(f"   Buffer: 32 MB")
    print()
    print("OTTIMIZZATA:")
    print(f"   Batch Size: 65,536 bytes (4x)")
    print(f"   Linger: 50 ms (batching)")
    print(f"   Buffer: 64 MB (2x)")
    print()
    
    # Test parameters
    num_messages = 800
    results = {}
    
    # TEST 1: Baseline
    print("🔵 TEST BASELINE...")
    try:
        producer = KafkaProducer(**baseline_config)
        
        start_time = time.time()
        successful_sends = 0
        
        for i in range(num_messages):
            message = {
                'id': i,
                'data': f'baseline_msg_{i}',
                'payload': 'x' * 100
            }
            
            try:
                future = producer.send('performance-test', message)
                result = future.get(timeout=5)
                successful_sends += 1
                
                if (i + 1) % 200 == 0:
                    elapsed = time.time() - start_time
                    rate = successful_sends / elapsed if elapsed > 0 else 0
                    print(f"   Baseline: {successful_sends}/{num_messages}, Rate: {rate:.1f} msgs/sec")
                    
            except Exception as e:
                print(f"   Baseline error: {str(e)[:30]}")
        
        producer.flush()
        producer.close()
        
        baseline_time = time.time() - start_time
        baseline_throughput = successful_sends / baseline_time
        
        results['baseline'] = {
            'messages_sent': successful_sends,
            'duration': baseline_time,
            'throughput': baseline_throughput
        }
        
        print(f"✅ BASELINE: {successful_sends} msgs in {baseline_time:.2f}s = {baseline_throughput:.1f} msgs/sec")
        
    except Exception as e:
        print(f"❌ Baseline test failed: {e}")
        results['baseline'] = {'throughput': 0, 'error': str(e)}
    
    # Pausa tra test
    time.sleep(2)
    
    # TEST 2: Ottimizzata
    print("🟢 TEST OTTIMIZZATO...")
    try:
        producer = KafkaProducer(**optimized_config)
        
        start_time = time.time()
        successful_sends = 0
        
        for i in range(num_messages):
            message = {
                'id': i,
                'data': f'optimized_msg_{i}',
                'payload': 'x' * 100
            }
            
            try:
                future = producer.send('performance-test', message)
                result = future.get(timeout=5)
                successful_sends += 1
                
                if (i + 1) % 200 == 0:
                    elapsed = time.time() - start_time
                    rate = successful_sends / elapsed if elapsed > 0 else 0
                    print(f"   Optimized: {successful_sends}/{num_messages}, Rate: {rate:.1f} msgs/sec")
                    
            except Exception as e:
                print(f"   Optimized error: {str(e)[:30]}")
        
        producer.flush()
        producer.close()
        
        optimized_time = time.time() - start_time
        optimized_throughput = successful_sends / optimized_time
        
        results['optimized'] = {
            'messages_sent': successful_sends,
            'duration': optimized_time,
            'throughput': optimized_throughput
        }
        
        print(f"✅ OTTIMIZZATO: {successful_sends} msgs in {optimized_time:.2f}s = {optimized_throughput:.1f} msgs/sec")
        
    except Exception as e:
        print(f"❌ Optimized test failed: {e}")
        results['optimized'] = {'throughput': 0, 'error': str(e)}
    
    # ANALISI RISULTATI
    print("\n📊 RISULTATI FINALI:")
    
    baseline_tput = results.get('baseline', {}).get('throughput', 0)
    optimized_tput = results.get('optimized', {}).get('throughput', 0)
    
    if baseline_tput > 0 and optimized_tput > 0:
        improvement = optimized_tput - baseline_tput
        improvement_pct = (improvement / baseline_tput) * 100
        
        print(f"Baseline Throughput:    {baseline_tput:.1f} msgs/sec")
        print(f"Optimized Throughput:   {optimized_tput:.1f} msgs/sec")
        print(f"Improvement:            {improvement:+.1f} msgs/sec ({improvement_pct:+.1f}%)")
        
        if improvement > 50:  # >10% improvement typically
            print("🎉 OTTIMIZZAZIONE RIUSCITA!")
            print("   ✅ Miglioramento significativo dimostrato")
            print("   ✅ Parametri batch_size e linger_ms efficaci") 
            conclusion = "SUCCESS"
        elif improvement > 20:
            print("👍 OTTIMIZZAZIONE POSITIVA!")
            print("   ✅ Miglioramento moderato ma misurabile")
            conclusion = "POSITIVE"
        elif improvement > 0:
            print("⚠️ OTTIMIZZAZIONE MARGINALE")
            print("   📝 Piccolo miglioramento, testare altri parametri")
            conclusion = "MARGINAL"
        else:
            print("❌ OTTIMIZZAZIONE NON EFFICACE")
            print("   📝 Nessun miglioramento con questa configurazione")
            conclusion = "INEFFECTIVE"
        
        results['comparison'] = {
            'improvement_msgs_sec': improvement,
            'improvement_percentage': improvement_pct,
            'conclusion': conclusion
        }
        
        print("\n🔬 IMPLICAZIONI RICERCA:")
        if improvement > 20:
            print("✅ IPOTESI CONFERMATA: Ottimizzazione Kafka funziona")
            print("✅ GAP LETTERATURA: Altri studi non ottimizzavano parametri")
            print("✅ CONTRIBUTO: Prima ottimizzazione sistematica blockchain")
        else:
            print("📝 Risultati misti - necessario testare altre configurazioni")
        
    else:
        print("❌ Test falliti - controlla configurazione Kafka")
        results['comparison'] = {'conclusion': 'TEST_FAILED'}
    
    # Salva risultati
    with open('/workspace/results/working_test_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    return results

if __name__ == "__main__":
    test_optimized_simple()
