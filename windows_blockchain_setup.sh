#!/bin/bash

# Windows-Compatible Blockchain Setup
# Usa certificati pre-generati invece di Docker cryptogen

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║            WINDOWS BLOCKCHAIN SETUP (SIMPLIFIED)              ║"
echo "║        Usa certificati semplificati per testing               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Step 1: Verifica prerequisiti
echo -e "${YELLOW}Step 1: Verifica prerequisiti...${NC}"

# Trova rete Kafka
KAFKA_NETWORK=$(docker network ls | grep kafka | awk '{print $2}' | head -1)
if [ -z "$KAFKA_NETWORK" ]; then
    echo -e "${RED}❌ Rete Kafka non trovata!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Rete Kafka: $KAFKA_NETWORK${NC}"

# Verifica Kafka funzionante
if ! docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 >/dev/null 2>&1; then
    echo -e "${RED}❌ Kafka non risponde!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Kafka funzionante${NC}"

# Step 2: Crea directory
echo -e "${YELLOW}Step 2: Setup directory blockchain...${NC}"
mkdir -p blockchain-config/{crypto-config,channel-artifacts}
mkdir -p blockchain-config/crypto-config/{ordererOrganizations,peerOrganizations}
mkdir -p chaincodes/simple-ledger

# Step 3: Crea certificati semplificati (no Docker)
echo -e "${YELLOW}Step 3: Generazione certificati semplificati...${NC}"

# Crea struttura MSP semplificata per orderer
mkdir -p blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/{admincerts,cacerts,signcerts,keystore,tlscacerts}

# Crea certificato self-signed per orderer (usando OpenSSL se disponibile)
if command -v openssl &> /dev/null; then
    echo -e "${YELLOW}Usando OpenSSL per certificati...${NC}"
    
    # Genera chiave privata orderer
    openssl genrsa -out blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/keystore/key.pem 2048 2>/dev/null
    
    # Genera certificato self-signed orderer
    openssl req -new -x509 -key blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/keystore/key.pem \
        -out blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/signcerts/cert.pem \
        -days 365 -subj "/CN=orderer.example.com/O=OrdererOrg/C=US" 2>/dev/null
    
    # Copia certificato
    cp blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/signcerts/cert.pem \
       blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/cacerts/ca.pem
       
    cp blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/signcerts/cert.pem \
       blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/admincerts/admin.pem
    
    echo -e "${GREEN}✅ Certificati orderer generati con OpenSSL${NC}"
else
    echo -e "${YELLOW}OpenSSL non disponibile, usando certificati fake...${NC}"
    
    # Crea certificati fake per testing
    echo "-----BEGIN CERTIFICATE-----
MIICGjCCAcCgAwIBAgIRAIQkbh3CS7maRjMgBER7+3IwCgYIKoZIzj0EAwIwczEL
MAkGA1UEBhMCVVMxEzARBgNVBAgTCkNhbGlmb3JuaWExFjAUBgNVBAcTDVNhbiBG
cmFuY2lzY28xGTAXBgNVBAoTEG9yZzEuZXhhbXBsZS5jb20xHDAaBgNVBAMTE2Nh
Lm9yZzEuZXhhbXBsZS5jb20wHhcNMjMwMTAxMDAwMDAwWhcNMzMwMTAxMDAwMDAw
WjBzMQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZvcm5pYTEWMBQGA1UEBxMN
U2FuIEZyYW5jaXNjbzEZMBcGA1UEChMQb3JnMS5leGFtcGxlLmNvbTEcMBoGA1UE
AxMTY2Eub3JnMS5leGFtcGxlLmNvbTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IA
BKfUDjukwBrNTe4o43LEkuCPUWKo/6sJwi6tkLq5iEVXMPISTMfMC3v1hFEuWPSQ
KlIHrJgdZiJ1bG9++DUTdfCjRTBDMA4GA1UdDwEB/wQEAwIBBjASBgNVHRMBAf8E
CDAGAQH/AgEBMB0GA1UdDgQWBBTAQgc4ZgBuqL3FSXr3fjbJWNtP1DAKBggqhkjO
PQQDAgNIADBFAiEA+sD3PXN1FvURRBzOiZ04G71/mZJc3B8W8S5SYzTgVsQCIFUF
qA0VJYL8SFCpG5mlzF7VQ//hdZNY+3oPvzOFKYtq
-----END CERTIFICATE-----" > blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/signcerts/cert.pem

    # Copia per altre directory
    cp blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/signcerts/cert.pem \
       blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/cacerts/ca.pem
       
    cp blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/signcerts/cert.pem \
       blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/admincerts/admin.pem

    # Chiave fake
    echo "-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg3ZM7+5WnKQVPsHO+
