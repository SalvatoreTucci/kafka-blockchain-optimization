#!/bin/bash

# Script per analizzare il test singolo default-baseline

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}=== ANALISI TEST SINGOLO default-baseline ===${NC}"
echo ""

# Trova la directory del test
TEST_DIR=""
for dir in results/default-baseline results/default_baseline results/baseline results/*/; do
    if [[ -d "$dir" ]] && [[ -f "$dir/test-metadata.txt" || -f "$dir/config-used.env" ]]; then
        TEST_DIR="$dir"
        break
    fi
done

if [[ -z "$TEST_DIR" ]]; then
    echo -e "${RED}‚ùå Directory test non trovata${NC}"
    echo "Directories disponibili in results/:"
    ls -la results/ 2>/dev/null || echo "Directory results non esiste"
    exit 1
fi

echo -e "${GREEN}‚úì Test trovato in: $TEST_DIR${NC}"
echo ""

# Analizza metadata
if [[ -f "$TEST_DIR/test-metadata.txt" ]]; then
    echo -e "${BLUE}Ì≥ã METADATA TEST:${NC}"
    cat "$TEST_DIR/test-metadata.txt"
    echo ""
fi

# Analizza configurazione
if [[ -f "$TEST_DIR/config-used.env" ]]; then
    echo -e "${BLUE}‚öôÔ∏è  CONFIGURAZIONE UTILIZZATA:${NC}"
    grep -E "(KAFKA_|TEST_)" "$TEST_DIR/config-used.env" | while read line; do
        echo "   $line"
    done
    echo ""
fi

# Lista tutti i file disponibili
echo -e "${BLUE}Ì≥Å FILE RISULTATI DISPONIBILI:${NC}"
find "$TEST_DIR" -type f | sort | while read file; do
    filename=$(basename "$file")
    size=$(ls -lh "$file" | awk '{print $5}')
    echo -e "   ${GREEN}‚úì${NC} $filename ($size)"
done
echo ""

# Analizza risultati specifici
echo -e "${BLUE}Ì≥ä ANALISI RISULTATI:${NC}"

# Summary
if [[ -f "$TEST_DIR/summary.txt" ]]; then
    echo -e "${YELLOW}Ì≥Ñ SUMMARY:${NC}"
    echo "----------------------------------------"
    cat "$TEST_DIR/summary.txt"
    echo "----------------------------------------"
    echo ""
fi

# Performance metrics
if [[ -f "$TEST_DIR/performance_metrics.json" ]]; then
    echo -e "${YELLOW}Ì≥à PERFORMANCE METRICS:${NC}"
    python3 -c "
import json
import sys
try:
    with open('$TEST_DIR/performance_metrics.json', 'r') as f:
        data = json.load(f)
    
    if 'kafka' in data:
        print('Kafka Metrics:')
        for key, value in data['kafka'].items():
            print(f'  {key}: {value}')
    
    if 'blockchain' in data:
        print('\\nBlockchain Metrics:')
        for key, value in data['blockchain'].items():
            print(f'  {key}: {value}')
            
    if 'summary' in data:
        print('\\nSummary:')
        for key, value in data['summary'].items():
            print(f'  {key}: {value}')
            
except Exception as e:
    print(f'Errore lettura JSON: {e}')
" 2>/dev/null || echo "   File JSON non leggibile o non presente"
    echo ""
fi

# Throughput results
if [[ -f "$TEST_DIR/throughput_results.txt" ]]; then
    echo -e "${YELLOW}Ì∫Ä THROUGHPUT RESULTS:${NC}"
    cat "$TEST_DIR/throughput_results.txt"
    echo ""
fi

# Latency results  
if [[ -f "$TEST_DIR/latency_results.txt" ]]; then
    echo -e "${YELLOW}‚è±Ô∏è  LATENCY RESULTS:${NC}"
    cat "$TEST_DIR/latency_results.txt"
    echo ""
fi

# Test output log (ultimi 20 righe)
if [[ -f "$TEST_DIR/test_output.log" ]]; then
    echo -e "${YELLOW}Ì≥ã TEST OUTPUT (ultime 20 righe):${NC}"
    echo "----------------------------------------"
    tail -20 "$TEST_DIR/test_output.log"
    echo "----------------------------------------"
    echo ""
fi

# Docker stats
if [[ -f "$TEST_DIR/docker_stats.txt" ]]; then
    echo -e "${YELLOW}Ì∞≥ UTILIZZO RISORSE DOCKER:${NC}"
    cat "$TEST_DIR/docker_stats.txt"
    echo ""
fi

# Kafka logs (se errori)
if [[ -f "$TEST_DIR/kafka.log" ]]; then
    error_count=$(grep -i error "$TEST_DIR/kafka.log" | wc -l)
    warning_count=$(grep -i warn "$TEST_DIR/kafka.log" | wc -l)
    
    echo -e "${YELLOW}Ì≥ù KAFKA LOGS SUMMARY:${NC}"
    echo "   Errori trovati: $error_count"
    echo "   Warning trovati: $warning_count"
    
    if [[ $error_count -gt 0 ]]; then
        echo -e "${RED}   Ultimi errori:${NC}"
        grep -i error "$TEST_DIR/kafka.log" | tail -5 | while read line; do
            echo "   $line"
        done
    fi
    echo ""
fi

# Calcola metriche chiave se disponibili
echo -e "${BLUE}ÌæØ METRICHE CHIAVE CALCOLATE:${NC}"

# Cerca throughput nei vari file
throughput=""
latency=""

# Cerca nei file di output
if [[ -f "$TEST_DIR/test_output.log" ]]; then
    throughput=$(grep -i "throughput\|msgs/sec\|messages/second" "$TEST_DIR/test_output.log" | tail -1 | grep -o '[0-9,]\+\.[0-9]\+\|[0-9,]\+' | tail -1)
    latency=$(grep -i "latency\|avg.*ms" "$TEST_DIR/test_output.log" | tail -1 | grep -o '[0-9,]\+\.[0-9]\+\|[0-9,]\+' | tail -1)
fi

if [[ -n "$throughput" ]]; then
    echo -e "   ${GREEN}‚úì${NC} Throughput: $throughput msgs/sec"
else
    echo -e "   ${YELLOW}?${NC} Throughput: non trovato nei log"
fi

if [[ -n "$latency" ]]; then
    echo -e "   ${GREEN}‚úì${NC} Latency media: $latency ms"
else
    echo -e "   ${YELLOW}?${NC} Latency: non trovata nei log"
fi

# Valutazione configurazione baseline
echo ""
echo -e "${BLUE}Ì≤° VALUTAZIONE CONFIGURAZIONE BASELINE:${NC}"
echo -e "   ${YELLOW}Ì≥ä${NC} Questa √® la configurazione DEFAULT (non ottimizzata)"
echo -e "   ${YELLOW}Ì≥ä${NC} Parametri usati:"
echo "   - Batch Size: 16KB (relativamente piccolo)"
echo "   - Linger: 0ms (nessun batching temporale)"
echo "   - Compression: none (spreco bandwidth)"
echo "   - Threads: 3 network + 8 I/O (conservative)"
echo ""
echo -e "   ${GREEN}Ì≤° OPPORTUNIT√Ä DI OTTIMIZZAZIONE:${NC}"
echo "   1. Aumentare batch_size (32KB-64KB) per +throughput"
echo "   2. Aggiungere linger_ms (5-50ms) per batching efficiente"
echo "   3. Abilitare compression (lz4/snappy) per -network usage"
echo "   4. Aumentare network_threads se CPU disponibili"

echo ""
echo -e "${BLUE}Ì∫Ä PROSSIMI PASSI CONSIGLIATI:${NC}"
echo "1. Esegui test con configurazioni ottimizzate:"
echo "   ./scripts/hybrid-full-test.sh configs/.env.optimized1 high_throughput"
echo "   ./scripts/hybrid-full-test.sh configs/.env.optimized2 low_latency"
echo ""
echo "2. Confronta risultati:"
echo "   ./scripts/compare-hybrid-results.py results/ comparison"
echo ""
echo "3. Esegui suite completa:"
echo "   ./scripts/run-hybrid-suite.sh"

echo ""
echo -e "${GREEN}‚úÖ Analisi completata!${NC}"
