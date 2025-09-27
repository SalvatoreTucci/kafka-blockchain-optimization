# Week 4: Blockchain Integration

## Overview
This directory contains the complete setup for integrating the optimal Kafka configuration (from Week 3) with Hyperledger Fabric blockchain network.

## Quick Start

```bash
# 1. Start Fabric network with optimized Kafka
cd fabric-network
./scripts/network-up.sh

# 2. Deploy and test smallbank chaincode
./scripts/chaincode-deploy.sh

# 3. Run blockchain benchmarks
cd ../benchmarks
./blockchain-test-suite.sh
```

## Optimal Configuration Applied
- **Batch Size**: 65KB (4x default) 
- **Linger Time**: 0ms (zero latency)
- **Compression**: none (no overhead)
- **Performance**: 22% latency improvement validated

## Network Architecture
- **Organizations**: 2 (Org1, Org2)
- **Peers**: 4 total (2 per org)
- **Orderer**: Kafka-based with optimal config
- **Channels**: businesschannel
- **Chaincode**: Smallbank benchmark
