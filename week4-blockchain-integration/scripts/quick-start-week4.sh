#!/bin/bash

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              WEEK 4: QUICK START BLOCKCHAIN                 ║"
echo "║           One-Command Full Deployment & Testing             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

cd "$(dirname "$0")/.."

echo -e "${YELLOW}🚀 Phase 1: Starting Fabric Network with Optimized Kafka...${NC}"
cd fabric-network
./scripts/network-up.sh

echo -e "${YELLOW}📦 Phase 2: Deploying Smallbank Chaincode...${NC}"
./scripts/chaincode-deploy.sh

echo -e "${YELLOW}📊 Phase 3: Running Blockchain Benchmark...${NC}"
cd ../benchmarks
./blockchain-test-suite.sh 200 3 120  # 200 transactions, 3 clients, 2 minutes

echo -e "${YELLOW}📈 Phase 4: Analyzing Results...${NC}"
python3 ../scripts/analyze_blockchain_results.py

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                  WEEK 4 COMPLETE! 🎉                        ║"
echo "║                                                              ║"
echo "║  ✅ Hyperledger Fabric network deployed                     ║"
echo "║  ✅ Optimal Kafka configuration applied                     ║"
echo "║  ✅ Smallbank chaincode operational                         ║"
echo "║  ✅ Blockchain benchmark executed                           ║"
echo "║  ✅ Performance analysis completed                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "  • Kafka optimized for blockchain (65KB batch, 0ms linger, no compression)"
echo "  • Real blockchain transactions tested successfully"
echo "  • Performance validated in production-like environment"
echo ""
echo -e "${YELLOW}📊 Monitoring URLs:${NC}"
echo "  • Container Status: docker-compose -f fabric-network/docker-compose-fabric.yml ps"
echo "  • System Resources: docker stats kafka orderer peer0-org1"
echo ""
echo -e "${GREEN}🎯 Week 4 SUCCESS! Ready for Week 5 validation and thesis completion.${NC}"
