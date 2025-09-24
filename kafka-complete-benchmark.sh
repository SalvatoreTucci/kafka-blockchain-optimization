#!/bin/bash

# Kafka Complete Benchmark Suite
# Esegue tutti i test di performance Kafka e organizza i risultati

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner iniziale
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                 KAFKA COMPLETE BENCHMARK SUITE               ║"
echo "║                                                               ║"
echo "║  🚀 Test automatizzati per tutte le configurazioni Kafka     ║"
echo "║  📊 Risultati organizzati per tipologia                      ║"
echo "║  📈 Analisi automatica con Python                            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Configurazione
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASE_RESULTS_DIR="kafka_benchmark_results_${TIMESTAMP}"
DURATION="${1:-120}"  # Durata default 2 minuti per test più veloci
TPS="${2:-1000}"      # Target TPS

echo -e "${YELLOW}📋 Configurazione del benchmark:${NC}"
echo "• Durata per test: ${DURATION}s"
echo "• Target TPS: ${TPS}"
echo "• Directory risultati: ${BASE_RESULTS_DIR}"
echo

# Definizione delle configurazioni di test
declare -A TEST_CONFIGS=(
    ["baseline"]="Configurazione base di riferimento|.env.default"
    ["batch-optimized"]="Ottimizzazione batch size|.env.batch-optimized" 
    ["compression"]="Test con compressione|.env.compression"
    ["high-throughput"]="Configurazione ad alto throughput|.env.high-throughput"
    ["low-latency"]="Ottimizzazione per bassa latenza|.env.low-latency"
)

# Array per memorizzare i risultati
declare -A RESULTS_SUMMARY

# Funzione per creare le configurazioni di test se non esistono
create_test_configs() {
    echo -e "${YELLOW}🔧 Creazione configurazioni di test...${NC}"
    
    # Configurazione baseline (default)
    cat > .env.default << 'EOF'
# Kafka Default Configuration (Baseline)
KAFKA_BATCH_SIZE=16384
KAFKA_LINGER_MS=0
KAFKA_COMPRESSION_TYPE=none
KAFKA_BUFFER_MEMORY=33554432
KAFKA_NUM_NETWORK_THREADS=3
KAFKA_NUM_IO_THREADS=8
KAFKA_SOCKET_SEND_BUFFER_BYTES=102400
KAFKA_SOCKET_RECEIVE_BUFFER_BYTES=102400
KAFKA_REPLICA_FETCH_MAX_BYTES=1048576

TEST_NAME=baseline
TEST_DURATION=120
TEST_TPS=1000
EOF

    # Configurazione batch ottimizzata
    cat > .env.batch-optimized << 'EOF'
# Kafka Batch Optimized Configuration
KAFKA_BATCH_SIZE=65536
KAFKA_LINGER_MS=5
KAFKA_COMPRESSION_TYPE=none
KAFKA_BUFFER_MEMORY=67108864
KAFKA_NUM_NETWORK_THREADS=3
KAFKA_NUM_IO_THREADS=8
KAFKA_SOCKET_SEND_BUFFER_BYTES=131072
KAFKA_SOCKET_RECEIVE_BUFFER_BYTES=131072
KAFKA_REPLICA_FETCH_MAX_BYTES=2097152

TEST_NAME=batch-optimized
TEST_DURATION=120
TEST_TPS=1000
EOF

    # Configurazione con compressione
    cat > .env.compression << 'EOF'
# Kafka Compression Configuration
KAFKA_BATCH_SIZE=32768
KAFKA_LINGER_MS=10
KAFKA_COMPRESSION_TYPE=lz4
KAFKA_BUFFER_MEMORY=67108864
KAFKA_NUM_NETWORK_THREADS=4
KAFKA_NUM_IO_THREADS=8
KAFKA_SOCKET_SEND_BUFFER_BYTES=131072
KAFKA_SOCKET_RECEIVE_BUFFER_BYTES=131072
KAFKA_REPLICA_FETCH_MAX_BYTES=2097152

TEST_NAME=compression
TEST_DURATION=120
TEST_TPS=1000
EOF

    # Configurazione high throughput
    cat > .env.high-throughput << 'EOF'
# Kafka High Throughput Configuration
KAFKA_BATCH_SIZE=131072
KAFKA_LINGER_MS=20
KAFKA_COMPRESSION_TYPE=snappy
KAFKA_BUFFER_MEMORY=134217728
KAFKA_NUM_NETWORK_THREADS=6
KAFKA_NUM_IO_THREADS=12
KAFKA_SOCKET_SEND_BUFFER_BYTES=262144
KAFKA_SOCKET_RECEIVE_BUFFER_BYTES=262144
KAFKA_REPLICA_FETCH_MAX_BYTES=4194304

TEST_NAME=high-throughput
TEST_DURATION=120
TEST_TPS=1500
EOF

    # Configurazione low latency
    cat > .env.low-latency << 'EOF'
# Kafka Low Latency Configuration
KAFKA_BATCH_SIZE=1024
KAFKA_LINGER_MS=0
KAFKA_COMPRESSION_TYPE=none
KAFKA_BUFFER_MEMORY=16777216
KAFKA_NUM_NETWORK_THREADS=8
KAFKA_NUM_IO_THREADS=16
KAFKA_SOCKET_SEND_BUFFER_BYTES=65536
KAFKA_SOCKET_RECEIVE_BUFFER_BYTES=65536
KAFKA_REPLICA_FETCH_MAX_BYTES=524288

TEST_NAME=low-latency
TEST_DURATION=120
TEST_TPS=800
EOF

    echo -e "${GREEN}✅ Configurazioni create con successo${NC}"
}

