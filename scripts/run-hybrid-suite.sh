#!/bin/bash

# Kafka-Blockchain Optimization - Hybrid Test Suite
# Esegue una suite completa di test ibridi Kafka + Blockchain

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_ROOT/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SUITE_DIR="$RESULTS_DIR/hybrid_suite_$TIMESTAMP"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzioni utility
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configurazioni da testare
declare -a CONFIGS=(
    ".env.default:baseline"
    ".env.optimized1:high_throughput"
    ".env.optimized2:low_latency"
    ".env.optimized3:balanced"
    ".env.compression:compression_focused"
)

# Verifica prerequisiti
check_prerequisites() {
    log_info "Verificando prerequisiti..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker non installato"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose non installato"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon non in esecuzione"
        exit 1
    fi
    
    log_success "Prerequisiti verificati"
}

# Cleanup ambiente precedente
cleanup_environment() {
    log_info "Cleanup ambiente precedente..."
    cd "$PROJECT_ROOT"
    
    # Stop tutti i container
    docker-compose down -v --remove-orphans 2>/dev/null || true
    
    # Rimuovi networks orfani
    docker network prune -f 2>/dev/null || true
    
    # Rimuovi volumi orfani
    docker volume prune -f 2>/dev/null || true
    
    sleep 5
    log_success "Cleanup completato"
}

# Setup environment
setup_environment() {
    log_info "Setup ambiente ibrido..."
    cd "$PROJECT_ROOT"
    
    # Esegui setup ambiente
    if [[ -f "scripts/setup-simple-environment.sh" ]]; then
        chmod +x scripts/setup-simple-environment.sh
        ./scripts/setup-simple-environment.sh
    else
        log_error "Script setup-simple-environment.sh non trovato"
        exit 1
    fi
    
    log_success "Ambiente setup completato"
}

