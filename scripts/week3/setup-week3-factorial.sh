#!/bin/bash

# Setup completo Week 3: Factorial Design
# Installa dipendenze, verifica prerequisiti, prepara environment

set -e

# Colori
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              SETUP WEEK 3: FACTORIAL DESIGN                   ║"
echo "║       Installazione dipendenze e verifica prerequisiti        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Step 1: Verifica Python base
echo -e "${YELLOW}Step 1: Verifica Python base...${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}✅ ${PYTHON_VERSION} disponibile${NC}"
else
    echo -e "${RED}❌ Python3 non installato!${NC}"
    exit 1
fi

if command -v pip3 &> /dev/null; then
    echo -e "${GREEN}✅ pip3 disponibile${NC}"
else
    echo -e "${RED}❌ pip3 non trovato!${NC}"
    exit 1
fi

# Step 2: Installa dipendenze base (se non già installate)
echo -e "${YELLOW}Step 2: Verifica/installa dipendenze base...${NC}"
BASE_DEPS=("matplotlib" "pandas" "seaborn" "numpy")
for dep in "${BASE_DEPS[@]}"; do
    if python3 -c "import $dep" 2>/dev/null; then
        echo -e "${GREEN}✅ $dep già installato${NC}"
    else
        echo -e "${YELLOW}📦 Installando $dep...${NC}"
        pip3 install "$dep" --user --quiet
    fi
done

# Step 3: Installa dipendenze statistiche avanzate
echo -e "${YELLOW}Step 3: Installa dipendenze statistiche avanzate...${NC}"
ADVANCED_DEPS=("scipy" "statsmodels")
for dep in "${ADVANCED_DEPS[@]}"; do
    if python3 -c "import $dep" 2>/dev/null; then
        echo -e "${GREEN}✅ $dep già installato${NC}"
    else
        echo -e "${YELLOW}📦 Installando $dep...${NC}"
        pip3 install "$dep" --user --quiet
    fi
done

# Step 4: Test importazione completa
echo -e "${YELLOW}Step 4: Test importazione dipendenze...${NC}"
python3 -c "
try:
    import matplotlib.pyplot as plt
    import pandas as pd
    import seaborn as sns
    import numpy as np
    import scipy.stats
    import statsmodels.api as sm
    print('✅ Tutte le dipendenze importate correttamente!')
    
    # Test creazione plot
    import matplotlib
    matplotlib.use('Agg')  # Non-interactive backend per server
    plt.figure(figsize=(6,4))
    plt.plot([1,2,3], [1,4,2])
    plt.close()
    print('✅ Test matplotlib riuscito!')
    
except ImportError as e:
    print(f'❌ Errore import: {e}')
    exit(1)
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Test dipendenze superato!${NC}"
else
    echo -e "${RED}❌ Test dipendenze fallito${NC}"
    exit 1
fi

# Step 5: Verifica prerequisiti progetto
echo -e "${YELLOW}Step 5: Verifica prerequisiti progetto...${NC}"

# Docker
if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✅ Docker e Docker Compose disponibili${NC}"
else
    echo -e "${RED}❌ Docker o Docker Compose non installati!${NC}"
    exit 1
fi

# Script base
if [ -f "scripts/simple-kafka-test.sh" ]; then
    echo -e "${GREEN}✅ Script base simple-kafka-test.sh trovato${NC}"
    chmod +x scripts/simple-kafka-test.sh
else
    echo -e "${RED}❌ Script simple-kafka-test.sh non trovato!${NC}"
    echo "Assicurati di essere nella directory corretta del progetto"
    exit 1
fi

# Step 6: Verifica script factorial (se esistono)
echo -e "${YELLOW}Step 6: Verifica script factorial...${NC}"

if [ -f "kafka-factorial-benchmark.sh" ]; then
    echo -e "${GREEN}✅ Script factorial benchmark trovato${NC}"
    chmod +x kafka-factorial-benchmark.sh
else
    echo -e "${YELLOW}⚠️  Script kafka-factorial-benchmark.sh non trovato${NC}"
    echo "Crealo dal template fornito"
fi

if [ -f "analyze_factorial_results.py" ]; then
    echo -e "${GREEN}✅ Script analisi factorial trovato${NC}"
    chmod +x analyze_factorial_results.py 2>/dev/null || true
else
    echo -e "${YELLOW}⚠️  Script analyze_factorial_results.py non trovato${NC}"
    echo "Crealo dal template fornito"
fi

# Step 7: Test ambiente Docker
echo -e "${YELLOW}Step 7: Test ambiente Docker...${NC}"
if docker-compose ps &> /dev/null; then
    echo -e "${GREEN}✅ Docker Compose funzionante${NC}"
    
    # Check se ci sono container attivi
    if docker-compose ps | grep -q "Up"; then
        echo -e "${GREEN}✅ Ambiente Kafka attivo${NC}"
    else
        echo -e "${YELLOW}⚠️  Ambiente Kafka non attivo (normale se non in uso)${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Docker Compose non configurato in questa directory${NC}"
    echo "Assicurati di avere docker-compose.yml nel progetto"
fi

# Step 8: Verifica spazio disco
echo -e "${YELLOW}Step 8: Verifica spazio disco...${NC}"
AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}' | sed 's/[^0-9.]//g')
if (( $(echo "$AVAILABLE_SPACE > 5" | bc -l 2>/dev/null || echo 0) )); then
    echo -e "${GREEN}✅ Spazio disco sufficiente (${AVAILABLE_SPACE}GB disponibili)${NC}"
else
    echo -e "${YELLOW}⚠️  Spazio disco limitato. Factorial design genererà ~1-2GB dati${NC}"
fi

# Step 9: Setup completato
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    SETUP COMPLETATO!                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}📋 SUMMARY INSTALLAZIONE:${NC}"
echo -e "${GREEN}✅ Python3 e pip3 verificati${NC}"
echo -e "${GREEN}✅ Dipendenze matplotlib, pandas, seaborn, numpy${NC}"
echo -e "${GREEN}✅ Dipendenze statistiche scipy, statsmodels${NC}"
echo -e "${GREEN}✅ Docker environment verificato${NC}"
echo -e "${GREEN}✅ Script di base verificati${NC}"

echo ""
echo -e "${YELLOW}🚀 PROSSIMI STEP:${NC}"
echo ""
echo -e "${BLUE}1. Se non hai ancora creato i script factorial:${NC}"
echo -e "   Crea 'kafka-factorial-benchmark.sh' e 'analyze_factorial_results.py'"
echo ""
echo -e "${BLUE}2. Per eseguire factorial design completo:${NC}"
echo -e "${YELLOW}   ./kafka-factorial-benchmark.sh 3 300 1000${NC}"
echo -e "   (8 config × 3 runs × 5 min = ~2 ore)"
echo ""
echo -e "${BLUE}3. Per analizzare risultati:${NC}"
echo -e "${YELLOW}   python3 analyze_factorial_results.py factorial_results_TIMESTAMP${NC}"
echo ""

echo -e "${GREEN}🎯 Environment Week 3 pronto per Factorial Design!${NC}"