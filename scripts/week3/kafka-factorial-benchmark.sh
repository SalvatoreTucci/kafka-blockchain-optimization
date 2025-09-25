#!/bin/bash

# Kafka Factorial Design Benchmark (Week 3) - Fixed Version
# 2^3 Factorial Design: batch.size × linger.ms × compression.type
# Da eseguire dalla directory root del progetto

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get script directory e project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." &> /dev/null && pwd )"

# Cambio alla directory del progetto principale
cd "$PROJECT_ROOT"

# Banner
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           KAFKA FACTORIAL DESIGN BENCHMARK (Week 3)          ║"
echo "║                                                               ║"
echo "║  🧪 2³ Factorial Design: 8 Configurations × Multiple Runs    ║"
echo "║  📊 Statistical Analysis: ANOVA + Interaction Effects         ║"
echo "║  🎯 Focus: Latency Optimization & Parameter Interactions     ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Parametri configurabili
RUNS_PER_CONFIG="${1:-3}"
DURATION="${2:-300}"
TPS="${3:-1000}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASE_RESULTS_DIR="factorial_results_${TIMESTAMP}"

echo -e "${YELLOW}📋 Configurazione Factorial Design:${NC}"
echo "• Project Root: ${PROJECT_ROOT}"
echo "• Runs per configurazione: ${RUNS_PER_CONFIG}"
echo "• Durata per test: ${DURATION}s"
echo "• Target TPS: ${TPS}"
echo "• Directory risultati: ${BASE_RESULTS_DIR}"
echo "• Tempo stimato totale: 90 minuti (approssimativo)"
echo ""

# Definizione Factorial Design 2^3 - SPOSTATA DOPO LA DICHIARAZIONE
FACTORIAL_CONFIGS=(
    "config_000|16384|0|none|Baseline: small batch + no linger + no compression"
    "config_001|16384|0|lz4|Small batch + no linger + compression"  
    "config_010|16384|10|none|Small batch + linger + no compression"
    "config_011|16384|10|lz4|Small batch + linger + compression"
    "config_100|65536|0|none|Large batch + no linger + no compression"
    "config_101|65536|0|lz4|Large batch + no linger + compression"
    "config_110|65536|10|none|Large batch + linger + no compression"  
    "config_111|65536|10|lz4|Large batch + linger + compression (all factors)"
)

# Verifica prerequisiti
echo -e "${YELLOW}🔍 Verifica prerequisiti...${NC}"
if [ ! -f "scripts/simple-kafka-test.sh" ]; then
    echo -e "${RED}❌ Script scripts/simple-kafka-test.sh non trovato!${NC}"
    echo "Esegui questo script dalla directory root del progetto"
    exit 1
fi

chmod +x scripts/simple-kafka-test.sh
echo -e "${GREEN}✅ Prerequisiti verificati${NC}"

# Crea directory principale
mkdir -p "${BASE_RESULTS_DIR}"

# Log file per tracking
LOG_FILE="${BASE_RESULTS_DIR}/factorial_execution.log"
echo "Factorial Design Execution Log - Started at $(date)" > "${LOG_FILE}"

# Funzione per creare configurazione .env
create_factorial_config() {
    local config_name=$1
    local batch_size=$2
    local linger_ms=$3
    local compression=$4
    
    local config_file=".env.${config_name}"
    
    cat > "${config_file}" << EOF
# Kafka Factorial Configuration: ${config_name}
# Factors: batch=${batch_size}, linger=${linger_ms}ms, compression=${compression}
KAFKA_BATCH_SIZE=${batch_size}
KAFKA_LINGER_MS=${linger_ms}
KAFKA_COMPRESSION_TYPE=${compression}
KAFKA_BUFFER_MEMORY=67108864
KAFKA_NUM_NETWORK_THREADS=4
KAFKA_NUM_IO_THREADS=8
KAFKA_SOCKET_SEND_BUFFER_BYTES=131072
KAFKA_SOCKET_RECEIVE_BUFFER_BYTES=131072
KAFKA_REPLICA_FETCH_MAX_BYTES=2097152

TEST_NAME=${config_name}
TEST_DURATION=${DURATION}
TEST_TPS=${TPS}
EOF

    echo "${config_file}"
}

