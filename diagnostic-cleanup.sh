#!/bin/bash

# Diagnostic and Complete Repository Cleanup Script
# Checks current state and completes the optimization

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

# Check current repository state
log_info "=== DIAGNOSING CURRENT REPOSITORY STATE ==="

echo "📁 Current directory structure:"
echo "=================="
find . -maxdepth 3 -type f -name "*.sh" -o -name "*.py" -o -name ".env*" -o -name "*.yml" -o -name "*.yaml" | sort
echo "=================="
echo ""

# Count files by type
echo "📊 File count analysis:"
echo "Scripts (.sh): $(find . -name "*.sh" | wc -l)"
echo "Python files (.py): $(find . -name "*.py" | wc -l)"
echo "Environment files (.env*): $(find . -name ".env*" | wc -l)"
echo "Docker files: $(find . -name "docker-compose*" -o -name "Dockerfile*" | wc -l)"
echo "Config files (.yml/.yaml): $(find . -name "*.yml" -o -name "*.yaml" | wc -l)"
echo ""

# Check for specific redundant files still present
log_info "🔍 Checking for files that should be removed..."

declare -a REDUNDANT_FILES=(
    "corrected-optimization-test.sh"
    "working-optimized-test.sh" 
    "fixed-network-test.sh"
    "fix-windows-environment.sh"
    "configs/.env.optimized2"
    "configs/.env.optimized3"
    "configs/.env.compression"
    "docker-compose.yml.backup"
    "cleanup-repository.sh"
    "benchmarks/smallbank-config.yml"
    "docker/base/Dockerfile.test"
    "configs/kafka/server.properties"
    "configs/monitoring/jmx_exporter_config.yml"
)

echo "Files still present that should be removed:"
found_redundant=0
for file in "${REDUNDANT_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "  ❌ $file"
        ((found_redundant++))
    fi
done

if [[ $found_redundant -eq 0 ]]; then
    log_success "No redundant files found - cleanup already effective!"
else
    log_warning "Found $found_redundant files that should be removed"
fi

echo ""

# Check for essential files
log_info "✅ Checking for essential files..."
declare -a ESSENTIAL_FILES=(
    ".env.default"
    ".env.batch-optimized" 
    ".env.compression-optimized"
    ".env.high-throughput"
    "docker-compose.yml"
    "scripts/simple-kafka-test.sh"
    "scripts/run-complete-test.sh"
    "scripts/setup-simple-environment.sh"
)

missing_essential=0
for file in "${ESSENTIAL_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "  ✅ $file"
    else
        echo "  ❌ MISSING: $file"
        ((missing_essential++))
    fi
done

if [[ $missing_essential -gt 0 ]]; then
    log_error "Missing $missing_essential essential files!"
fi

echo ""

# Interactive cleanup
log_info "🧹 INTERACTIVE CLEANUP"
echo "Do you want to:"
echo "1. Remove remaining redundant files"
echo "2. Clean temporary files (.log, .bak, __pycache__)"
echo "3. Update .gitignore"
echo "4. All of the above"
echo "5. Skip cleanup"

read -p "Choose option (1-5): " choice

