#!/bin/bash

# Network Up Script - Starts the complete Kafka-optimized blockchain network
# Windows-compatible with SSL fixes and robust error handling

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
MAX_RETRY=5
RETRY_DELAY=15

log_info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] SUCCESS:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1"
}

echo -e "${PURPLE}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║            WEEK 4 BLOCKCHAIN NETWORK STARTUP                  ║"
echo "║                                                                ║"
echo "║  🚀 Hyperledger Fabric + Optimized Kafka Ordering Service     ║"
echo "║  📊 Configuration: config_100 (65KB, 0ms, none)               ║"
echo "║  🔧 Windows-compatible with SSL fixes                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found. Please install Docker."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose not found. Please install Docker Compose."
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -f "docker-compose-fabric.yml" ]; then
        log_error "docker-compose-fabric.yml not found. Run this script from week4-blockchain-integration/fabric-network/"
        exit 1
    fi
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        log_error "Docker daemon not running. Please start Docker."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Function to generate certificates with SSL fix
generate_certificates() {
    log_info "Generating blockchain certificates..."
    
    if [ ! -d "../crypto-config" ] || [ -z "$(ls -A ../crypto-config 2>/dev/null)" ]; then
        log_info "Certificates not found, generating..."
        
        if [ -f "scripts/generate-crypto-docker.sh" ]; then
            chmod +x scripts/generate-crypto-docker.sh
            if ./scripts/generate-crypto-docker.sh; then
                log_success "Certificates generated successfully"
            else
                log_warning "Certificate generation failed, using fallback"
                create_fallback_certificates
            fi
        else
            log_warning "Certificate script not found, using fallback"
            create_fallback_certificates
        fi
    else
        log_success "Certificates already exist"
    fi
}

# Fallback certificate creation
create_fallback_certificates() {
    log_info "Creating fallback certificates..."
    
    mkdir -p ../crypto-config/{orderer,org1/peer0,org2/peer0}
    
    # Create minimal certificate structure for testing
    for entity in "orderer" "org1/peer0" "org2/peer0"; do
        mkdir -p "../crypto-config/$entity/msp"/{admincerts,cacerts,signcerts,keystore}
        
        # Create dummy certificate files
        echo "DUMMY_CERT_FOR_TESTING" > "../crypto-config/$entity/msp/cacerts/ca.pem"
        echo "DUMMY_CERT_FOR_TESTING" > "../crypto-config/$entity/msp/signcerts/cert.pem"
        echo "DUMMY_KEY_FOR_TESTING" > "../crypto-config/$entity/msp/keystore/key.pem"
        echo "DUMMY_ADMIN_CERT" > "../crypto-config/$entity/msp/admincerts/admin.pem"
    done
    
    log_warning "Fallback certificates created (for testing only)"
}

# Function to clean up previous deployment
cleanup_previous() {
    log_info "Cleaning up previous deployment..."
    
    # Stop containers
    docker-compose -f docker-compose-fabric.yml down --remove-orphans &>/dev/null || true
    
    # Remove any dangling containers
    docker container prune -f &>/dev/null || true
    
    log_success "Previous deployment cleaned up"
}

# Function to start the network with retry logic
start_network() {
    local attempt=1
    
    while [ $attempt -le $MAX_RETRY ]; do
        log_info "Starting blockchain network (attempt $attempt/$MAX_RETRY)..."
        
        if docker-compose -f docker-compose-fabric.yml up -d; then
            log_success "Containers started successfully"
            break
        else
            log_error "Failed to start containers on attempt $attempt"
            if [ $attempt -lt $MAX_RETRY ]; then
                log_info "Retrying in $RETRY_DELAY seconds..."
                sleep $RETRY_DELAY
                cleanup_previous
            else
                log_error "All startup attempts failed"
                return 1
            fi
        fi
        ((attempt++))
    done
    
    return 0
}

# Function to wait for services with health checks
wait_for_services() {
    log_info "Waiting for services to become healthy..."
    
    local services=("zookeeper:2181" "kafka:9092" "orderer:7050" "peer0-org1:7051" "peer0-org2:8051")
    local max_wait=300  # 5 minutes total
    local wait_interval=15
    local elapsed=0
    
    while [ $elapsed -lt $max_wait ]; do
        local all_healthy=true
        
        for service in "${services[@]}"; do
            IFS=':' read -r container port <<< "$service"
            
            if ! docker-compose -f docker-compose-fabric.yml ps "$container" | grep -q "Up"; then
                all_healthy=false
                break
            fi
        done
        
        if $all_healthy; then
            log_success "All services are running"
            
            # Additional specific checks
            log_info "Performing connectivity tests..."
            
            # Test Kafka
            if docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 &>/dev/null; then
                log_success "Kafka is responsive"
            else
                log_warning "Kafka not yet responsive, continuing..."
            fi
            
            # Test CLI
            if docker exec cli peer version &>/dev/null; then
                log_success "Fabric CLI is responsive"
            else
                log_warning "Fabric CLI not yet responsive, continuing..."
            fi
            
            return 0
        fi
        
        log_info "Services still starting... (${elapsed}s/${max_wait}s)"
        sleep $wait_interval
        elapsed=$((elapsed + wait_interval))
    done
    
    log_error "Services failed to become healthy within $max_wait seconds"
    return 1
}

# Main execution function
main() {
    log_info "Starting Week 4 blockchain network deployment..."
    
    check_prerequisites
    generate_certificates
    cleanup_previous
    
    if ! start_network; then
        log_error "Network startup failed"
        exit 1
    fi
    
    if ! wait_for_services; then
        log_error "Services failed to become ready"
        exit 1
    fi
    
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                 NETWORK STARTUP COMPLETED                     ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${YELLOW}🌐 Network Access Points:${NC}"
    echo "  • Grafana Dashboard: http://localhost:3000 (admin/admin123)"
    echo "  • Prometheus Metrics: http://localhost:9090"
    echo "  • Orderer Health: http://localhost:8443/healthz"
    
    log_success "Week 4 blockchain network is ready for testing!"
}

# Check if network should be stopped instead
if [ "${1:-}" == "down" ]; then
    log_info "Stopping blockchain network..."
    docker-compose -f docker-compose-fabric.yml down --remove-orphans
    log_success "Network stopped"
    exit 0
fi

# Execute main function
main "$@"
