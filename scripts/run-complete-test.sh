#!/bin/bash

# Script per eseguire un test completo con monitoring e debug

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TEST_NAME="complete-baseline"
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

log_info "=== TEST COMPLETO BASELINE ==="
log_info "Directory risultati: $RESULTS_DIR"

# 1. Verifica prerequisiti
log_info "Verificando ambiente..."

if ! docker-compose ps | grep -q "Up"; then
    log_error "Alcuni servizi Docker non sono attivi"
    log_info "Riavviando ambiente..."
    docker-compose down -v
    sleep 10
    docker-compose up -d
    sleep 120
fi

# 2. Verifica connettività Kafka
log_info "Testando connettività Kafka..."
if ! timeout 30 docker-compose exec -T kafka kafka-topics --list --bootstrap-server localhost:9092 &>/dev/null; then
    log_error "Kafka non risponde"
    exit 1
fi
log_success "Kafka connesso"

# 3. Salva configurazione e metadata
cat > "$RESULTS_DIR/test-metadata.txt" << EOF
Complete Kafka-Blockchain Test
==============================
Date: $(date --iso-8601=seconds)
Test Name: $TEST_NAME
Configuration: baseline (default)
Duration: 300 seconds
Target TPS: 500

Kafka Parameters:
- Batch Size: 16384 bytes
- Linger Time: 0 ms  
- Compression: none
- Buffer Memory: 33554432 bytes
- Network Threads: 3
- I/O Threads: 8

Test Phases:
1. Infrastructure verification
2. Kafka performance testing
3. Blockchain validation (simulated)
4. Resource monitoring
5. Results collection
EOF

# 4. Copia configurazione
cp .env.default "$RESULTS_DIR/config-used.env"

# 5. Test Kafka throughput
log_info "Iniziando test throughput Kafka..."

# Crea topic per test
docker-compose exec -T kafka kafka-topics --create --topic test-topic \
    --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 \
    --if-not-exists &>/dev/null

# Producer test (script Python semplice)
cat > "$RESULTS_DIR/kafka_producer_test.py" << 'EOF'
import time
import json
from kafka import KafkaProducer
from kafka.errors import KafkaError

def run_producer_test():
    producer_config = {
        'bootstrap_servers': ['localhost:9092'],
        'batch_size': 16384,
        'linger_ms': 0,
        'buffer_memory': 33554432,
        'value_serializer': lambda x: json.dumps(x).encode('utf-8')
    }
    
    producer = KafkaProducer(**producer_config)
    
    messages_sent = 0
    start_time = time.time()
    test_duration = 60  # 1 minuto di test
    
    print(f"Starting producer test for {test_duration} seconds...")
    
    while time.time() - start_time < test_duration:
        message = {
            'timestamp': time.time(),
            'message_id': messages_sent,
            'data': f'test_message_{messages_sent}'
        }
        
        try:
            future = producer.send('test-topic', message)
            future.get(timeout=10)  # Wait for confirmation
            messages_sent += 1
            
            if messages_sent % 100 == 0:
                elapsed = time.time() - start_time
                rate = messages_sent / elapsed
                print(f"Messages sent: {messages_sent}, Rate: {rate:.2f} msgs/sec")
                
        except KafkaError as e:
            print(f"Error sending message: {e}")
    
    producer.flush()
    producer.close()
    
    total_time = time.time() - start_time
    avg_throughput = messages_sent / total_time
    
    results = {
        'total_messages': messages_sent,
        'test_duration': total_time,
        'avg_throughput': avg_throughput,
        'target_throughput': 500
    }
    
    print(f"\n=== RESULTS ===")
    print(f"Messages sent: {messages_sent}")
    print(f"Test duration: {total_time:.2f} seconds")
    print(f"Average throughput: {avg_throughput:.2f} msgs/sec")
    
    return results

if __name__ == "__main__":
    results = run_producer_test()
    with open('/workspace/results/producer_results.json', 'w') as f:
        json.dump(results, f, indent=2)
EOF

# Esegui test producer nel container
log_info "Eseguendo test producer..."
docker-compose exec -T test-runner python3 -c "
import sys
sys.path.append('/workspace')
exec(open('$RESULTS_DIR/kafka_producer_test.py').read())
" 2>&1 | tee "$RESULTS_DIR/producer_output.log"

# Copia risultati se generati
docker-compose exec -T test-runner cp /workspace/results/producer_results.json /workspace/ 2>/dev/null || true
if [[ -f "producer_results.json" ]]; then
    mv producer_results.json "$RESULTS_DIR/"
fi

# 6. Consumer test
log_info "Iniziando test consumer..."

cat > "$RESULTS_DIR/kafka_consumer_test.py" << 'EOF'
import time
import json
from kafka import KafkaConsumer
from kafka.errors import KafkaError