case $choice in
    1|4)
        log_info "Removing redundant files..."
        removed=0
        for file in "${REDUNDANT_FILES[@]}"; do
            if [[ -f "$file" ]]; then
                git rm "$file" 2>/dev/null || rm "$file"
                log_success "Removed: $file"
                ((removed++))
            elif [[ -d "$file" ]]; then
                git rm -r "$file" 2>/dev/null || rm -rf "$file" 
                log_success "Removed directory: $file"
                ((removed++))
            fi
        done
        echo "Removed $removed redundant files/directories"
        ;&
    2|4)
        log_info "Cleaning temporary files..."
        # Clean temporary files more aggressively
        temp_removed=0
        
        # Remove log files (except in results/)
        for logfile in $(find . -name "*.log" -not -path "./results/*" -not -path "./.git/*"); do
            rm "$logfile"
            ((temp_removed++))
        done
        
        # Remove backup files
        for bakfile in $(find . -name "*.bak" -not -path "./.git/*"); do
            rm "$bakfile"
            ((temp_removed++))
        done
        
        # Remove Python cache
        for pycache in $(find . -name "__pycache__" -type d -not -path "./.git/*"); do
            rm -rf "$pycache"
            ((temp_removed++))
        done
        
        # Remove .pyc files
        for pycfile in $(find . -name "*.pyc" -not -path "./.git/*"); do
            rm "$pycfile"
            ((temp_removed++))
        done
        
        echo "Removed $temp_removed temporary files"
        ;&
    3|4)
        log_info "Updating .gitignore..."
        cat > .gitignore << 'EOF'
# Environment files
.env
.env.local
.env.*.local
!.env.default
!.env.batch-optimized
!.env.compression-optimized
!.env.high-throughput

# Results and logs  
results/*.json
results/*.txt
results/*.log
results/*/
!results/.gitkeep
!results/README.md

# Docker volumes and data
docker-volumes/
kafka-data/
zk-data/
prometheus-data/
grafana-data/

# Blockchain generated files
blockchain-config/crypto-config/*
!blockchain-config/crypto-config/.gitkeep

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
Thumbs.db

# Temporary files
*.tmp
*.bak
*.log
*.backup
EOF
        log_success "Updated .gitignore"
        ;&
esac

if [[ $choice -eq 4 ]]; then
    # Create essential directories
    log_info "Ensuring essential directories..."
    mkdir -p results configs/prometheus configs/grafana/provisioning
    touch results/.gitkeep configs/prometheus/.gitkeep configs/grafana/.gitkeep
    
    # Update README if needed
    if [[ ! -f "README.md" ]] || ! grep -q "Kafka Optimization for Blockchain" README.md; then
        log_info "Creating optimized README.md..."
        cat > README.md << 'EOF'
# Kafka Optimization for Blockchain Consensus

## 🎯 Research Objective
Systematic optimization of Apache Kafka parameters for blockchain workloads.

## 🚀 Quick Start
```bash
# Setup environment
./scripts/setup-simple-environment.sh

# Run baseline test  
./scripts/simple-kafka-test.sh .env.default

# Run comparison tests
./scripts/run-complete-test.sh
```

## 📁 Repository Structure
- `configs/` - Kafka configuration files
- `scripts/` - Test and setup scripts  
- `results/` - Test results (gitignored)
- `docker-compose.yml` - Docker environment

## 🧪 Test Configurations
1. **Baseline** (`.env.default`) - Default Kafka settings
2. **Batch Optimized** - Larger batch sizes
3. **Compression Optimized** - Network efficiency
4. **High Throughput** - Maximum performance

## 📈 Monitoring
- Grafana: http://localhost:3000 (admin/admin123)
- Prometheus: http://localhost:9090
EOF
        log_success "Created optimized README.md"
    fi
fi

echo ""
log_info "=== FINAL REPOSITORY STATE ==="

# Show final structure
echo "📁 Optimized structure:"
echo "Essential configuration files:"
ls -la .env* 2>/dev/null || echo "No .env files found"

echo ""
echo "Essential scripts:"
find scripts/ -name "*.sh" -o -name "*.py" | head -10

echo ""
echo "Repository size:"
echo "Total files: $(find . -type f | wc -l)"
echo "Size: $(du -sh . | cut -f1)"

echo ""
echo "🎯 OPTIMIZATION COMPLETE!"
echo ""
echo "Next steps:"
echo "1. Review changes: git status"
echo "2. Test environment: ./scripts/setup-simple-environment.sh"  
echo "3. Commit changes: git add -A && git commit -m 'Optimize repository structure'"
echo ""
log_success "Repository is now optimized and ready for research!"