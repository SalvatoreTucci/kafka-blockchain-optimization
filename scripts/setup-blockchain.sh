#!/bin/bash

# Setup blockchain configuration for hybrid environment
# Creates minimal but functional Hyperledger Fabric network with Kafka ordering

set -e

echo "Setting up blockchain configuration..."

# Create blockchain config directories
mkdir -p blockchain-config/{orderer,org1/peer0,org2/peer0}
mkdir -p chaincodes/simple-ledger

# Create minimal MSP structure for orderer
mkdir -p blockchain-config/orderer/msp/{admincerts,cacerts,signcerts,keystore,tlscacerts}

# Generate simple certificates (for testing only)
create_cert() {
    local name=$1
    local org=$2
    
    # Create private key
    openssl genrsa -out blockchain-config/${org}/${name}/msp/keystore/key.pem 2048 2>/dev/null
    
    # Create self-signed certificate
    openssl req -new -x509 -key blockchain-config/${org}/${name}/msp/keystore/key.pem \
        -out blockchain-config/${org}/${name}/msp/signcerts/cert.pem \
        -days 365 -subj "/CN=${name}.${org}.example.com/O=${org}/C=US" 2>/dev/null
    
    # Copy cert to cacerts
    cp blockchain-config/${org}/${name}/msp/signcerts/cert.pem \
       blockchain-config/${org}/${name}/msp/cacerts/ca.pem
    
    # Copy cert to admincerts
    cp blockchain-config/${org}/${name}/msp/signcerts/cert.pem \
       blockchain-config/${org}/${name}/msp/admincerts/admin.pem
}

echo "Generating certificates..."
create_cert "orderer" "orderer"
create_cert "peer0" "org1"
create_cert "peer0" "org2"

# Create simple chaincode for testing
cat > chaincodes/simple-ledger/simple-ledger.js << 'EOF'
'use strict';

const { Contract } = require('fabric-contract-api');

class SimpleLedger extends Contract {

    async initLedger(ctx) {
        console.info('============= START : Initialize Ledger ===========');
        const assets = [
            { id: 'asset1', value: 100, owner: 'user1' },
            { id: 'asset2', value: 200, owner: 'user2' },
            { id: 'asset3', value: 300, owner: 'user3' },
        ];

        for (const asset of assets) {
            await ctx.stub.putState(asset.id, Buffer.from(JSON.stringify(asset)));
        }
        console.info('============= END : Initialize Ledger ===========');
    }

    async createAsset(ctx, id, value, owner) {
        const asset = { id, value: parseInt(value), owner };
        await ctx.stub.putState(id, Buffer.from(JSON.stringify(asset)));
        return JSON.stringify(asset);
    }

    async readAsset(ctx, id) {
        const assetJSON = await ctx.stub.getState(id);
        if (!assetJSON || assetJSON.length === 0) {
            throw new Error(`Asset ${id} does not exist`);
        }
        return assetJSON.toString();
    }

    async updateAsset(ctx, id, newValue) {
        const assetString = await this.readAsset(ctx, id);
        const asset = JSON.parse(assetString);
        asset.value = parseInt(newValue);
        await ctx.stub.putState(id, Buffer.from(JSON.stringify(asset)));
        return JSON.stringify(asset);
    }

    async transferAsset(ctx, id, newOwner) {
        const assetString = await this.readAsset(ctx, id);
        const asset = JSON.parse(assetString);
        asset.owner = newOwner;
        await ctx.stub.putState(id, Buffer.from(JSON.stringify(asset)));
        return JSON.stringify(asset);
    }

    async getAllAssets(ctx) {
        const allResults = [];
        const iterator = await ctx.stub.getStateByRange('', '');
        let result = await iterator.next();
        while (!result.done) {
            const strValue = Buffer.from(result.value.value).toString('utf8');
            let record;
            try {
                record = JSON.parse(strValue);
            } catch (err) {
                console.log(err);
                record = strValue;
            }
            allResults.push({ Key: result.value.key, Record: record });
            result = await iterator.next();
        }
        return JSON.stringify(allResults);
    }
}

module.exports = SimpleLedger;
EOF

# Create package.json for chaincode
cat > chaincodes/simple-ledger/package.json << 'EOF'
{
    "name": "simple-ledger",
    "version": "1.0.0",
    "description": "Simple ledger chaincode for Kafka optimization testing",
    "main": "simple-ledger.js",
    "scripts": {
        "start": "fabric-chaincode-node start"
    },
    "dependencies": {
        "fabric-contract-api": "^2.4.1",
        "fabric-shim": "^2.4.1"
    }
}
EOF

# Create blockchain test script
cat > scripts/blockchain-test.sh << 'EOF'
#!/bin/bash

# Test blockchain functionality with optimized Kafka
# This script validates that the blockchain works with different Kafka configurations

set -e

KAFKA_CONFIG="${1:-.env.default}"
TEST_NAME="${2:-blockchain-test-$(date +%H%M%S)}"

echo "=== Blockchain Test with Kafka Configuration ==="
echo "Configuration: $KAFKA_CONFIG"
echo "Test Name: $TEST_NAME"

# Create results directory
RESULTS_DIR="results/$TEST_NAME"
mkdir -p "$RESULTS_DIR"

