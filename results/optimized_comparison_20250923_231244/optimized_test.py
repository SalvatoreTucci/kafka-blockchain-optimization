import time
import json
from kafka import KafkaProducer

def test_optimized_vs_baseline():
    print("=== KAFKA OPTIMIZED CONFIGURATION TEST ===")
    
    # Configurazione ottimizzata
    optimized_config = {
        'bootstrap_servers': ['kafka:29092'],
        'batch_size': 65536,           # 4x più grande (vs 16384)
        'linger_ms': 50,               # Batching attivo (vs 0)
        'buffer_memory': 67108864,     # 64MB (vs 32MB)
        'compression_type': 'lz4',     # Compressione veloce (vs none)
        'value_serializer': lambda x: json.dumps(x).encode('utf-8'),
        'request_timeout_ms': 15000,
        'retries': 3
    }
    
    print(f"🔧 Configurazione Ottimizzata:")
    print(f"   Batch Size: {optimized_config['batch_size']:,} bytes (4x baseline)")
    print(f"   Linger: {optimized_config['linger_ms']} ms (batching enabled)")
    print(f"   Compression: {optimized_config['compression_type']} (network efficient)")
    print(f"   Buffer: {optimized_config['buffer_memory']:,} bytes (2x baseline)")
    print()
    
    # Test con più messaggi per configuration ottimizzata
    num_messages = 1000
    baseline_throughput = 490.0  # Media baseline
    
    try:
        producer = KafkaProducer(**optimized_config)
        
        start_time = time.time()
        successful_sends = 0
        
        print(f"🚀 Inviando {num_messages} messaggi con configurazione ottimizzata...")
        
        for i in range(num_messages):
            message = {
                'id': i,
                'timestamp': time.time(),
                'data': f'optimized_msg_{i}',
                'payload': 'x' * 120  # Payload leggermente più grande
            }
            
            try:
                future = producer.send('performance-test', message)
                result = future.get(timeout=10)
                successful_sends += 1
                
                if (i + 1) % 250 == 0:
                    elapsed = time.time() - start_time
                    current_rate = successful_sends / elapsed
                    print(f"   📤 Progress: {successful_sends}/{num_messages}, Current Rate: {current_rate:.1f} msgs/sec")
                    
            except Exception as e:
                print(f"   ❌ Error: {str(e)[:50]}")
        
        producer.flush()
        producer.close()
        
        total_time = time.time() - start_time
        optimized_throughput = successful_sends / total_time
        
        # Calcola miglioramento
        improvement = optimized_throughput - baseline_throughput
        improvement_pct = (improvement / baseline_throughput) * 100
        
        results = {
            'test_type': 'optimized_vs_baseline',
            'timestamp': time.time(),
            'messages_sent': successful_sends,
            'total_messages': num_messages,
            'success_rate': (successful_sends / num_messages) * 100,
            'test_duration': total_time,
            'optimized_throughput': optimized_throughput,
            'baseline_throughput': baseline_throughput,
            'improvement_msgs_sec': improvement,
            'improvement_percentage': improvement_pct,
            'configuration': 'high_throughput_optimized'
        }
        
        print(f"\n📊 RISULTATI FINALI:")
        print(f"   Messaggi inviati: {successful_sends:,}/{num_messages:,}")
        print(f"   Success rate: {results['success_rate']:.1f}%")
        print(f"   Durata test: {total_time:.2f} secondi")
        print(f"   Throughput ottimizzato: {optimized_throughput:.1f} msgs/sec")
        print()
        print(f"🎯 CONFRONTO PRESTAZIONI:")
        print(f"   Baseline media: {baseline_throughput:.1f} msgs/sec")
        print(f"   Ottimizzato: {optimized_throughput:.1f} msgs/sec")
        
        if improvement > 0:
            print(f"   ✅ MIGLIORAMENTO: +{improvement:.1f} msgs/sec (+{improvement_pct:.1f}%)")
            if improvement_pct > 20:
                print(f"   🎉 OTTIMIZZAZIONE ECCELLENTE! Miglioramento > 20%")
            elif improvement_pct > 10:
                print(f"   👍 OTTIMIZZAZIONE BUONA! Miglioramento > 10%")
            else:
                print(f"   ✓ OTTIMIZZAZIONE MODESTA ma positiva")
        else:
            print(f"   ❌ PEGGIORAMENTO: {improvement:.1f} msgs/sec ({improvement_pct:.1f}%)")
        
        print()
        print(f"🔬 ANALISI SCIENTIFICA:")
        if improvement > 50:  # >10% improvement
            print("   ✅ L'ottimizzazione sistematica di Kafka FUNZIONA")
            print("   ✅ Ipotesi confermata: Kafka ottimizzato > Kafka default")
            print("   ✅ Parametri chiave: batch size, linger, compression efficaci")
        elif improvement > 0:
            print("   ⚠️  Miglioramento marginale - alcuni parametri efficaci")
            print("   📝 Suggerimento: testare altre combinazioni parametri")
        else:
            print("   ❌ Questa combinazione non ha migliorato le performance")
            print("   📝 Necessario testare configurazioni alternative")
        
        # Salva risultati
        with open('/workspace/results/optimized_comparison.json', 'w') as f:
            json.dump(results, f, indent=2)
        
        return results
        
    except Exception as e:
        print(f"❌ Errore test ottimizzato: {e}")
        return None

if __name__ == "__main__":
    test_optimized_vs_baseline()