# Esegui test singolo
run_single_test() {
    local config_file="$1"
    local test_name="$2"
    local iteration="$3"
    
    log_info "Eseguendo test: $test_name (iterazione $iteration)"
    
    # Directory per questo test
    local test_dir="$SUITE_DIR/${test_name}_iter${iteration}"
    mkdir -p "$test_dir"
    
    cd "$PROJECT_ROOT"
    
    # Copia file di configurazione
    if [[ -f "configs/$config_file" ]]; then
        cp "configs/$config_file" .env
    else
        log_warning "File configurazione $config_file non trovato, uso default"
        cp ".env.default" .env || touch .env
    fi
    
    # Restart environment con nuova config
    docker-compose down -v 2>/dev/null || true
    sleep 10
    docker-compose up -d
    
    # Aspetta stabilizzazione
    log_info "Aspettando stabilizzazione ambiente (60s)..."
    sleep 60
    
    # Verifica servizi
    if ! docker-compose ps | grep -q "Up"; then
        log_error "Alcuni servizi non sono attivi"
        docker-compose logs --tail=20
        return 1
    fi
    
    # Esegui test ibrido
    if [[ -f "scripts/hybrid-full-test.sh" ]]; then
        chmod +x scripts/hybrid-full-test.sh
        
        # Esegui test e salva risultati
        timeout 300 ./scripts/hybrid-full-test.sh .env "$test_name" 2>&1 | tee "$test_dir/test_output.log"
        local test_exit_code=${PIPESTATUS[0]}
        
        if [[ $test_exit_code -eq 0 ]]; then
            log_success "Test $test_name completato con successo"
            
            # Copia risultati se esistono
            if [[ -d "results/$test_name" ]]; then
                cp -r "results/$test_name"/* "$test_dir/" 2>/dev/null || true
            fi
            
            # Salva metriche container
            docker stats --no-stream > "$test_dir/docker_stats.txt" 2>/dev/null || true
            
            # Salva logs importanti
            docker-compose logs kafka > "$test_dir/kafka.log" 2>/dev/null || true
            docker-compose logs prometheus > "$test_dir/prometheus.log" 2>/dev/null || true
            
        else
            log_error "Test $test_name fallito (exit code: $test_exit_code)"
            return 1
        fi
    else
        log_error "Script hybrid-full-test.sh non trovato"
        return 1
    fi
    
    return 0
}

# Esegui suite completa
run_test_suite() {
    log_info "Iniziando suite di test ibridi..."
    
    # Crea directory risultati
    mkdir -p "$SUITE_DIR"
    
    # Salva info sistema
    {
        echo "=== System Information ==="
        date
        echo "Docker version: $(docker --version)"
        echo "Docker Compose version: $(docker-compose --version)"
        echo "Available memory: $(free -h | grep '^Mem:' | awk '{print $7}')"
        echo "Available disk: $(df -h . | tail -1 | awk '{print $4}')"
        echo ""
    } > "$SUITE_DIR/system_info.txt"
    
    local total_tests=0
    local successful_tests=0
    local failed_tests=0
    
    # Esegui test per ogni configurazione
    for config_entry in "${CONFIGS[@]}"; do
        IFS=':' read -r config_file test_name <<< "$config_entry"
        
        log_info "=== Testing configurazione: $test_name ==="
        
        # Esegui 3 iterazioni per ogni configurazione
        for iteration in {1..3}; do
            total_tests=$((total_tests + 1))
            
            if run_single_test "$config_file" "$test_name" "$iteration"; then
                successful_tests=$((successful_tests + 1))
            else
                failed_tests=$((failed_tests + 1))
                log_warning "Test fallito, continuando con il prossimo..."
            fi
            
            # Pausa tra test
            sleep 30
        done
        
        # Pausa più lunga tra configurazioni diverse
        sleep 60
    done
    
    # Riepilogo risultati
    {
        echo "=== Test Suite Summary ==="
        echo "Data: $(date)"
        echo "Configurazioni testate: ${#CONFIGS[@]}"
        echo "Test totali eseguiti: $total_tests"
        echo "Test riusciti: $successful_tests"
        echo "Test falliti: $failed_tests"
        echo "Tasso di successo: $(( successful_tests * 100 / total_tests ))%"
        echo ""
        echo "Risultati salvati in: $SUITE_DIR"
    } | tee "$SUITE_DIR/summary.txt"
    
    log_success "Suite completata! Risultati in: $SUITE_DIR"
}

# Analizza risultati
analyze_results() {
    log_info "Analizzando risultati..."
    
    if [[ -f "scripts/compare-hybrid-results.py" ]]; then
        cd "$PROJECT_ROOT"
        python3 scripts/compare-hybrid-results.py "$SUITE_DIR" hybrid 2>/dev/null || {
            log_warning "Analisi Python fallita, genero report manuale"
            
            # Report semplice
            {
                echo "=== Quick Analysis ==="
                echo "Directory analizzata: $SUITE_DIR"
                echo "Subdirectory trovate:"
                find "$SUITE_DIR" -type d -name "*_iter*" | sort
                echo ""
                echo "File di output trovati:"
                find "$SUITE_DIR" -name "*.log" -o -name "*.txt" -o -name "*.json" | sort
            } > "$SUITE_DIR/quick_analysis.txt"
        }
    else
        log_warning "Script di analisi non trovato"
    fi
}

# Main execution
main() {
    log_info "=== Kafka-Blockchain Hybrid Test Suite ==="
    log_info "Timestamp: $TIMESTAMP"
    
    # Trappola per cleanup su exit
    trap 'log_info "Cleaning up..."; cleanup_environment' EXIT
    
    check_prerequisites
    cleanup_environment
    setup_environment
    run_test_suite
    analyze_results
    
    log_success "Suite hybrid completa!"
    log_info "Risultati disponibili in: $SUITE_DIR"
    
    # Mostra accesso dashboard
    echo ""
    echo "=== Dashboard Monitoring ==="
    echo "Grafana: http://localhost:3000 (admin/admin123)"
    echo "Prometheus: http://localhost:9090"
    echo ""
}

# Verifica se script chiamato direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi