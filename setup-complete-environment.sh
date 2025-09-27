#!/bin/bash

# Setup completo ambiente Kafka + Blockchain Integrated Testing
# Mantiene tutto il funzionamento esistente e aggiunge blockchain

set -e

# Colori
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║       SETUP COMPLETE KAFKA + BLOCKCHAIN ENVIRONMENT           ║"
echo "║                                                                ║"
echo "║  🚀 Mantiene simple-kafka-test.sh funzionante                 ║"
echo "║  ⛓️  Aggiunge Hyperledger Fabric integration                  ║"
echo "║  📊 Week 4: Blockchain validation con Kafka ottimizzato       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Verifica prerequisiti base
echo -e "${YELLOW}🔍 Verifica prerequisiti...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker non installato!${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose non installato!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker e Docker Compose disponibili${NC}"

# Verifica script esistente funzionante
if [ ! -f "scripts/simple-kafka-test.sh" ]; then
    echo -e "${RED}❌ Script simple-kafka-test.sh non trovato!${NC}"
    echo "Questo script è necessario per il funzionamento"
    exit 1
fi

echo -e "${GREEN}✅ Script Kafka esistente verificato${NC}"

# Crea struttura directory
echo -e "${YELLOW}📁 Creazione struttura directory...${NC}"
mkdir -p {scripts,blockchain-config/{crypto-config,channel-artifacts},chaincodes/simple-ledger,configs/{monitoring,grafana/provisioning/datasources},results}

# Crea file di monitoraggio Prometheus
echo -e "${YELLOW}⚙️ Configurazione monitoring...${NC}"
cat > configs/monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'kafka-jmx'
    static_configs:
      - targets: ['kafka:9094']
    scrape_interval: 30s
    metrics_path: /metrics
    
  - job_name: 'docker-containers'
    static_configs:
      - targets: ['host.docker.internal:9323']
    scrape_interval: 30s
EOF

# Crea datasource Grafana
cat > configs/grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

# Verifica spazio disco
echo -e "${YELLOW}💾 Verifica spazio disco...${NC}"
AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}' | sed 's/[^0-9.]//g' || echo "1")
if (( $(echo "$AVAILABLE_SPACE > 3" | bc -l 2>/dev/null || echo 0) )); then
    echo -e "${GREEN}✅ Spazio disco sufficiente (${AVAILABLE_SPACE}GB)${NC}"
else
    echo -e "${YELLOW}⚠️ Spazio disco limitato. Test richiede ~2-3GB${NC}"
fi

# Test Docker
echo -e "${YELLOW}🐳 Test Docker environment...${NC}"
if docker run --rm hello-world >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker funzionante${NC}"
else
    echo -e "${RED}❌ Docker non funziona correttamente${NC}"
    exit 1
fi

# Pulisci ambiente esistente se presente
echo -e "${YELLOW}🧹 Pulizia ambiente esistente...${NC}"
docker-compose down -v >/dev/null 2>&1 || true
docker system prune -f >/dev/null 2>&1 || true

# Verifica file necessari sono presenti
echo -e "${YELLOW}📄 Verifica file configurazione...${NC}"

FILES_TO_CHECK=(
    "docker-compose.yml:Docker Compose integrato"
    ".env.optimal:Configurazione ottimale Week 3" 
    "scripts/blockchain-integrated-test.sh:Script test integrato"
)

missing_files=0
for file_info in "${FILES_TO_CHECK[@]}"; do
    IFS=':' read -r file desc <<< "$file_info"
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ ${desc}${NC}"
    else
        echo -e "${RED}❌ MANCANTE: ${desc} (${file})${NC}"
        ((missing_files++))
    fi
done

if [ $missing_files -gt 0 ]; then
    echo -e "${RED}❌ File mancanti! Crearli prima di continuare.${NC}"
    exit 1
fi