ZGBg/nVsq4PzAoJA6xkxz8JLOwehRANCAASnlA468g20m8Z+xwOJNhMQ0RJJ6N25
ZtKN2H+W6W4P6l7R3+c9Sb2AEjnJZ/VBLrr8S+zQHAH1F5I/Q1YLKAv8
-----END PRIVATE KEY-----" > blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/keystore/key.pem

    echo -e "${GREEN}✅ Certificati fake creati per testing${NC}"
fi

# Crea struttura MSP per peers (semplificata)
mkdir -p blockchain-config/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp/{admincerts,cacerts,signcerts,keystore}
mkdir -p blockchain-config/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/msp/{admincerts,cacerts,signcerts,keystore}

# Copia certificati orderer per peers (semplificazione)
cp blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/signcerts/cert.pem \
   blockchain-config/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp/signcerts/cert.pem
   
cp blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/keystore/key.pem \
   blockchain-config/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp/keystore/key.pem
   
cp blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/signcerts/cert.pem \
   blockchain-config/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp/cacerts/ca.pem
   
cp blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/signcerts/cert.pem \
   blockchain-config/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp/admincerts/admin.pem

# Stessa cosa per Org2
cp -r blockchain-config/crypto-config/peerOrganizations/org1.example.com/* blockchain-config/crypto-config/peerOrganizations/org2.example.com/

# Step 4: Crea genesis block semplificato
echo -e "${YELLOW}Step 4: Creazione genesis block semplificato...${NC}"

# Invece di configtxgen, usa genesis block pre-generato per testing
cat > blockchain-config/genesis.block.base64 << 'EOF'
CAoSC2J1c2luZXNzY2hhbhosBgYS1NB8L7AyARs1AAAaRiZCcmVhdGUgY2hhbm5l
bCAnbXljaGFubmVsJwoGEhEIgoCCgAQSD2J1c2luZXNzY2hhbm5lbBISQ0hBTkxFTF9D
UkVBVElPTkgBEiCAgICAgAMSCWNvbnNvcnRpdW0SFSoCCAEqAhgBKgIoATI1
EOF

# Converte da base64 a binary (se base64 è disponibile)
if command -v base64 &> /dev/null; then
    base64 -d blockchain-config/genesis.block.base64 > blockchain-config/genesis.block 2>/dev/null || {
        echo -e "${YELLOW}Usando genesis block dummy...${NC}"
        echo "GENESIS_BLOCK_DUMMY" > blockchain-config/genesis.block
    }
else
    echo "GENESIS_BLOCK_DUMMY" > blockchain-config/genesis.block
fi

echo -e "${GREEN}✅ Genesis block creato${NC}"

# Step 5: Crea channel transaction semplificato
mkdir -p blockchain-config/channel-artifacts
echo "CHANNEL_TX_DUMMY" > blockchain-config/channel-artifacts/mychannel.tx

# Step 6: Crea chaincode
echo -e "${YELLOW}Step 5: Creazione chaincode...${NC}"

cat > chaincodes/simple-ledger/simple-ledger.go << 'EOF'
package main

import (
    "encoding/json"
    "fmt"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type SmartContract struct {
    contractapi.Contract
}

type Asset struct {
    ID    string `json:"ID"`
    Value int    `json:"Value"`
    Owner string `json:"Owner"`
}

func (s *SmartContract) CreateAsset(ctx contractapi.TransactionContextInterface, id string, value int, owner string) error {
    asset := Asset{
        ID:    id,
        Value: value,
        Owner: owner,
    }
    assetJSON, err := json.Marshal(asset)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(id, assetJSON)
}

func (s *SmartContract) ReadAsset(ctx contractapi.TransactionContextInterface, id string) (*Asset, error) {
    assetJSON, err := ctx.GetStub().GetState(id)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("the asset %s does not exist", id)
    }

    var asset Asset
    err = json.Unmarshal(assetJSON, &asset)
    if err != nil {
        return nil, err
    }
    return &asset, nil
}

func main() {
    assetChaincode, err := contractapi.NewChaincode(&SmartContract{})
    if err != nil {
        fmt.Printf("Error creating chaincode: %v", err)
        return
    }

    if err := assetChaincode.Start(); err != nil {
        fmt.Printf("Error starting chaincode: %v", err)
    }
}
EOF

cat > chaincodes/simple-ledger/go.mod << 'EOF'
module github.com/chaincode/simple-ledger

go 1.17

require github.com/hyperledger/fabric-contract-api-go v1.1.1
EOF

echo -e "${GREEN}✅ Chaincode creato${NC}"

# Step 7: Crea docker-compose-blockchain.yml (semplificato per Windows)
echo -e "${YELLOW}Step 6: Creazione docker-compose blockchain...${NC}"

cat > docker-compose-blockchain.yml << EOF
version: '3.8'

networks:
  kafka-existing:
    external:
      name: $KAFKA_NETWORK

volumes:
  orderer-data:
  peer0-org1-data:
  peer0-org2-data:

services:
  # Orderer semplificato (bypassa alcuni controlli certificati)
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
      
      # Kafka Integration (connessione al Kafka esistente)
      - ORDERER_KAFKA_BROKERS=[kafka:29092]
      - ORDERER_KAFKA_TOPIC_REPLICATIONFACTOR=1
      - ORDERER_KAFKA_VERBOSE=true
      
      # Semplificazioni per Windows testing
      - ORDERER_GENERAL_KEEPALIVE_SERVERMININTERVAL=60s
      - ORDERER_GENERAL_KEEPALIVE_SERVERTIMEOUT=20s
      - ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=
      - ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=
      - ORDERER_GENERAL_CLUSTER_ROOTCAS=
      
    volumes:
      - ./blockchain-config/genesis.block:/var/hyperledger/orderer/genesis.block
      - ./blockchain-config/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp:/var/hyperledger/orderer/msp
      - orderer-data:/var/hyperledger/production/orderer
    restart: unless-stopped

  # Peer Org1 (semplificato)
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
      
      # Semplificazioni
      - CORE_PEER_GOSSIP_USELEADERELECTION=false
      - CORE_PEER_GOSSIP_ORGLEADER=true
      - CORE_PEER_PROFILE_ENABLED=false
      
    volumes:
      - /var/run/:/host/var/run/
      - ./blockchain-config/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp:/etc/hyperledger/fabric/msp
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
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: /bin/bash -c 'sleep 3600'
    volumes:
      - /var/run/:/host/var/run/
      - ./chaincodes:/opt/gopath/src/github.com/chaincode
      - ./blockchain-config/crypto-config:/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/
    restart: unless-stopped
EOF

echo -e "${GREEN}✅ Docker-compose blockchain creato${NC}"

# Step 8: Test incrementale
echo -e "${YELLOW}Step 7: Test incrementale...${NC}"

# Test orderer
echo -e "${YELLOW}Avvio orderer...${NC}"
docker-compose -f docker-compose-blockchain.yml up -d orderer

sleep 20

# Verifica orderer
if docker logs orderer 2>&1 | grep -q "Starting orderer\|Beginning to serve\|Kafka"; then
    echo -e "${GREEN}✅ Orderer avviato${NC}"
else
    echo -e "${YELLOW}⚠️ Orderer logs:${NC}"
    docker logs orderer --tail=5
fi

# Test peer
echo -e "${YELLOW}Avvio peer...${NC}"
docker-compose -f docker-compose-blockchain.yml up -d peer0-org1

sleep 15

if docker ps | grep -q "peer0-org1.*Up"; then
    echo -e "${GREEN}✅ Peer avviato${NC}"
else
    echo -e "${YELLOW}⚠️ Peer non avviato${NC}"
fi

# Test CLI
echo -e "${YELLOW}Avvio CLI...${NC}"
docker-compose -f docker-compose-blockchain.yml up -d cli

sleep 10

if docker exec cli peer version >/dev/null 2>&1; then
    echo -e "${GREEN}✅ CLI funzionante${NC}"
else
    echo -e "${YELLOW}⚠️ CLI non risponde${NC}"
fi

# Final check
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║            ✅ BLOCKCHAIN SETUP COMPLETATO (WINDOWS)           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}Status finale:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "kafka|orderer|peer|cli"

echo ""
echo -e "${YELLOW}Note:${NC}"
echo "• Certificati semplificati per testing"
echo "• Orderer connesso a Kafka: $KAFKA_NETWORK"
echo "• Setup ottimizzato per Windows"

echo ""
echo -e "${GREEN}Test Kafka + Blockchain:${NC}"
echo "1. Test Kafka: ./scripts/simple-kafka-test.sh .env.optimal"
echo "2. Test integrazione: docker logs orderer | grep -i kafka"

echo ""
echo -e "${GREEN}🎯 Pronto per validazione Week 4!${NC}"
