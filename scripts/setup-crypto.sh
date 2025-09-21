#!/bin/bash

# Setup script for Hyperledger Fabric crypto materials and genesis block
# This script generates the necessary certificates and configuration files

set -e

echo "Setting up Hyperledger Fabric crypto materials..."

# Create necessary directories
mkdir -p configs/crypto-config
mkdir -p configs/channel-artifacts

# Download Hyperledger Fabric binaries if not present
FABRIC_VERSION=2.4.7
if [ ! -f bin/cryptogen ]; then
    echo "Downloading Hyperledger Fabric binaries..."
    curl -sSL https://bit.ly/2ysbOFE | bash -s -- $FABRIC_VERSION $FABRIC_VERSION 0.5.4
    mv fabric-samples/bin ./
    mv fabric-samples/config ./
    rm -rf fabric-samples
fi

# Create crypto-config.yaml
cat > configs/crypto-config.yaml << EOF
OrdererOrgs:
  - Name: Orderer
    Domain: example.com
    Specs:
      - Hostname: orderer

PeerOrgs:
  - Name: Org1
    Domain: org1.example.com
    Template:
      Count: 2
    Users:
      Count: 1

  - Name: Org2
    Domain: org2.example.com
    Template:
      Count: 2
    Users:
      Count: 1
EOF

# Generate crypto materials
echo "Generating crypto materials..."
./bin/cryptogen generate --config=configs/crypto-config.yaml --output=configs/crypto-config

# Create configtx.yaml for genesis block
cat > configs/configtx.yaml << EOF
Organizations:
  - &OrdererOrg
    Name: OrdererOrg
    ID: OrdererMSP
    MSPDir: crypto-config/ordererOrganizations/example.com/msp
    Policies:
      Readers:
        Type: Signature
        Rule: "OR('OrdererMSP.member')"
      Writers:
        Type: Signature
        Rule: "OR('OrdererMSP.member')"
      Admins:
        Type: Signature
        Rule: "OR('OrdererMSP.admin')"

  - &Org1
    Name: Org1MSP
    ID: Org1MSP
    MSPDir: crypto-config/peerOrganizations/org1.example.com/msp
    Policies:
      Readers:
        Type: Signature
        Rule: "OR('Org1MSP.admin', 'Org1MSP.peer', 'Org1MSP.client')"
      Writers:
        Type: Signature
        Rule: "OR('Org1MSP.admin', 'Org1MSP.client')"
      Admins:
        Type: Signature
        Rule: "OR('Org1MSP.admin')"
    AnchorPeers:
      - Host: peer0.org1.example.com
        Port: 7051

  - &Org2
    Name: Org2MSP
    ID: Org2MSP
    MSPDir: crypto-config/peerOrganizations/org2.example.com/msp
    Policies:
      Readers:
        Type: Signature
        Rule: "OR('Org2MSP.admin', 'Org2MSP.peer', 'Org2MSP.client')"
      Writers:
        Type: Signature
        Rule: "OR('Org2MSP.admin', 'Org2MSP.client')"
      Admins:
        Type: Signature
        Rule: "OR('Org2MSP.admin')"
    AnchorPeers:
      - Host: peer0.org2.example.com
        Port: 9051

Capabilities:
  Channel: &ChannelCapabilities
    V2_0: true
  Orderer: &OrdererCapabilities
    V2_0: true
  Application: &ApplicationCapabilities
    V2_0: true

Application: &ApplicationDefaults
  Organizations:
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
    LifecycleEndorsement:
      Type: ImplicitMeta
      Rule: "MAJORITY Endorsement"
    Endorsement:
      Type: ImplicitMeta
      Rule: "MAJORITY Endorsement"
  Capabilities:
    <<: *ApplicationCapabilities

Orderer: &OrdererDefaults
  OrdererType: kafka
  Addresses:
    - orderer.example.com:7050
  
  # Kafka Configuration
  Kafka:
    Brokers:
      - kafka1:9092
      - kafka2:9093
      - kafka3:9094

  BatchTimeout: 2s
  BatchSize:
    MaxMessageCount: 100
    AbsoluteMaxBytes: 99 MB
    PreferredMaxBytes: 512 KB

  Organizations:
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
    BlockValidation:
      Type: ImplicitMeta
      Rule: "ANY Writers"

Channel: &ChannelDefaults
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
  Capabilities:
    <<: *ChannelCapabilities

Profiles:
  KafkaOrdererGenesis:
    <<: *ChannelDefaults
    Capabilities:
      <<: *ChannelCapabilities
    Orderer:
      <<: *OrdererDefaults
      Organizations:
        - *OrdererOrg
      Capabilities:
        <<: *OrdererCapabilities
    Consortiums:
      SampleConsortium:
        Organizations:
          - *Org1
          - *Org2

  TwoOrgsChannel:
    Consortium: SampleConsortium
    <<: *ChannelDefaults
    Application:
      <<: *ApplicationDefaults
      Organizations:
        - *Org1
        - *Org2
      Capabilities:
        <<: *ApplicationCapabilities
EOF

# Generate genesis block
echo "Generating genesis block..."
export FABRIC_CFG_PATH=\$PWD/configs
./bin/configtxgen -profile KafkaOrdererGenesis -outputBlock configs/genesis.block

# Generate channel configuration
echo "Generating channel configuration..."
./bin/configtxgen -profile TwoOrgsChannel -outputCreateChannelTx configs/channel-artifacts/channel.tx -channelID mychannel

# Generate anchor peer updates
./bin/configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate configs/channel-artifacts/Org1MSPanchors.tx -channelID mychannel -asOrg Org1MSP
./bin/configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate configs/channel-artifacts/Org2MSPanchors.tx -channelID mychannel -asOrg Org2MSP

echo "Crypto setup completed successfully!"
echo "Generated files:"
echo "  - configs/crypto-config/ (certificates)"
echo "  - configs/genesis.block (genesis block)"
echo "  - configs/channel-artifacts/ (channel configurations)"