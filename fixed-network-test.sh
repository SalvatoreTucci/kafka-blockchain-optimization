#!/bin/bash

# Test con configurazione networking corretta per container

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TEST_NAME="fixed-network-baseline"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="results/${TEST_NAME}_${TIMESTAMP}"

log_info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')]${NC} $1"
}

# Crea directory risultati
mkdir -p "$RESULTS_DIR"

log_info "=== TEST CON NETWORK FIX ==="
log_info "Directory risultati: $RESULTS_DIR"

# 1. Diagnosi rete
log_info "Diagnosticando problemi di rete..."

# Verifica che i container siano sulla stessa rete
log_info "Container network status:"
docker-compose ps

# Test connettività da test-runner a kafka
log_info "Test connettività interna..."
if docker-compose exec -T test-runner ping -c 2 kafka &>/dev/null; then
    log_success "✅ Ping a Kafka funziona"
else
    log_error "❌ Ping a Kafka fallisce"
fi

# Test porta Kafka da interno container
if docker-compose exec -T test-runner nc -zv kafka 9092 &>/dev/null; then
    log_success "✅ Porta Kafka 9092 raggiungibile da container"
else
    log_error "❌ Porta Kafka 9092 NON raggiungibile da container"
fi

# 2. Test Python corretto con hostname interno
log_info "Creando test Python con hostname corretto..."

cat > "$RESULTS_DIR/fixed_kafka_test.py" << 'PYTHON_EOF'
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
PYTHON_EOF

# 3. Esegui test corretto nel container
log_info "Eseguendo test con network fix..."
docker-compose exec -T test-runner python3 "$RESULTS_DIR/fixed_kafka_test.py" 2>&1 | tee "$RESULTS_DIR/test_output.log"

# 4. Copia risultati se generati
if docker-compose exec -T test-runner test -f /workspace/results/performance_results.json; then
    docker-compose exec -T test-runner cp /workspace/results/performance_results.json /workspace/ 2>/dev/null || true
    if [[ -f "performance_results.json" ]]; then
        mv performance_results.json "$RESULTS_DIR/"
        log_success "✅ Risultati performance recuperati"
    fi
fi

# 5. Genera summary dai risultati
if [[ -f "$RESULTS_DIR/performance_results.json" ]]; then
    log_info "Generando summary dai risultati..."
    
    python3 << SUMMARY_EOF > "$RESULTS_DIR/summary.txt"
import json
import sys

try:
    with open('$RESULTS_DIR/performance_results.json', 'r') as f:
        results = json.load(f)
    
    print("=== KAFKA NETWORK FIX TEST SUMMARY ===")
    print(f"Date: $(date)")
    print(f"Test Name: $TEST_NAME")
    print(f"Kafka Server: {results['kafka_server']}")
    print("")
    print("PERFORMANCE RESULTS:")
    print(f"  Messages Sent: {results['total_messages_sent']:,}/{results['target_messages']:,}")
    print(f"  Success Rate: {results['success_rate']:.1f}%")
    print(f"  Duration: {results['total_time']:.2f} seconds")
    print(f"  Throughput: {results['avg_throughput']:.1f} msgs/sec")
    print(f"  Errors: {results['errors_count']}")
    print("")
    print("BASELINE CONFIGURATION:")
    print(f"  - Batch Size: {results['config']['batch_size']:,} bytes")
    print(f"  - Linger Time: {results['config']['linger_ms']} ms")
    print(f"  - Compression: {results['config']['compression']}")
    print(f"  - Buffer Memory: {results['config']['buffer_memory']:,} bytes")
    print("")
    print("BASELINE PERFORMANCE EVALUATION:")
    if results['avg_throughput'] > 100:
        print("  ✅ Good baseline throughput achieved")
    else:
        print("  ⚠️  Low baseline throughput - check for issues")
    
    if results['success_rate'] > 95:
        print("  ✅ Excellent success rate")
    elif results['success_rate'] > 80:
        print("  ⚠️  Acceptable success rate")
    else:
        print("  ❌ Poor success rate - check configuration")
    
    print("")
    print("OPTIMIZATION OPPORTUNITIES:")
    print("  1. Increase batch_size (32KB-64KB) for higher throughput")
    print("  2. Add linger_ms (5-50ms) for better batching efficiency")
    print("  3. Enable compression (lz4/snappy) for network optimization")
    print("  4. Tune buffer_memory based on expected load")

except Exception as e:
    print(f"Error generating summary: {e}")
    print("Test results incomplete - check logs for errors")
SUMMARY_EOF
    
else
    echo "Test results incomplete - check logs for errors" > "$RESULTS_DIR/summary.txt"
fi

# 6. Salva metriche sistema
docker stats --no-stream > "$RESULTS_DIR/docker_stats.txt" 2>/dev/null || true
docker-compose logs kafka > "$RESULTS_DIR/kafka.log" 2>/dev/null || true

# 7. Mostra risultati
echo ""
echo "=== FILE GENERATI ==="
ls -la "$RESULTS_DIR"

echo ""
echo "=== SUMMARY ==="
cat "$RESULTS_DIR/summary.txt"

log_success "Test network fix completato!"
log_info "Risultati salvati in: $RESULTS_DIR"

# 8. Se il test ha funzionato, suggerisci prossimi passi
if [[ -f "$RESULTS_DIR/performance_results.json" ]]; then
    echo ""
    log_success "🎯 BASELINE STABILITO!"
    echo ""
    echo "Prossimi passi per la ricerca:"
    echo "1. Confronta con configurazioni ottimizzate"
    echo "2. Esegui test con diverse configurazioni"
    echo "3. Analizza miglioramenti delle performance"
else
    log_error "Test non completato - controlla logs per debug"
fi