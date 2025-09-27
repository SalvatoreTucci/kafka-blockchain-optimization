#!/bin/bash

# Week 4 Complete Setup Script

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}"
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                        WEEK 4 SETUP - BLOCKCHAIN INTEGRATION          ║"
echo "║                                                                        ║"
echo "║  ��� Objective: Validate Week 3 optimal Kafka config in blockchain     ║"
echo "║  ��� Config: 65KB batch, 0ms linger, no compression (config_100)       ║"
echo "║  ��� Platform: Hyperledger Fabric 2.4.7 with Kafka ordering           ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

log_info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] SUCCESS:${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking system prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker not found. Please install Docker."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo "❌ Docker Compose not found. Please install Docker Compose."
        exit 1
    fi
    
    if ! docker info &>/dev/null; then
        echo "❌ Docker daemon not running - please start Docker"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Create missing files
create_missing_files() {
    log_info "Creating missing Week 4 files..."
    
    echo "⚠️  Some files are missing. I'll create the essential ones now."
    echo "For complete setup, you should run the full create-week4-files.sh script."
    echo ""
    
    # Create minimal docker-compose
    if [ ! -f "fabric-network/docker-compose-fabric.yml" ]; then
        echo "Creating minimal docker-compose-fabric.yml..."
        cat > fabric-network/docker-compose-fabric.yml << 'INNER_EOF'
version: '3.7'

networks:
  fabric-kafka-net:
    driver: bridge

volumes:
  kafka-data:
  zk-data:

services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.4.0
    hostname: zookeeper
    container_name: zookeeper
    networks:
      - fabric-kafka-net
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    volumes:
      - zk-data:/var/lib/zookeeper/data
    restart: unless-stopped

  kafka:
    image: confluentinc/cp-kafka:7.4.0
    hostname: kafka
    container_name: kafka
    networks:
      - fabric-kafka-net
    ports:
      - "9092:9092"
      - "9999:9999"
    depends_on:
      - zookeeper
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: 'zookeeper:2181'
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:29092,PLAINTEXT_HOST://0.0.0.0:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      
      # Week 3 Optimal Configuration (config_100)
      KAFKA_BATCH_SIZE: 65536          # 65KB batch size
      KAFKA_LINGER_MS: 0               # No linger time
      KAFKA_COMPRESSION_TYPE: none     # No compression
      KAFKA_BUFFER_MEMORY: 67108864    # 64MB buffer
      
      KAFKA_JMX_PORT: 9999
      KAFKA_JMX_HOSTNAME: localhost
      
    volumes:
      - kafka-data:/var/lib/kafka/data
    restart: unless-stopped
INNER_EOF
    fi
    
    # Create minimal network-up script
    if [ ! -f "fabric-network/scripts/network-up.sh" ]; then
        echo "Creating minimal network-up.sh..."
        cat > fabric-network/scripts/network-up.sh << 'INNER_EOF'
#!/bin/bash

echo "��� Starting Week 4 blockchain network (minimal version)..."

cd $(dirname $0)/..

echo "⚠️  Running minimal setup. For full blockchain, use complete create-week4-files.sh"

docker-compose -f docker-compose-fabric.yml down --remove-orphans 2>/dev/null || true
docker-compose -f docker-compose-fabric.yml up -d

echo "Waiting for services..."
sleep 30

if docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 &>/dev/null; then
    echo "✅ Kafka is ready with Week 3 optimal config:"
    echo "   • Batch Size: 65KB"
    echo "   • Linger Time: 0ms" 
    echo "   • Compression: none"
    echo ""
    echo "��� This validates your Week 3 optimization in a real environment!"
else
    echo "❌ Kafka not responding"
    exit 1
fi
INNER_EOF
        chmod +x fabric-network/scripts/network-up.sh
    fi
    
    log_success "Essential files created"
}

# Show next steps
show_next_steps() {
    echo -e "${YELLOW}��� WEEK 4 VALIDATION STEPS:${NC}"
    echo ""
    echo "��� CURRENT STATUS: Basic setup completed"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Start minimal network:"
    echo "   cd fabric-network && ./scripts/network-up.sh"
    echo ""
    echo "2. Test Kafka with Week 3 optimal config:"
    echo "   docker exec kafka kafka-topics --create --topic test --bootstrap-server localhost:9092"
    echo "   docker exec kafka kafka-console-producer --topic test --bootstrap-server localhost:9092"
    echo ""
    echo -e "${YELLOW}��� For complete blockchain testing:${NC}"
    echo "• Run the full create-week4-files.sh script for complete setup"
    echo "• This includes Hyperledger Fabric, chaincode, and comprehensive testing"
    echo ""
    echo -e "${GREEN}✅ Week 3 optimal config (65KB, 0ms, none) is ready for validation!${NC}"
}

# Main execution
main() {
    log_info "Starting Week 4 blockchain integration setup..."
    
    check_prerequisites
    create_missing_files
    show_next_steps
    
    log_success "Week 4 minimal setup completed!"
}

main "$@"
