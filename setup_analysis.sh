#!/bin/bash

# Setup script per l'analisi Python dei benchmark Kafka

set -e

# Colori per output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════╗"
echo "║       SETUP ANALISI PYTHON BENCHMARK KAFKA        ║"
echo "╚════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Verifica Python
echo -e "${YELLOW}🐍 Verificando Python...${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}✅ ${PYTHON_VERSION} trovato${NC}"
else
    echo -e "${RED}❌ Python3 non installato!${NC}"
    echo "Installare Python3 prima di continuare"
    exit 1
fi

# Verifica pip
echo -e "${YELLOW}📦 Verificando pip...${NC}"
if command -v pip3 &> /dev/null; then
    echo -e "${GREEN}✅ pip3 disponibile${NC}"
else
    echo -e "${RED}❌ pip3 non trovato!${NC}"
    echo "Installare pip3: sudo apt install python3-pip"
    exit 1
fi

# Installa dipendenze
echo -e "${YELLOW}📚 Installando dipendenze Python...${NC}"

# Lista delle dipendenze necessarie
DEPENDENCIES=(
    "matplotlib>=3.5.0"
    "pandas>=1.3.0" 
    "seaborn>=0.11.0"
    "numpy>=1.21.0"
)

echo "Dipendenze da installare:"
for dep in "${DEPENDENCIES[@]}"; do
    echo "  - $dep"
done
echo

# Chiedi conferma
read -p "Procedere con l'installazione? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installazione annullata"
    exit 0
fi

# Installa ogni dipendenza
for dep in "${DEPENDENCIES[@]}"; do
    echo -e "${YELLOW}📦 Installando $dep...${NC}"
    if pip3 install "$dep" --user; then
        echo -e "${GREEN}✅ $dep installato${NC}"
    else
        echo -e "${RED}❌ Errore installando $dep${NC}"
        echo "Prova: pip3 install $dep --user --break-system-packages"
    fi
done

echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════╗"
echo "║                 SETUP COMPLETATO!                 ║"
echo "╚════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Testa l'installazione
echo -e "${YELLOW}🧪 Testando l'installazione...${NC}"

python3 -c "
try:
    import matplotlib.pyplot as plt
    import pandas as pd
    import seaborn as sns
    import numpy as np
    print('✅ Tutte le dipendenze importate correttamente!')
    
    # Test creazione grafico semplice
    plt.figure(figsize=(6,4))
    plt.plot([1,2,3], [1,4,2])
    plt.title('Test Plot')
    plt.close()
    print('✅ Test matplotlib riuscito!')
    
except ImportError as e:
    print(f'❌ Errore import: {e}')
    print('Alcune dipendenze potrebbero non essere installate correttamente')
    exit(1)
" || echo -e "${RED}❌ Test fallito - verificare l'installazione${NC}"

echo
echo -e "${BLUE}📋 ISTRUZIONI USO:${NC}"
echo
echo -e "${YELLOW}1. Esegui benchmark completo:${NC}"
echo -e "   ./kafka-complete-benchmark.sh"
echo
echo -e "${YELLOW}2. Analizza i risultati:${NC}"
echo -e "   python3 analyze_benchmark_results.py [directory_risultati]"
echo
echo -e "${YELLOW}3. Oppure (auto-detect directory più recente):${NC}"
echo -e "   python3 analyze_benchmark_results.py"
echo
echo -e "${GREEN}🎯 Setup completato! Pronto per l'analisi dei benchmark Kafka.${NC}"