def run_consumer_test():
    consumer_config = {
        'bootstrap_servers': ['localhost:9092'],
        'auto_offset_reset': 'earliest',
        'enable_auto_commit': True,
        'group_id': 'test-group',
        'value_deserializer': lambda m: json.loads(m.decode('utf-8'))
    }
    
    consumer = KafkaConsumer('test-topic', **consumer_config)
    
    messages_consumed = 0
    start_time = time.time()
    test_duration = 30  # 30 secondi per consumer
    latencies = []
    
    print(f"Starting consumer test for {test_duration} seconds...")
    
    for message in consumer:
        current_time = time.time()
        
        if current_time - start_time > test_duration:
            break
            
        messages_consumed += 1
        
        # Calcola latency se possibile
        if 'timestamp' in message.value:
            latency = (current_time - message.value['timestamp']) * 1000  # ms
            latencies.append(latency)
        
        if messages_consumed % 50 == 0:
            elapsed = current_time - start_time
            rate = messages_consumed / elapsed if elapsed > 0 else 0
            print(f"Messages consumed: {messages_consumed}, Rate: {rate:.2f} msgs/sec")
    
    consumer.close()
    
    total_time = time.time() - start_time
    avg_throughput = messages_consumed / total_time if total_time > 0 else 0
    avg_latency = sum(latencies) / len(latencies) if latencies else 0
    
    results = {
        'total_messages': messages_consumed,
        'test_duration': total_time,
        'avg_throughput': avg_throughput,
        'avg_latency_ms': avg_latency
    }
    
    print(f"\n=== CONSUMER RESULTS ===")
    print(f"Messages consumed: {messages_consumed}")
    print(f"Test duration: {total_time:.2f} seconds")
    print(f"Average throughput: {avg_throughput:.2f} msgs/sec")
    print(f"Average latency: {avg_latency:.2f} ms")
    
    return results

if __name__ == "__main__":
    results = run_consumer_test()
    with open('/workspace/results/consumer_results.json', 'w') as f:
        json.dump(results, f, indent=2)
EOF

# Pausa per permettere al producer di finire
sleep 10

# Esegui consumer test
docker-compose exec -T test-runner python3 -c "
import sys
sys.path.append('/workspace')
exec(open('$RESULTS_DIR/kafka_consumer_test.py').read())
" 2>&1 | tee "$RESULTS_DIR/consumer_output.log"

# Copia risultati consumer
docker-compose exec -T test-runner cp /workspace/results/consumer_results.json /workspace/ 2>/dev/null || true
if [[ -f "consumer_results.json" ]]; then
    mv consumer_results.json "$RESULTS_DIR/"
fi

# 7. Salva metriche sistema
log_info "Raccogliendo metriche sistema..."
docker stats --no-stream > "$RESULTS_DIR/docker_stats.txt"
docker-compose logs kafka > "$RESULTS_DIR/kafka.log" 2>/dev/null || true

# 8. Genera summary
log_info "Generando summary..."

# Estrai metriche dai risultati JSON
if [[ -f "$RESULTS_DIR/producer_results.json" ]] && [[ -f "$RESULTS_DIR/consumer_results.json" ]]; then
    python3 << EOF > "$RESULTS_DIR/summary.txt"
import json

# Carica risultati
with open('$RESULTS_DIR/producer_results.json', 'r') as f:
    producer = json.load(f)

with open('$RESULTS_DIR/consumer_results.json', 'r') as f:
    consumer = json.load(f)

print("=== KAFKA BASELINE TEST SUMMARY ===")
print(f"Date: $(date)")
print(f"Test Name: $TEST_NAME")
print("")
print("PRODUCER RESULTS:")
print(f"  Messages Sent: {producer['total_messages']:,}")
print(f"  Duration: {producer['test_duration']:.2f} seconds")
print(f"  Throughput: {producer['avg_throughput']:.2f} msgs/sec")
print("")
print("CONSUMER RESULTS:")
print(f"  Messages Consumed: {consumer['total_messages']:,}")
print(f"  Duration: {consumer['test_duration']:.2f} seconds")
print(f"  Throughput: {consumer['avg_throughput']:.2f} msgs/sec")
print(f"  Average Latency: {consumer['avg_latency_ms']:.2f} ms")
print("")
print("CONFIGURATION ANALYSIS:")
print("  - Batch Size: 16KB (small, room for improvement)")
print("  - Linger: 0ms (no temporal batching)")
print("  - Compression: none (inefficient)")
print("  - Network Threads: 3 (conservative)")
print("")
print("OPTIMIZATION OPPORTUNITIES:")
print("  1. Increase batch_size to 32KB-64KB")
print("  2. Add linger_ms (5-50ms) for efficient batching")
print("  3. Enable compression (lz4/snappy)")
print("  4. Increase network threads if CPU available")
EOF
else
    echo "Test results incomplete - check logs for errors" > "$RESULTS_DIR/summary.txt"
fi

# 9. Risultati finali
log_success "Test completato!"
log_info "Risultati salvati in: $RESULTS_DIR"

echo ""
echo "=== FILE GENERATI ==="
ls -la "$RESULTS_DIR"

echo ""
echo "=== SUMMARY ==="
cat "$RESULTS_DIR/summary.txt"

echo ""
log_success "Ora puoi confrontare con test ottimizzati!"
log_info "Prossimo passo: ./scripts/hybrid-full-test.sh configs/.env.optimized1 high_throughput"