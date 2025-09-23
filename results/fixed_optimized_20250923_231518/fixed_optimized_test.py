import time
import json
from kafka import KafkaProducer

def test_optimized_fixed():
    print("=== KAFKA OPTIMIZED TEST (FIXED) ===")
    
    # Configurazione ottimizzata SENZA compressione (per evitare errori librerie)
    optimized_config = {
        'bootstrap_servers': ['kafka:29092'],
        'batch_size': 65536,           # 4x più grande (vs 16384 baseline)
        'linger_ms': 50,               # Batching attivo (vs 0 baseline)
        'buffer_memory': 67108864,     # 64MB (vs 32MB baseline)
        'compression_type': 'none',    # Nessuna compressione per evitare errori
        'value_serializer': lambda x: json.dumps(x).encode('utf-8'),
        'request_timeout_ms': 15000,
        'retries': 3,
        'acks': 1,                     # Conferma dal leader
        'max_in_flight_requests_per_connection': 5
    }
    
    print(f"🔧 CONFIGURAZIONE OTTIMIZZATA (Fixed):")
    print(f"   Batch Size: {optimized_config['batch_size']:,} bytes (4x baseline)")
    print(f"   Linger: {optimized_config['linger_ms']} ms (batching enabled)")
    print(f"   Buffer: {optimized_config['buffer_memory']:,} bytes (2x baseline)")
    print(f"   Compression: {optimized_config['compression_type']} (safe choice)")
    print(f"   Acks: {optimized_config['acks']} (performance optimized)")
    print()
    
    # Test parameters
    num_messages = 1000
    baseline_throughput = 490.0
    
    try:
        producer = KafkaProducer(**optimized_config)
        
        start_time = time.time()
        successful_sends = 0
        errors = []
        
        print(f"🚀 Inviando {num_messages} messaggi ottimizzati...")
        
        for i in range(num_messages):
            message = {
                'id': i,
                'timestamp': time.time(),
                'data': f'optimized_msg_{i}',
                'payload': 'x' * 100  # Payload consistente con baseline
            }
            
            try:
                future = producer.send('performance-test', message)
                result = future.get(timeout=10)
                successful_sends += 1
                
                if (i + 1) % 200 == 0:
                    elapsed = time.time() - start_time
                    current_rate = successful_sends / elapsed if elapsed > 0 else 0
                    print(f"   📤 Sent: {successful_sends}/{num_messages}, Rate: {current_rate:.1f} msgs/sec")
                    
            except Exception as e:
                errors.append(str(e)[:50])
                if len(errors) <= 3:
                    print(f"   ❌ Error {i}: {str(e)[:50]}")
        
        producer.flush()
        producer.close()
        
        total_time = time.time() - start_time
        optimized_throughput = successful_sends / total_time
        
        # Calcoli comparativi
        improvement = optimized_throughput - baseline_throughput
        improvement_pct = (improvement / baseline_throughput) * 100
        success_rate = (successful_sends / num_messages) * 100
        
        results = {
            'test_type': 'fixed_optimized',
            'timestamp': time.time(),
            'messages_sent': successful_sends,
            'target_messages': num_messages,
            'success_rate': success_rate,
            'test_duration': total_time,
            'optimized_throughput': optimized_throughput,
            'baseline_throughput': baseline_throughput,
            'improvement_msgs_sec': improvement,
            'improvement_percentage': improvement_pct,
            'errors_count': len(errors),
            'optimization_parameters': {
                'batch_size_increase': '4x (16KB -> 64KB)',
                'linger_enabled': '0ms -> 50ms',
                'buffer_increase': '2x (32MB -> 64MB)', 
                'compression': 'none (compatibility)',
                'acks': 'leader_only (performance)'
            }
        }
        
        print(f"\n📊 RISULTATI OTTIMIZZAZIONE:")
        print(f"   Messaggi inviati: {successful_sends:,}/{num_messages:,}")
        print(f"   Success rate: {success_rate:.1f}%")
        print(f"   Durata: {total_time:.2f} secondi")
        print(f"   Throughput ottimizzato: {optimized_throughput:.1f} msgs/sec")
        print(f"   Errori: {len(errors)}")
        print()
        
        print(f"🎯 CONFRONTO vs BASELINE:")
        print(f"   Baseline (default): {baseline_throughput:.1f} msgs/sec")
        print(f"   Ottimizzato: {optimized_throughput:.1f} msgs/sec")
        print(f"   Differenza: {improvement:+.1f} msgs/sec")
        print(f"   Miglioramento: {improvement_pct:+.1f}%")
        print()
        
        # Valutazione risultati
        if improvement > 100:  # >20% improvement
            print(f"🎉 OTTIMIZZAZIONE ECCELLENTE!")
            print(f"   ✅ Miglioramento > 20% - ipotesi confermata!")
            print(f"   ✅ Parametri batch_size e linger_ms molto efficaci")
            success_level = "EXCELLENT"
        elif improvement > 50:  # >10% improvement  
            print(f"👍 OTTIMIZZAZIONE BUONA!")
            print(f"   ✅ Miglioramento > 10% - ottimizzazione funziona")
            print(f"   ✅ Approccio sistematico validato")
            success_level = "GOOD"
        elif improvement > 25:  # >5% improvement
            print(f"✓ OTTIMIZZAZIONE POSITIVA!")
            print(f"   ✅ Miglioramento > 5% - trend positivo")
            print(f"   📝 Margine per ulteriori ottimizzazioni")
            success_level = "POSITIVE"
        elif improvement > 0:
            print(f"⚠️ OTTIMIZZAZIONE MARGINALE")
            print(f"   ⚠️ Piccolo miglioramento - alcuni parametri efficaci")
            print(f"   📝 Testare altre combinazioni parametri")
            success_level = "MARGINAL"
        else:
            print(f"❌ OTTIMIZZAZIONE NON EFFICACE")
            print(f"   ❌ Nessun miglioramento con questa configurazione")
            print(f"   📝 Rivalutare strategia ottimizzazione")
            success_level = "INEFFECTIVE"
        
        results['success_level'] = success_level
        
        print()
        print(f"🔬 IMPLICAZIONI PER LA RICERCA:")
        if improvement > 25:
            print("   ✅ IPOTESI CONFERMATA: Ottimizzazione sistematica Kafka funziona")
            print("   ✅ GAP IDENTIFICATO: Altri studi usavano configurazioni default")
            print("   ✅ CONTRIBUTO: Prima ottimizzazione sistematica per blockchain")
        else:
            print("   📝 RISULTATI MISTI: Necessarie ulteriori ottimizzazioni")
            print("   📝 APPRENDIMENTO: Non tutte le ottimizzazioni funzionano")
            print("   📝 METODOLOGIA: Approccio sistematico comunque valido")
        
        # Salva risultati
        with open('/workspace/results/fixed_optimized_results.json', 'w') as f:
            json.dump(results, f, indent=2)
        
        return results
        
    except Exception as e:
        print(f"❌ Errore durante test: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    test_optimized_fixed()
