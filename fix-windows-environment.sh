#!/bin/bash

# Script per risolvere problemi Docker su Windows

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')]${NC} $1"
}

log_info "=== FIX AMBIENTE WINDOWS ==="

# 1. Stop completo e cleanup
log_info "Fermando tutti i servizi..."
docker-compose down -v --remove-orphans 2>/dev/null || true
docker container prune -f
docker network prune -f
docker volume prune -f

# 2. Verifica che Docker Desktop sia in esecuzione
log_info "Verificando Docker..."
if ! docker info &> /dev/null; then
    log_error "Docker non è in esecuzione"
    log_info "Assicurati che Docker Desktop sia avviato e riprova"
    exit 1
fi

# 3. Verifica porte libere (Windows style)
log_info "Verificando porte..."
netstat -an | findstr ":2181" && log_warning "Porta 2181 occupata"
netstat -an | findstr ":9092" && log_warning "Porta 9092 occupata" 
netstat -an | findstr ":3000" && log_warning "Porta 3000 occupata"

# 4. Fix docker-compose.yml per Windows
log_info "Ottimizzando docker-compose.yml per Windows..."

# Backup originale
cp docker-compose.yml docker-compose.yml.backup

# Crea versione ottimizzata per Windows
cat > docker-compose.yml << 'COMPOSE_EOF'
networks:
  kafka-net:
    driver: bridge

volumes:
  kafka-data:
  zk-data:
  prometheus-data:
  grafana-data:

services:
  # Zookeeper con configurazione Windows-friendly
  zookeeper:
    image: confluentinc/cp-zookeeper:7.4.0
    hostname: zookeeper
    container_name: zookeeper
    networks:
      - kafka-net
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
      ZOOKEEPER_SYNC_LIMIT: 2
    volumes:
      - zk-data:/var/lib/zookeeper/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "sh", "-c", "echo srvr | nc localhost 2181"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s

  # Kafka con configurazione ottimizzata per Windows
  kafka:
    image: confluentinc/cp-kafka:7.4.0
    hostname: kafka
    container_name: kafka
    networks:
      - kafka-net
    ports:
      - "9092:9092"
      - "9094:9094"
    depends_on:
      zookeeper:
        condition: service_healthy
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: 'zookeeper:2181'
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:29092,PLAINTEXT_HOST://0.0.0.0:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_JMX_PORT: 9094
      KAFKA_JMX_HOSTNAME: localhost
      
      # Configurazione Windows-friendly
      KAFKA_LOG4J_LOGGERS: "kafka.controller=INFO,kafka.producer.async.DefaultEventHandler=INFO,state.change.logger=INFO"
      KAFKA_LOG4J_ROOT_LOGLEVEL: INFO
      
      # Memory settings per Windows
      KAFKA_HEAP_OPTS: "-Xmx512M -Xms512M"
      
    volumes:
      - kafka-data:/var/lib/kafka/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "kafka-topics", "--bootstrap-server", "localhost:9092", "--list"]
      interval: 30s
      timeout: 15s
      retries: 5
      start_period: 60s

  # Test runner con Python e dependencies
  test-runner:
    image: python:3.9-slim
    container_name: test-runner
    networks:
      - kafka-net
    depends_on:
      kafka:
        condition: service_healthy
    volumes:
      - .:/workspace
      - ./results:/workspace/results
    working_dir: /workspace
    command: |
      sh -c "
      apt-get update && apt-get install -y netcat-traditional curl &&
      pip install kafka-python==2.0.2 requests==2.31.0 &&
      tail -f /dev/null
      "
    restart: unless-stopped

  # Prometheus (opzionale per ora)
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    networks:
      - kafka-net
    ports:
      - "9090:9090"
    volumes:
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    restart: unless-stopped

  # Grafana (opzionale per ora)
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    networks:
      - kafka-net
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    volumes:
      - grafana-data:/var/lib/grafana
    restart: unless-stopped
COMPOSE_EOF

log_success "docker-compose.yml ottimizzato per Windows"

# 5. Riavvio graduale
log_info "Avviando servizi gradualmente..."

# Prima solo Zookeeper
log_info "Avviando Zookeeper..."
docker-compose up -d zookeeper

# Aspetta che Zookeeper sia pronto
log_info "Aspettando Zookeeper (45 secondi)..."
sleep 45

# Verifica Zookeeper
if docker-compose exec -T zookeeper sh -c 'echo srvr | nc localhost 2181' | grep -q "Zookeeper version"; then
    log_success "Zookeeper è pronto!"
else
    log_warning "Zookeeper potrebbe non essere completamente pronto, continuo..."
fi

# Poi Kafka
log_info "Avviando Kafka..."
docker-compose up -d kafka

# Aspetta che Kafka sia pronto
log_info "Aspettando Kafka (90 secondi)..."
sleep 90

# Verifica Kafka
log_info "Testando connettività Kafka..."
for i in {1..10}; do
    if docker-compose exec -T kafka kafka-topics --bootstrap-server localhost:9092 --list &>/dev/null; then
        log_success "Kafka è connesso!"
        break
    else
        log_info "Tentativo $i/10... aspetto 10 secondi"
        sleep 10
    fi
done

# Avvia il resto dei servizi
log_info "Avviando servizi rimanenti..."
docker-compose up -d

# 6. Test finale
log_info "Test finale della connettività..."
sleep 30

echo ""
log_info "=== STATO FINALE ==="
docker-compose ps

echo ""
log_info "=== TEST KAFKA ==="
if docker-compose exec -T kafka kafka-topics --bootstrap-server localhost:9092 --list &>/dev/null; then
    log_success "✅ Kafka funziona correttamente!"
    
    # Crea topic di test
    docker-compose exec -T kafka kafka-topics --create --topic test-connectivity \
        --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1 \
        --if-not-exists &>/dev/null
    
    log_success "✅ Topic di test creato!"
    
    echo ""
    log_info "=== ACCESSO DASHBOARD ==="
    echo "Grafana: http://localhost:3000 (admin/admin123)"
    echo "Prometheus: http://localhost:9090"
    
    echo ""
    log_success "AMBIENTE PRONTO! Ora puoi eseguire:"
    echo "./run-complete-test.sh"
    
else
    log_error "❌ Kafka ancora non risponde"
    echo ""
    log_info "Debug info:"
    docker-compose logs --tail=20 kafka
fi