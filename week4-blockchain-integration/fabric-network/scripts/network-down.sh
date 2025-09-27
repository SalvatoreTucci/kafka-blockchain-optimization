#!/bin/bash

# Network Down Script - Safely shuts down the blockchain network

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] SUCCESS:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1"
}

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║               WEEK 4 BLOCKCHAIN NETWORK SHUTDOWN              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to stop the network gracefully
stop_network() {
    local clean_volumes=$1
    
    log_info "Stopping blockchain network..."
    
    if [ -f "docker-compose-fabric.yml" ]; then
        if [ "$clean_volumes" = "true" ]; then
            log_warning "Stopping network and cleaning volumes (data will be lost)"
            docker-compose -f docker-compose-fabric.yml down --remove-orphans -v
        else
            log_info "Stopping network (preserving data volumes)"
            docker-compose -f docker-compose-fabric.yml down --remove-orphans
        fi
        
        log_success "Network stopped successfully"
    else
        log_warning "docker-compose-fabric.yml not found"
    fi
}

# Parse command line arguments
clean_volumes="${CLEAN_VOLUMES:-false}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean-all|--reset)
            clean_volumes="true"
            export CLEAN_CRYPTO="true"
            log_warning "Full reset mode: All data and certificates will be removed"
            ;;
        --clean-volumes)
            clean_volumes="true"
            ;;
        -h|--help)
            echo "Network Down - Week 4 Blockchain Network Shutdown"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --clean-all, --reset    Remove all data, volumes, and certificates"
            echo "  --clean-volumes         Remove data volumes (blockchain data lost)"
            echo "  -h, --help             Show this help message"
            exit 0
            ;;
    esac
    shift
done

# Execute shutdown
stop_network "$clean_volumes"

if [ "${CLEAN_CRYPTO:-}" = "true" ]; then
    log_info "Cleaning certificates..."
    rm -rf ../crypto-config/*
    log_success "Certificates removed"
fi

log_success "Week 4 blockchain network shutdown completed!"
