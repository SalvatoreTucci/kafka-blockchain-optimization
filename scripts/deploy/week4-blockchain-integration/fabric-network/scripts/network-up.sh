#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "🚀 Starting Hyperledger Fabric network with optimized Kafka..."
echo "🐳 Using Docker-based approach for Windows compatibility..."

# Clean previous artifacts
rm -rf organizations channel-artifacts/*.block channel-artifacts/*.tx 2>/dev/null || true
mkdir -p channel-artifacts

# Create crypto materials directory structure
echo "🔐 Creating crypto materials structure..."
mkdir -p organizations/{ordererOrganizations,peerOrganizations}
mkdir -p organizations/ordererOrganizations/orderer.example.com/{msp/{admincerts,cacerts,keystore,signcerts,tlscacerts},orderers/orderer.example.com/msp/{admincerts,cacerts,keystore,signcerts,tlscacerts}}
mkdir -p organizations/peerOrganizations/org1.example.com/{msp/{admincerts,cacerts,keystore,signcerts,tlscacerts,config.yaml},peers/peer0.org1.example.com/msp/{admincerts,cacerts,keystore,signcerts,tlscacerts},users/Admin@org1.example.com/msp/{admincerts,cacerts,keystore,signcerts,tlscacerts}}
mkdir -p organizations/peerOrganizations/org2.example.com/{msp/{admincerts,cacerts,keystore,signcerts,tlscacerts,config.yaml},peers/peer0.org2.example.com/msp/{admincerts,cacerts,keystore,signcerts,tlscacerts},users/Admin@org2.example.com/msp/{admincerts,cacerts,keystore,signcerts,tlscacerts}}

# Generate certificates with OpenSSL
echo "🔐 Generating certificates with OpenSSL..."

generate_cert() {
    local name=$1
    local org=$2
    local dir=$3
    
    openssl genrsa -out "$dir/keystore/key.pem" 2048 2>/dev/null
    openssl req -new -x509 -key "$dir/keystore/key.pem" \
        -out "$dir/signcerts/cert.pem" -days 365 \
        -subj "/CN=$name.$org.example.com/O=$org/C=US" 2>/dev/null
    cp "$dir/signcerts/cert.pem" "$dir/cacerts/ca.pem"
    cp "$dir/signcerts/cert.pem" "$dir/admincerts/admin.pem"
}

# Generate all certificates
generate_cert "orderer" "orderer" "organizations/ordererOrganizations/orderer.example.com/orderers/orderer.example.com/msp"
generate_cert "orderer" "orderer" "organizations/ordererOrganizations/orderer.example.com/msp"
generate_cert "peer0" "org1" "organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp"
generate_cert "admin" "org1" "organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp"
generate_cert "org1" "org1" "organizations/peerOrganizations/org1.example.com/msp"
generate_cert "peer0" "org2" "organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/msp"
generate_cert "admin" "org2" "organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp"
generate_cert "org2" "org2" "organizations/peerOrganizations/org2.example.com/msp"

# Create config.yaml for NodeOUs
cat > organizations/peerOrganizations/org1.example.com/msp/config.yaml << 'CONFIG_EOF'
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/ca.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/ca.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/ca.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/ca.pem
    OrganizationalUnitIdentifier: orderer
CONFIG_EOF

cp organizations/peerOrganizations/org1.example.com/msp/config.yaml organizations/peerOrganizations/org2.example.com/msp/config.yaml

echo "✅ Certificates generated successfully"

# Generate channel artifacts using Docker
echo "📋 Generating channel artifacts using Docker..."
docker run --rm -v "$(pwd)":/workspace -w /workspace hyperledger/fabric-tools:2.4.7 configtxgen -profile OrdererGenesis -outputBlock channel-artifacts/genesis.block -channelID system-channel
docker run --rm -v "$(pwd)":/workspace -w /workspace hyperledger/fabric-tools:2.4.7 configtxgen -profile ChannelConfig -outputCreateChannelTx channel-artifacts/businesschannel.tx -channelID businesschannel

echo "✅ Channel artifacts created successfully"

# Start the network
echo "🐳 Starting Docker containers..."
docker-compose -f docker-compose-fabric.yml down -v 2>/dev/null || true
docker-compose -f docker-compose-fabric.yml up -d

echo "⏳ Waiting for services to initialize..."
sleep 60

echo "🎉 Fabric network started successfully!"
echo "📊 Container Status:"
docker-compose -f docker-compose-fabric.yml ps
