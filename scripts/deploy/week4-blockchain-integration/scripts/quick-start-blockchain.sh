#!/bin/bash
set -e

echo "🚀 Quick Start: Week 4 Blockchain Integration"
cd "$(dirname "$0")/../fabric-network"

echo "📋 Step 1: Starting Fabric network..."
./scripts/network-up.sh

echo "📦 Step 2: Basic chaincode test..."
if docker exec cli peer version &>/dev/null; then
    echo "✅ CLI ready for chaincode deployment"
else
    echo "⚠️  CLI not ready, use manual deployment later"
fi

echo ""
echo "🎉 Week 4 environment ready!"
echo "📊 Applied Kafka optimizations: 65KB batch, 0ms linger, no compression"
echo "🔍 Next: Deploy chaincode and run blockchain tests"