# Funzione per verificare prerequisiti
check_prerequisites() {
    echo -e "${YELLOW}🔍 Verifica prerequisiti...${NC}"
    
    # Verifica Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker non installato${NC}"
        exit 1
    fi
    
    # Verifica Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}❌ Docker Compose non installato${NC}"
        exit 1
    fi
    
    # Verifica script di test
    if [ ! -f "scripts/simple-kafka-test.sh" ]; then
        echo -e "${RED}❌ Script simple-kafka-test.sh non trovato${NC}"
        exit 1
    fi
    
    # Rendi eseguibile lo script
    chmod +x scripts/simple-kafka-test.sh
    
    # Verifica Python (opzionale per analisi)
    if command -v python3 &> /dev/null; then
        echo -e "${GREEN}✅ Python3 disponibile per analisi${NC}"
        PYTHON_AVAILABLE=true
    else
        echo -e "${YELLOW}⚠️  Python3 non disponibile, analisi limitata${NC}"
        PYTHON_AVAILABLE=false
    fi
    
    echo -e "${GREEN}✅ Prerequisiti verificati${NC}"
}

# Funzione per eseguire un singolo test
run_single_test() {
    local test_name=$1
    local config_file=$2
    local description=$3
    
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  🧪 TEST: ${test_name^^}"
    echo "║  📝 ${description}"
    echo "║  ⚙️  Config: ${config_file}"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Directory per questo test
    local test_dir="${BASE_RESULTS_DIR}/${test_name}"
    
    # Esegui il test
    echo -e "${YELLOW}⏱️  Avvio test ${test_name}...${NC}"
    
    if timeout 600 ./scripts/simple-kafka-test.sh "$config_file" "${test_name}_${TIMESTAMP}" "$DURATION" "$TPS"; then
        echo -e "${GREEN}✅ Test ${test_name} completato con successo${NC}"
        
        # Sposta i risultati nella directory organizzata
        if [ -d "results/${test_name}_${TIMESTAMP}" ]; then
            mkdir -p "$test_dir"
            mv "results/${test_name}_${TIMESTAMP}"/* "$test_dir/"
            rmdir "results/${test_name}_${TIMESTAMP}" 2>/dev/null || true
            
            # Estrai metriche per il sommario
            extract_metrics "$test_dir" "$test_name"
            
            echo -e "${BLUE}📁 Risultati salvati in: ${test_dir}${NC}"
        fi
    else
        echo -e "${RED}❌ Test ${test_name} fallito o timeout${NC}"
        RESULTS_SUMMARY["${test_name}_status"]="FAILED"
        
        # Crea directory e salva log di errore anche se il test fallisce
        mkdir -p "$test_dir"
        echo "Test failed or timed out at $(date)" > "$test_dir/error.log"
        docker-compose logs --tail=50 kafka > "$test_dir/kafka-error.log" 2>/dev/null || true
    fi
    
    echo -e "${PURPLE}⏸️  Pausa di 30 secondi prima del prossimo test...${NC}"
    sleep 30
}

# Funzione per estrarre metriche dai risultati
extract_metrics() {
    local test_dir=$1
    local test_name=$2
    
    if [ -f "${test_dir}/producer-test.log" ]; then
        # Estrai metriche dal log del producer
        local final_line=$(grep "records sent.*records/sec.*avg latency" "${test_dir}/producer-test.log" | tail -1)
        
        if [[ -n "$final_line" ]]; then
            # Usa regex per estrarre le metriche in modo più affidabile
            local records=$(echo "$final_line" | grep -oE '^[0-9]+')
            local throughput=$(echo "$final_line" | grep -oE '[0-9]+\.[0-9]+ records/sec' | grep -oE '[0-9]+\.[0-9]+')
            local avg_latency=$(echo "$final_line" | grep -oE '[0-9]+\.[0-9]+ ms avg latency' | grep -oE '[0-9]+\.[0-9]+')
            local max_latency=$(echo "$final_line" | grep -oE '[0-9]+\.[0-9]+ ms max latency' | grep -oE '[0-9]+\.[0-9]+')
            
            RESULTS_SUMMARY["${test_name}_records"]="${records:-N/A}"
            RESULTS_SUMMARY["${test_name}_throughput"]="${throughput:-N/A}"
            RESULTS_SUMMARY["${test_name}_avg_latency"]="${avg_latency:-N/A}"
            RESULTS_SUMMARY["${test_name}_max_latency"]="${max_latency:-N/A}"
            RESULTS_SUMMARY["${test_name}_status"]="SUCCESS"
        else
            RESULTS_SUMMARY["${test_name}_status"]="PARSING_ERROR"
        fi
    else
        RESULTS_SUMMARY["${test_name}_status"]="NO_LOGS"
    fi
}

# Funzione per creare il sommario finale
create_final_summary() {
    echo -e "${YELLOW}📊 Creazione sommario finale...${NC}"
    
    local summary_file="${BASE_RESULTS_DIR}/BENCHMARK_SUMMARY.md"
    
    cat > "$summary_file" << EOF
# 🚀 Kafka Benchmark Results Summary

**Timestamp**: $(date)  
**Duration per test**: ${DURATION}s  
**Target TPS**: ${TPS}  

## 📋 Test Results Overview

| Test Name | Status | Records | Throughput (rec/s) | Avg Latency (ms) | Max Latency (ms) |
|-----------|--------|---------|-------------------|------------------|------------------|
EOF

    # Aggiungi i risultati di ogni test
    for test_name in "${!TEST_CONFIGS[@]}"; do
        local status="${RESULTS_SUMMARY[${test_name}_status]:-UNKNOWN}"
        local records="${RESULTS_SUMMARY[${test_name}_records]:-N/A}"
        local throughput="${RESULTS_SUMMARY[${test_name}_throughput]:-N/A}"
        local avg_latency="${RESULTS_SUMMARY[${test_name}_avg_latency]:-N/A}"
        local max_latency="${RESULTS_SUMMARY[${test_name}_max_latency]:-N/A}"
        
        local status_icon="❓"
        case $status in
            "SUCCESS") status_icon="✅" ;;
            "FAILED") status_icon="❌" ;;
            "PARSING_ERROR") status_icon="⚠️" ;;
            "NO_LOGS") status_icon="📝" ;;
        esac
        
        echo "| ${test_name} | ${status_icon} ${status} | ${records} | ${throughput} | ${avg_latency} | ${max_latency} |" >> "$summary_file"
    done
    
    cat >> "$summary_file" << EOF

## 🏆 Performance Analysis

### Best Performing Configurations
EOF

    # Trova il miglior throughput
    local best_throughput=0
    local best_test=""
    for test_name in "${!TEST_CONFIGS[@]}"; do
        local throughput="${RESULTS_SUMMARY[${test_name}_throughput]:-0}"
        if [[ "$throughput" =~ ^[0-9]+\.?[0-9]*$ ]] && (( $(echo "$throughput > $best_throughput" | bc -l 2>/dev/null || echo 0) )); then
            best_throughput=$throughput
            best_test=$test_name
        fi
    done
    
    if [[ -n "$best_test" ]]; then
        echo "- **Highest Throughput**: ${best_test} (${best_throughput} records/sec)" >> "$summary_file"
    fi
    
    # Trova la miglior latenza
    local best_latency=999999
    local best_latency_test=""
    for test_name in "${!TEST_CONFIGS[@]}"; do
        local latency="${RESULTS_SUMMARY[${test_name}_avg_latency]:-999999}"
        if [[ "$latency" =~ ^[0-9]+\.?[0-9]*$ ]] && (( $(echo "$latency < $best_latency" | bc -l 2>/dev/null || echo 0) )); then
            best_latency=$latency
            best_latency_test=$test_name
        fi
    done
    
    if [[ -n "$best_latency_test" ]]; then
        echo "- **Lowest Latency**: ${best_latency_test} (${best_latency} ms)" >> "$summary_file"
    fi
    
    cat >> "$summary_file" << EOF

## 📁 File Structure
\`\`\`
${BASE_RESULTS_DIR}/
├── BENCHMARK_SUMMARY.md          # Questo file
├── analysis_results/             # Risultati analisi Python
├── baseline/                     # Test configurazione base
│   ├── producer-test.log
│   ├── consumer-test.log
│   ├── summary.txt
│   └── ...
├── batch-optimized/             # Test batch ottimizzato
├── compression/                 # Test con compressione
├── high-throughput/            # Test alto throughput
└── low-latency/                # Test bassa latenza
\`\`\`

## 🔧 Next Steps

1. **Analizza i risultati dettagliati**:
   \`\`\`bash
   cd ${BASE_RESULTS_DIR}
   python3 ../analyze_benchmark_results.py
   \`\`\`

2. **Visualizza grafici** (se Grafana è attivo):
   - Grafana: http://localhost:3000 (admin/admin123)
   - Prometheus: http://localhost:9090

3. **Approfondisci test specifici**:
   \`\`\`bash
   cat ${best_test:-baseline}/summary.txt
   \`\`\`

---
*Generated by Kafka Complete Benchmark Suite*
EOF

    echo -e "${GREEN}📄 Sommario creato: ${summary_file}${NC}"
}

# Funzione principale di esecuzione
main() {
    echo -e "${BLUE}🚀 Avvio Kafka Complete Benchmark Suite${NC}"
    
    # Controlla prerequisiti
    check_prerequisites
    
    # Crea configurazioni di test
    create_test_configs
    
    # Crea directory principale dei risultati
    mkdir -p "$BASE_RESULTS_DIR"
    
    echo -e "${PURPLE}📊 Inizio esecuzione di ${#TEST_CONFIGS[@]} test configurazioni${NC}"
    echo
    
    # Esegui tutti i test
    local test_count=1
    for test_name in "${!TEST_CONFIGS[@]}"; do
        IFS='|' read -r description config_file <<< "${TEST_CONFIGS[$test_name]}"
        
        echo -e "${YELLOW}[${test_count}/${#TEST_CONFIGS[@]}]${NC}"
        run_single_test "$test_name" "$config_file" "$description"
        
        ((test_count++))
        echo
    done
    
    # Crea sommario finale
    create_final_summary
    
    # Risultati finali
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    🎉 BENCHMARK COMPLETATO!                   ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${CYAN}📁 Tutti i risultati salvati in: ${YELLOW}${BASE_RESULTS_DIR}${NC}"
    echo -e "${CYAN}📄 Sommario completo: ${YELLOW}${BASE_RESULTS_DIR}/BENCHMARK_SUMMARY.md${NC}"
    echo
    
    if $PYTHON_AVAILABLE; then
        echo -e "${GREEN}🐍 Per eseguire l'analisi Python:${NC}"
        echo -e "${YELLOW}cd ${BASE_RESULTS_DIR} && python3 ../analyze_benchmark_results.py${NC}"
        echo
    fi
    
    echo -e "${BLUE}📊 Per visualizzare i risultati:${NC}"
    echo -e "• Sommario: ${YELLOW}cat ${BASE_RESULTS_DIR}/BENCHMARK_SUMMARY.md${NC}"
    echo -e "• Grafana: ${YELLOW}http://localhost:3000${NC} (admin/admin123)"
    echo -e "• Prometheus: ${YELLOW}http://localhost:9090${NC}"
}

# Gestione parametri command line
case "${1:-}" in
    -h|--help)
        echo "Uso: $0 [durata] [tps]"
        echo "  durata: Durata di ogni test in secondi (default: 120)"
        echo "  tps: Target transactions per second (default: 1000)"
        echo
        echo "Esempio: $0 180 1500"
        exit 0
        ;;
    *)
        main
        ;;
esac