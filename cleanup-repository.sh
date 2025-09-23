#!/bin/bash

# Kafka-Blockchain Optimization - Repository Cleanup Script
# Rimuove file superflui e ottimizza la struttura

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Verifica di essere nella directory corretta
if [[ ! -f "README.md" ]] || [[ ! -d ".git" ]]; then
    log_error "Questo script deve essere eseguito nella root del repository"
    exit 1
fi

log_info "=== Pulizia Repository Kafka-Blockchain Optimization ==="

# Backup prima della pulizia
log_info "Creando backup..."
git stash push -m "Backup before cleanup $(date)" || true

# Array di file da rimuovere (se esistono)
declare -a FILES_TO_REMOVE=(
    # Script obsoleti
    "scripts/test/run-benchmark.py"
    "scripts/deploy/deploy-baseline.sh"
    "scripts/test/simple-producer-test.py"
    "scripts/monitoring/setup-monitoring.sh"
    "scripts/test/kafka-producer-test.py"
    "scripts/test/kafka-consumer-test.py"
    
    # Configurazioni ridondanti
    "configs/.env.development"
    "configs/.env.production"  
    "configs/kafka-only.yml"
    "configs/docker-compose.kafka-only.yml"
    
    # Documentazione obsoleta
    "docs/old-setup-guide.md"
    "docs/kafka-only-approach.md"
    "docs/simple-setup.md"
    "docs/legacy/"
    
    # File di test temporanei
    "test-results.txt"
    "kafka-test-output.log"
    "benchmark-results.json"
    
    # File IDE/editor
    ".vscode/launch.json"
    ".idea/"
    "*.swp"
    "*.swo"
    "*~"
)

# Array di directory vuote da rimuovere
declare -a EMPTY_DIRS=(
    "scripts/legacy"
    "configs/old"
    "docs/deprecated"
    "test"
    "scripts/test" # Solo se vuota dopo pulizia
)

# Rimuovi file
log_info "Rimuovendo file superflui..."
removed_count=0

for file in "${FILES_TO_REMOVE[@]}"; do
    if [[ -e "$file" ]]; then
        if [[ -f "$file" ]]; then
            git rm "$file" 2>/dev/null || rm "$file"
            log_success "Rimosso file: $file"
            ((removed_count++))
        elif [[ -d "$file" ]]; then
            git rm -r "$file" 2>/dev/null || rm -rf "$file"
            log_success "Rimossa directory: $file"
            ((removed_count++))
        fi
    fi
done

# Rimuovi directory vuote
log_info "Rimuovendo directory vuote..."
for dir in "${EMPTY_DIRS[@]}"; do
    if [[ -d "$dir" ]] && [[ -z "$(ls -A "$dir")" ]]; then
        rmdir "$dir"
        log_success "Rimossa directory vuota: $dir"
        ((removed_count++))
    fi
done

# Pulizia file temporanei pattern-based
log_info "Pulizia file temporanei..."

# Rimuovi file di log temporanei
find . -name "*.log" -not -path "./results/*" -not -path "./.git/*" -delete 2>/dev/null || true

# Rimuovi file backup temporanei
find . -name "*.bak" -not -path "./.git/*" -delete 2>/dev/null || true
find . -name "*.tmp" -not -path "./.git/*" -delete 2>/dev/null || true

# Rimuovi file Python cache
find . -name "__pycache__" -type d -not -path "./.git/*" -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -not -path "./.git/*" -delete 2>/dev/null || true

# Assicurati che le directory essenziali esistano
log_info "Verificando struttura directory essenziali..."

declare -a ESSENTIAL_DIRS=(
    "configs"
    "scripts"  
    "docs"
    "results"
    "blockchain"
    "configs/prometheus"
    "configs/grafana"
    "configs/grafana/dashboards"
    "docs/papers-analysis"
    "docs/papers-analysis/detailed-analyses"
    "blockchain/chaincode"
    "blockchain/crypto-config"
    "blockchain/config"
)

for dir in "${ESSENTIAL_DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_success "Creata directory: $dir"
    fi
done

# Crea .gitkeep per directory vuote importanti
touch results/.gitkeep
touch blockchain/chaincode/.gitkeep
touch blockchain/crypto-config/.gitkeep
touch configs/grafana/dashboards/.gitkeep

# Aggiorna .gitignore se necessario
log_info "Aggiornando .gitignore..."

cat > .gitignore << 'EOF'
# Environment files
.env
.env.local
.env.*.local

# Results and logs
results/*.json
results/*.txt
results/*.log
results/*/
!results/.gitkeep

# Docker volumes
docker-volumes/

# Blockchain generated files
blockchain/crypto-config/*
!blockchain/crypto-config/.gitkeep
blockchain/chaincode/vendor/

# IDE files
.vscode/
.idea/
*.swp
*.swo
*~

# Python
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
env/
venv/
.venv/

# OS files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Temporary files
*.tmp
*.bak
*.log
!docker-compose.yml
!*/prometheus.yml