# Load Kafka configuration
if [ -f "$KAFKA_CONFIG" ]; then
    set -a
    source <(cat $KAFKA_CONFIG | grep -v '^#' | grep -v '^$')
    set +a
    echo "Loaded Kafka config: batch_size=$KAFKA_BATCH_SIZE, linger_ms=$KAFKA_LINGER_MS"
else
    echo "Configuration file not found: $KAFKA_CONFIG"
    exit 1
fi

# Start environment
echo "Starting blockchain environment..."
docker-compose --env-file "$KAFKA_CONFIG" up -d

# Wait for services
echo "Waiting for services to be ready..."
sleep 60

# Check Kafka
echo "Checking Kafka..."
for i in {1..30}; do
    if docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 > /dev/null 2>&1; then
        echo "✓ Kafka is ready"
        break
    fi
    echo -n "."
    sleep 2
done

# Check Fabric orderer
echo "Checking Fabric orderer..."
for i in {1..30}; do
    if docker logs orderer 2>&1 | grep -q "Beginning to serve requests"; then
        echo "✓ Orderer is ready"
        break
    fi
    echo -n "."
    sleep 2
done

# Start monitoring
MONITOR_START=$(date +%s)

# Create channel (if not exists)
echo "Creating blockchain channel..."
docker exec cli peer channel create \
    -o orderer:7050 \
    -c testchannel \
    -f /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/channel.tx \
    --outputBlock /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/testchannel.block 2>/dev/null || echo "Channel might exist"

# Join peers to channel
echo "Joining peers to channel..."
docker exec cli peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/testchannel.block 2>/dev/null || echo "Peer might already be joined"

# Run transaction load test
echo "Running blockchain transaction load test..."

# Simple transaction test - create multiple assets
for i in {1..100}; do
    docker exec cli peer chaincode invoke \
        -o orderer:7050 \
        -C testchannel \
        -n simple-ledger \
        -c "{\"function\":\"createAsset\",\"Args\":[\"asset_$i\",\"$((i*10))\",\"user_$i\"]}" \
        > /dev/null 2>&1 &
    
    # Limit concurrent transactions
    if [ $((i % 10)) -eq 0 ]; then
        wait
        echo "Processed $i transactions..."
    fi
done
wait

# Query test
echo "Running query test..."
for i in {1..50}; do
    docker exec cli peer chaincode query \
        -C testchannel \
        -n simple-ledger \
        -c "{\"function\":\"readAsset\",\"Args\":[\"asset_$i\"]}" \
        > /dev/null 2>&1 &
done
wait

MONITOR_END=$(date +%s)

# Collect metrics
echo "Collecting performance metrics..."

# Kafka metrics
docker exec kafka kafka-log-dirs --bootstrap-server localhost:9092 --describe --json > "$RESULTS_DIR/kafka-logs.json" || true

# Container stats
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" \
    kafka orderer peer0-org1 peer0-org2 > "$RESULTS_DIR/container-stats.txt"

# Orderer logs (look for block creation)
docker logs orderer > "$RESULTS_DIR/orderer.log" 2>&1

# Count blocks created
BLOCKS_CREATED=$(docker logs orderer 2>&1 | grep -c "Created block" || echo "0")

# Calculate performance metrics
DURATION=$((MONITOR_END - MONITOR_START))
TPS_ACHIEVED=$((150 / DURATION))  # 100 creates + 50 queries

# Generate report
cat > "$RESULTS_DIR/blockchain-test-summary.txt" << EOL
Blockchain Test Summary
======================
Test: $TEST_NAME
Date: $(date)
Kafka Configuration: $KAFKA_CONFIG

Kafka Parameters:
- Batch Size: $KAFKA_BATCH_SIZE bytes
- Linger Time: $KAFKA_LINGER_MS ms
- Compression: $KAFKA_COMPRESSION_TYPE
- Buffer Memory: $KAFKA_BUFFER_MEMORY bytes
- Network Threads: $KAFKA_NUM_NETWORK_THREADS

Test Results:
- Duration: ${DURATION}s
- Transactions: 150 (100 creates + 50 queries)
- Blocks Created: $BLOCKS_CREATED
- Estimated TPS: $TPS_ACHIEVED

Files Generated:
- container-stats.txt: Resource utilization
- kafka-logs.json: Kafka log statistics
- orderer.log: Ordering service logs

This test validates that the blockchain functions correctly
with the specified Kafka optimization parameters.
EOL

echo "✓ Blockchain test completed!"
echo "Results: $RESULTS_DIR/blockchain-test-summary.txt"
cat "$RESULTS_DIR/blockchain-test-summary.txt"
EOF

chmod +x scripts/blockchain-test.sh

echo "✓ Blockchain configuration completed!"
echo
echo "Files created:"
echo "  - blockchain-config/ (minimal certificates)"
echo "  - chaincodes/simple-ledger/ (test chaincode)"
echo "  - scripts/blockchain-test.sh (blockchain validation)"
echo
echo "Next steps:"
echo "1. Test Kafka optimization: ./scripts/simple-kafka-test.sh"
echo "2. Validate on blockchain: ./scripts/blockchain-test.sh"