# Funzione per eseguire run singolo con better error handling
run_single_test() {
    local config_name=$1
    local run_number=$2
    local config_file=$3
    local description=$4
    
    local test_id="${config_name}_run${run_number}_${TIMESTAMP}"
    local config_dir="${BASE_RESULTS_DIR}/${config_name}"
    
    echo -e "${CYAN}🧪 Test: ${config_name} | Run: ${run_number}/${RUNS_PER_CONFIG}${NC}"
    echo -e "${BLUE}📝 ${description}${NC}"
    echo "Starting test ${test_id} at $(date)" >> "${LOG_FILE}"
    
    # Timeout più lungo per test più stabili
    local timeout_duration=$((DURATION + 300))
    
    if timeout ${timeout_duration} ./scripts/simple-kafka-test.sh "${config_file}" "${test_id}" "${DURATION}" "${TPS}" < /dev/null; then
        # Sposta risultati nella directory organizzata
        mkdir -p "${config_dir}/run_${run_number}"
        
        if [ -d "results/${test_id}" ]; then
            mv "results/${test_id}"/* "${config_dir}/run_${run_number}/" 2>/dev/null || true
            rmdir "results/${test_id}" 2>/dev/null || true
            echo -e "${GREEN}✅ Run ${run_number} completato${NC}"
            echo "Test ${test_id} completed successfully at $(date)" >> "${LOG_FILE}"
            return 0
        else
            echo -e "${RED}❌ Risultati non trovati per run ${run_number}${NC}"
            echo "Test ${test_id} failed - no results directory at $(date)" >> "${LOG_FILE}"
            return 1
        fi
    else
        echo -e "${RED}❌ Run ${run_number} fallito o timeout${NC}"
        mkdir -p "${config_dir}/run_${run_number}"
        echo "Test failed or timed out at $(date)" > "${config_dir}/run_${run_number}/error.log"
        echo "Test ${test_id} failed or timed out at $(date)" >> "${LOG_FILE}"
        return 1
    fi
}

# Funzione per eseguire configurazione completa
run_factorial_configuration() {
    local config_spec=$1
    local config_index=$2
    
    # Parse configuration usando read invece di IFS
    local config_name batch_size linger_ms compression description
    IFS='|' read -r config_name batch_size linger_ms compression description <<< "${config_spec}"
    
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  📊 CONFIGURAZIONE: ${config_name^^} [${config_index}/8]"
    echo "║  ⚙️  Batch: ${batch_size} bytes, Linger: ${linger_ms}ms, Compression: ${compression}"
    echo "║  📝 ${description}"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo "Starting configuration ${config_name} at $(date)" >> "${LOG_FILE}"
    
    # Crea file configurazione
    local config_file
    config_file=$(create_factorial_config "${config_name}" "${batch_size}" "${linger_ms}" "${compression}")
    
    # Esegui multiple runs
    local successful_runs=0
    local run
    for run in $(seq 1 ${RUNS_PER_CONFIG}); do
        echo "Attempting run ${run} for ${config_name}" >> "${LOG_FILE}"
        
        if run_single_test "${config_name}" "${run}" "${config_file}" "${description}"; then
            ((successful_runs++))
            echo "Run ${run} successful for ${config_name}" >> "${LOG_FILE}"
        else
            echo "Run ${run} failed for ${config_name}" >> "${LOG_FILE}"
        fi
        
        # Pausa tra run (ridotta per test più veloci)
        if [ ${run} -lt ${RUNS_PER_CONFIG} ]; then
            echo -e "${YELLOW}⏸️  Pausa 20s prima prossimo run...${NC}"
            sleep 20
        fi
    done
    
    echo -e "${GREEN}📊 ${config_name}: ${successful_runs}/${RUNS_PER_CONFIG} runs completati${NC}"
    echo -e "${BLUE}📁 Risultati salvati in: ${BASE_RESULTS_DIR}/${config_name}${NC}"
    echo "Configuration ${config_name} completed with ${successful_runs}/${RUNS_PER_CONFIG} successful runs" >> "${LOG_FILE}"
    
    # Cleanup config file
    rm -f "${config_file}"
    
    # Pausa tra configurazioni (ridotta)
    if [ ${config_index} -lt ${#FACTORIAL_CONFIGS[@]} ]; then
        echo -e "${PURPLE}⏸️  Pausa 30s prima prossima configurazione...${NC}"
        sleep 30
    fi
    
    return 0
}

# Esegui tutti i test factorial con better progress tracking
echo -e "${PURPLE}🚀 Inizio Factorial Design Benchmark${NC}"
echo -e "${YELLOW}Configurazioni da testare: ${#FACTORIAL_CONFIGS[@]}${NC}"
echo -e "${YELLOW}Runs totali previsti: $((${#FACTORIAL_CONFIGS[@]} * ${RUNS_PER_CONFIG}))${NC}"
echo -e "${YELLOW}Tempo stimato: $((${#FACTORIAL_CONFIGS[@]} * ${RUNS_PER_CONFIG} * (${DURATION} + 50) / 60)) minuti${NC}"
echo ""

# Conferma prima di iniziare se durata > 60 minuti
total_time_minutes=$((${#FACTORIAL_CONFIGS[@]} * ${RUNS_PER_CONFIG} * (${DURATION} + 50) / 60))
if [ ${total_time_minutes} -gt 60 ]; then
    echo -e "${YELLOW}⚠️  Il test completo richiederà circa ${total_time_minutes} minuti.${NC}"
    echo -e "${YELLOW}Vuoi continuare? (y/N)${NC}"
    read -r -t 30 confirmation || confirmation="n"
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Test annullato dall'utente${NC}"
        exit 0
    fi
fi

# Loop principale con error handling robusto
config_count=1
total_successful_tests=0
total_failed_tests=0

for config_spec in "${FACTORIAL_CONFIGS[@]}"; do
    echo -e "${YELLOW}[${config_count}/${#FACTORIAL_CONFIGS[@]}] Processando configurazione...${NC}"
    
    if run_factorial_configuration "${config_spec}" "${config_count}"; then
        echo -e "${GREEN}✅ Configurazione ${config_count} processata${NC}"
    else
        echo -e "${RED}❌ Errore configurazione ${config_count}${NC}"
    fi
    
    ((config_count++))
    echo ""
done

# Crea summary factorial design
create_factorial_summary() {
    echo -e "${YELLOW}📊 Creazione summary factorial design...${NC}"
    
    local summary_file="${BASE_RESULTS_DIR}/FACTORIAL_SUMMARY.md"
    
    cat > "${summary_file}" << EOF
# Factorial Design Results Summary (Week 3)

**Generated**: $(date)
**Design**: 2³ Factorial (batch.size × linger.ms × compression.type)  
**Configurations**: ${#FACTORIAL_CONFIGS[@]}
**Runs per Configuration**: ${RUNS_PER_CONFIG}
**Total Tests Attempted**: $((${#FACTORIAL_CONFIGS[@]} * ${RUNS_PER_CONFIG}))

## Factorial Design Matrix

| Config | Batch Size | Linger (ms) | Compression | Description |
|--------|------------|-------------|-------------|-------------|
EOF

    # Aggiungi configurazioni alla tabella
    for config_spec in "${FACTORIAL_CONFIGS[@]}"; do
        IFS='|' read -r config_name batch_size linger_ms compression description <<< "${config_spec}"
        echo "| ${config_name} | ${batch_size} | ${linger_ms} | ${compression} | ${description} |" >> "${summary_file}"
    done
    
    cat >> "${summary_file}" << EOF

## Factor Levels

- **Factor A (batch.size)**: 16KB (low), 65KB (high)
- **Factor B (linger.ms)**: 0ms (low), 10ms (high)  
- **Factor C (compression)**: none (low), lz4 (high)

## Directory Structure

\`\`\`
${BASE_RESULTS_DIR}/
├── FACTORIAL_SUMMARY.md          # Questo file
├── factorial_execution.log       # Log esecuzione
├── config_000/                   # Baseline (000)
│   ├── run_1/
│   ├── run_2/
│   └── run_3/
├── config_001/                   # Small batch + compression (001)
├── config_010/                   # Small batch + linger (010)
├── config_011/                   # Small batch + both (011)
├── config_100/                   # Large batch only (100)
├── config_101/                   # Large batch + compression (101)
├── config_110/                   # Large batch + linger (110)
└── config_111/                   # All factors high (111)
\`\`\`

## Next Steps

1. **Analisi statistica**:
   \`\`\`bash
   python3 scripts/week3/analyze_factorial_results.py ${BASE_RESULTS_DIR}
   \`\`\`

2. **ANOVA Analysis**:
   - Main effects di ogni fattore
   - Interaction effects tra fattori
   - Statistical significance testing

3. **Optimization**:
   - Identificare configurazione Pareto-optimal
   - Response Surface Methodology  
   - Preparare configurazione finale per Week 4

## Execution Log

Check \`factorial_execution.log\` for detailed execution timeline and any errors.

---
*Generated by Kafka Factorial Design Benchmark Suite (Fixed Version)*
EOF

    echo -e "${GREEN}📄 Summary creato: ${summary_file}${NC}"
}

# Conta risultati effettivi
echo -e "${YELLOW}📊 Conteggio risultati finali...${NC}"
total_dirs_created=$(find "${BASE_RESULTS_DIR}" -name "run_*" -type d | wc -l)
echo "Total test directories created: ${total_dirs_created}" >> "${LOG_FILE}"

# Crea summary finale
create_factorial_summary

# Risultati finali con statistiche reali
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                 🎉 FACTORIAL DESIGN COMPLETATO!               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${CYAN}📁 Tutti i risultati factorial salvati in: ${YELLOW}${BASE_RESULTS_DIR}${NC}"
echo -e "${CYAN}📄 Summary completo: ${YELLOW}${BASE_RESULTS_DIR}/FACTORIAL_SUMMARY.md${NC}"
echo -e "${CYAN}📋 Log esecuzione: ${YELLOW}${BASE_RESULTS_DIR}/factorial_execution.log${NC}"
echo -e "${CYAN}📊 Test directories creati: ${YELLOW}${total_dirs_created}${NC}"
echo ""

echo -e "${BLUE}📊 Per analizzare i risultati:${NC}"
echo -e "${YELLOW}python3 scripts/week3/analyze_factorial_results.py ${BASE_RESULTS_DIR}${NC}"
echo ""

if [ ${total_dirs_created} -ge $((${#FACTORIAL_CONFIGS[@]} * ${RUNS_PER_CONFIG} / 2)) ]; then
    echo -e "${GREEN}🎯 Factorial Design completato con successo sufficiente per analisi!${NC}"
else
    echo -e "${YELLOW}⚠️  Alcuni test potrebbero essere falliti. Controlla il log per dettagli.${NC}"
fi

echo -e "${BLUE}Ready per ANOVA analysis e optimization finale.${NC}"

# Final log entry
echo "Factorial Design completed at $(date) with ${total_dirs_created} test directories created" >> "${LOG_FILE}"