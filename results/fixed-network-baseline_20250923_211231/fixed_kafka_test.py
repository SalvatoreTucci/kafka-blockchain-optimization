import time
import json
import sys
from kafka import KafkaProducer, KafkaConsumer
from kafka.errors import KafkaError

def test_connectivity():
    """Test connettività con diversi hostname"""
    print("🔍 Testando connettività Kafka...")
    
    # Prova diversi server
    servers_to_try = [
        ['kafka:9092'],           # Hostname interno container
        ['kafka:29092'],          # Porta interna
        ['localhost:9092'],       # Localhost (probabilmente fallisce in container)
    ]
    
    for servers in servers_to_try:
        print(f"   Provando server: {servers}")
        try:
            producer = KafkaProducer(
                bootstrap_servers=servers,
                value_serializer=lambda x: json.dumps(x).encode('utf-8'),
                request_timeout_ms=5000,
                retries=1
            )
            
            # Test rapido
            future = producer.send('test-connectivity', {'test': 'connection'})
            result = future.get(timeout=5)
            producer.close()
            
            print(f"   ✅ Connessione riuscita con: {servers}")
            return servers[0]
            
        except Exception as e:
            print(f"   ❌ Errore con {servers}: {str(e)[:100]}")
    
    print("   ❌ Nessun server raggiungibile")
    return None

def run_performance_test(kafka_server):
    """Esegue test performance con server corretto"""
    print(f"\n🚀 Test performance usando server: {kafka_server}")
    
    # Configurazione corretta
    producer_config = {
        'bootstrap_servers': [kafka_server],
        'batch_size': 16384,
        'linger_ms': 0,
        'buffer_memory': 33554432,
        'value_serializer': lambda x: json.dumps(x).encode('utf-8'),
        'request_timeout_ms': 10000,
        'retries': 3
    }
    
    try:
        producer = KafkaProducer(**producer_config)
        
        # Test parametri
        num_messages = 500  # Ridotto per test veloce
        start_time = time.time()
        successful_sends = 0
        errors = []
        
        print(f"📤 Inviando {num_messages} messaggi...")
        
        for i in range(num_messages):
            message = {
                'id': i,
                'timestamp': time.time(),
                'data': f'test_message_{i}',
                'payload': 'x' * 100  # 100 byte payload
            }
            
            try:
                future = producer.send('performance-test', message)
                result = future.get(timeout=5)
                successful_sends += 1
                
                if (i + 1) % 100 == 0:
                    elapsed = time.time() - start_time
                    rate = successful_sends / elapsed if elapsed > 0 else 0
                    print(f"   Sent: {successful_sends}/{num_messages}, Rate: {rate:.1f} msgs/sec")
                    
            except Exception as e:
                errors.append(str(e)[:50])
                if len(errors) <= 5:  # Mostra solo primi 5 errori
                    print(f"   ❌ Errore msg {i}: {str(e)[:50]}")
        
        producer.flush()
        producer.close()
        
        total_time = time.time() - start_time
        
        # Risultati
        results = {
            'kafka_server': kafka_server,
            'total_messages_sent': successful_sends,
            'target_messages': num_messages,
            'success_rate': (successful_sends / num_messages) * 100 if num_messages > 0 else 0,
            'total_time': total_time,
            'avg_throughput': successful_sends / total_time if total_time > 0 else 0,
            'errors_count': len(errors),
            'config': {
                'batch_size': 16384,
                'linger_ms': 0,
                'compression': 'none',
                'buffer_memory': 33554432
            }
        }
        
        print(f"\n📊 RISULTATI TEST:")
        print(f"   Server usato: {kafka_server}")
        print(f"   Messaggi inviati: {successful_sends}/{num_messages}")
        print(f"   Tasso successo: {results['success_rate']:.1f}%")
        print(f"   Tempo totale: {total_time:.2f} secondi")
        print(f"   Throughput medio: {results['avg_throughput']:.1f} msgs/sec")
        print(f"   Errori: {len(errors)}")
        
        # Salva risultati
        with open('/workspace/results/performance_results.json', 'w') as f:
            json.dump(results, f, indent=2)
        
        return results
        
    except Exception as e:
        print(f"❌ Errore setup producer: {e}")
        return None

def main():
    print("=== KAFKA NETWORK FIX TEST ===")
    
    # Test connettività
    working_server = test_connectivity()
    if not working_server:
        print("❌ Impossibile connettersi a Kafka")
        return
    
    # Test performance
    results = run_performance_test(working_server)
    if results:
        print(f"\n✅ Test completato!")
        print(f"🎯 Baseline throughput: {results['avg_throughput']:.1f} msgs/sec")
        print(f"📊 Success rate: {results['success_rate']:.1f}%")
    else:
        print("\n❌ Test fallito")

if __name__ == "__main__":
    main()