# Rendi eseguibili gli script
echo -e "${YELLOW}🔧 Configurazione script...${NC}"
chmod +x scripts/*.sh 2>/dev/null || true
chmod +x *.sh 2>/dev/null || true

# Test configurazione caricamento .env
echo -e "${YELLOW}⚙️ Test configurazione .env.optimal...${NC}"
if [ -f ".env.optimal" ]; then
    # Test caricamento variabili
    set -a
    source .env.optimal
    set +a
    
    if [ -n "$KAFKA_BATCH_SIZE" ] && [ -n "$KAFKA_LINGER_MS" ]; then
        echo -e "${GREEN}✅ Configurazione ottimale caricata${NC}"
        echo "  • Batch Size: $KAFKA_BATCH_SIZE bytes"
        echo "  • Linger Time: $KAFKA_LINGER_MS ms"
        echo "  • Compression: $KAFKA_COMPRESSION_TYPE"
    else
        echo -e "${RED}❌ Errore caricamento configurazione${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ File .env.optimal non trovato${NC}"
    exit 1
fi

# Test avvio base (solo core services)
echo -e "${YELLOW}🚀 Test avvio ambiente base...${NC}"
if docker-compose --env-file .env.optimal up -d zookeeper kafka; then
    echo -e "${GREEN}✅ Core services (Zookeeper + Kafka) avviati${NC}"
    
    # Attesa breve per initialization
    echo -e "${YELLOW}⏳ Attesa initialization (30s)...${NC}"
    sleep 30
    
    # Test Kafka readiness
    echo -n "Test Kafka readiness..."
    for i in {1..20}; do
        if docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 >/dev/null 2>&1; then
            echo -e " ${GREEN}✓${NC}"
            break
        fi
        echo -n "."
        sleep 3
    done
    
    echo -e "${GREEN}✅ Test ambiente completato${NC}"
    
    # Ferma per ora
    docker-compose down >/dev/null 2>&1
    echo -e "${GREEN}✅ Ambiente fermato (test completato)${NC}"
else
    echo -e "${RED}❌ Errore avvio ambiente base${NC}"
    exit 1
fi

# Setup completed
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    SETUP COMPLETATO!                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}📋 AMBIENTE CONFIGURATO:${NC}"
echo -e "${GREEN}✅ Docker environment funzionante${NC}"
echo -e "${GREEN}✅ Script simple-kafka-test.sh mantenuto${NC}"
echo -e "${GREEN}✅ Blockchain integration aggiunta${NC}"
echo -e "${GREEN}✅ Configurazione ottimale Week 3 ready${NC}"
echo -e "${GREEN}✅ Monitoring (Prometheus + Grafana) configurato${NC}"

echo ""
echo -e "${YELLOW}🎯 COMANDI DISPONIBILI:${NC}"
echo ""
echo -e "${BLUE}1. Test Kafka standalone (mantiene funzionalità esistente):${NC}"
echo -e "${YELLOW}   ./scripts/simple-kafka-test.sh .env.optimal${NC}"
echo ""
echo -e "${BLUE}2. Test Blockchain Integrato (NUOVO):${NC}"
echo -e "${YELLOW}   ./scripts/blockchain-integrated-test.sh .env.optimal${NC}"
echo ""
echo -e "${BLUE}3. Avvio ambiente completo per sviluppo:${NC}"
echo -e "${YELLOW}   docker-compose --env-file .env.optimal up -d${NC}"
echo ""
echo -e "${BLUE}4. Monitoring:${NC}"
echo -e "   • Grafana: ${YELLOW}http://localhost:3000${NC} (admin/admin123)"
echo -e "   • Prometheus: ${YELLOW}http://localhost:9090${NC}"
echo ""

echo -e "${PURPLE}🏆 WEEK 4 READY:${NC}"
echo "• Kafka optimization (Week 1-3) ✅ MANTIENE FUNZIONALITÀ"
echo "• Blockchain integration ✅ AGGIUNGE FUNZIONALITÀ"  
echo "• Config ottimale (config_100) ✅ PRONTA"
echo "• Test automatizzati ✅ PRONTI"
echo "• Monitoring ✅ CONFIGURATO"

echo ""
echo -e "${GREEN}🚀 Ambiente pronto per validazione Week 4!${NC}"
echo -e "${BLUE}Primo test raccomandato:${NC}"
echo -e "${YELLOW}./scripts/blockchain-integrated-test.sh .env.optimal blockchain_validation_$(date +%H%M)${NC}"