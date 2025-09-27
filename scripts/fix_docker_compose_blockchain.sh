#!/bin/bash

# Fix docker-compose-blockchain.yml per rimuovere dependency problematica

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Fix Docker Compose Blockchain${NC}"

# Trova rete Kafka
KAFKA_NETWORK=$(docker network ls | grep kafka | awk '{print $2}' | head -1)
if [ -z "$KAFKA_NETWORK" ]; then
    echo -e "${RED}❌ Rete Kafka non trovata!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Rete Kafka trovata: $KAFKA_NETWORK${NC}"

# Crea docker-compose-blockchain.yml corretto (senza dependencies problematiche)
echo -e "${YELLOW}Creando docker-compose-blockchain.yml corretto...${NC}"

cat > docker-compose-blockchain.yml << EOF
version: '3.8'

networks:
  kafka-existing:
    external:
      name: $KAFKA_NETWORK

volumes:
  orderer-data:
  peer0-org1-data:

services:
  # Orderer senza dependency su kafka (usa solo rete)
  orderer:
    image: hyperledger/fabric-orderer:2.4.7
    container_name: orderer
    hostname: orderer.example.com
    networks:
      - kafka-existing
    ports:
      - "7050:7050"
    environment:
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_LISTENPORT=7050
      - ORDERER_GENERAL_GENESISMETHOD=file
      - ORDERER_GENERAL_GENESISFILE=/var/hyperledger/orderer/genesis.block
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/var/hyperledger/orderer/msp
      - ORDERER_GENERAL_TLS_ENABLED=false
      
      # Kafka Integration (connessione diretta via rete)
      - ORDERER_KAFKA_BROKERS=[kafka:29092]
      - ORDERER_KAFKA_TOPIC_REPLICATIONFACTOR=1
      - ORDERER_KAFKA_VERBOSE=true
      
      # Timeouts per stabilità
      - ORDERER_GENERAL_KEEPALIVE_SERVERMININTERVAL=60s
      - ORDERER_GENERAL_KEEPALIVE_SERVERTIMEOUT=20s
      
      # Batch settings ottimizzati
      - ORDERER_GENERAL_BATCHSIZE_MAXMESSAGECOUNT=10
      - ORDERER_GENERAL_BATCHSIZE_ABSOLUTEMAXBYTES=1048576
      - ORDERER_GENERAL_BATCHSIZE_PREFERREDMAXBYTES=524288
      - ORDERER_GENERAL_BATCHTIMEOUT=2s
      
    volumes:
      - ./blockchain-config/genesis.block:/var/hyperledger/orderer/genesis.block:ro
      - ./blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp:/var/hyperledger/orderer/msp:ro
      - orderer-data:/var/hyperledger/production/orderer
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "sh", "-c", "netstat -lnp | grep :7050 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # Peer semplificato
  peer0-org1:
    image: hyperledger/fabric-peer:2.4.7
    container_name: peer0-org1
    hostname: peer0.org1.example.com
    networks:
      - kafka-existing
    ports:
      - "7051:7051"
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=$KAFKA_NETWORK
      - FABRIC_LOGGING_SPEC=INFO
      - CORE_PEER_TLS_ENABLED=false
      - CORE_PEER_ID=peer0.org1.example.com
      - CORE_PEER_ADDRESS=peer0.org1.example.com:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_LOCALMSPID=Org1MSP
      
      # Semplificazioni per testing
      - CORE_PEER_GOSSIP_USELEADERELECTION=false
      - CORE_PEER_GOSSIP_ORGLEADER=true
      - CORE_PEER_PROFILE_ENABLED=false
      
    volumes:
      - /var/run/:/host/var/run/
      - ./blockchain-config/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp:/etc/hyperledger/fabric/msp:ro
      - peer0-org1-data:/var/hyperledger/production
    restart: unless-stopped

  # CLI semplificato
  cli:
    image: hyperledger/fabric-tools:2.4.7
    container_name: cli
    hostname: cli
    networks:
      - kafka-existing
    tty: true
    stdin_open: true
    environment:
      - GOPATH=/opt/gopath
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - FABRIC_LOGGING_SPEC=INFO
      - CORE_PEER_ID=cli
      - CORE_PEER_ADDRESS=peer0.org1.example.com:7051
      - CORE_PEER_LOCALMSPID=Org1MSP
      - CORE_PEER_TLS_ENABLED=false
      
      # Path semplificati
      - CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
      
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: /bin/bash -c 'sleep 3600'
    volumes:
      - /var/run/:/host/var/run/
      - ./chaincodes:/opt/gopath/src/github.com/chaincode:ro
      - ./blockchain-config/crypto-config:/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/:ro
    restart: unless-stopped
EOF

echo -e "${GREEN}✅ docker-compose-blockchain.yml corretto creato${NC}"

# Test validazione YAML
if docker-compose -f docker-compose-blockchain.yml config >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Configurazione YAML valida${NC}"
else
    echo -e "${RED}❌ Errore nella configurazione YAML${NC}"
    exit 1
fi

# Test avvio singolo servizio
echo -e "${YELLOW}Test avvio orderer...${NC}"
docker-compose -f docker-compose-blockchain.yml up -d orderer

sleep 20

# Verifica che orderer sia avviato
if docker ps | grep orderer | grep -q "Up"; then
    echo -e "${GREEN}✅ Orderer avviato con successo${NC}"
    
    # Verifica logs per connessione Kafka
    if docker logs orderer 2>&1 | grep -q "Starting orderer\|Beginning to serve\|kafka"; then
        echo -e "${GREEN}✅ Orderer operational${NC}"
    else
        echo -e "${YELLOW}⚠️ Orderer logs:${NC}"
        docker logs orderer --tail=5
    fi
else
    echo -e "${RED}❌ Orderer non avviato${NC}"
    docker logs orderer --tail=10
    exit 1
fi

# Test connectivity Kafka
echo -e "${YELLOW}Test connettività Kafka dall'orderer...${NC}"
if docker exec orderer ping -c 1 kafka >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Orderer può pingare Kafka${NC}"
else
    echo -e "${YELLOW}⚠️ Ping a Kafka fallito (normale se no ping nel container)${NC}"
fi

echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                ✅ FIX COMPLETATO!                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}Status containers:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "kafka|orderer"

echo ""
echo -e "${YELLOW}Ora riprova il test:${NC}"
echo -e "${GREEN}./simple-integration-test.sh${NC}"

echo ""
echo -e "${GREEN}🎯 Docker-compose blockchain corretto e testato!${NC}"
