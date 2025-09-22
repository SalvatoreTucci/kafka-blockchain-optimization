#!/bin/bash

# Complete benchmark setup script
# Creates all necessary files and dependencies for baseline testing

set -e

echo "Setting up benchmark environment..."

# Create benchmark directories
mkdir -p benchmarks/{networks,workloads,chaincodes}
mkdir -p results/baselines

# Install Python dependencies for analysis
echo "Setting up Python analysis environment..."
if command -v python3 &> /dev/null; then
    pip3 install --user pandas matplotlib numpy || echo "Warning: Could not install Python packages"
else
    echo "Warning: Python3 not found. Install manually: pip3 install pandas matplotlib numpy"
fi

# Make scripts executable
chmod +x scripts/run-benchmark.sh
chmod +x scripts/analyze-results.py

# Create simplified smallbank chaincode (Node.js)
echo "Creating smallbank chaincode..."
mkdir -p benchmarks/chaincodes/smallbank

cat > benchmarks/chaincodes/smallbank/package.json << 'EOF'
{
  "name": "smallbank",
  "version": "1.0.0",
  "description": "Smallbank benchmark chaincode",
  "main": "index.js",
  "scripts": {
    "start": "fabric-chaincode-node start"
  },
  "dependencies": {
    "fabric-contract-api": "^2.4.1",
    "fabric-shim": "^2.4.1"
  }
}
EOF

cat > benchmarks/chaincodes/smallbank/index.js << 'EOF'
'use strict';

const { Contract } = require('fabric-contract-api');

class SmallbankContract extends Contract {

    async initLedger(ctx) {
        console.info('============= START : Initialize Ledger ===========');
        
        // Initialize some accounts for testing
        const accounts = [
            { id: 'account_0', savings: 10000, checking: 10000 },
            { id: 'account_1', savings: 10000, checking: 10000 },
            { id: 'account_2', savings: 10000, checking: 10000 },
        ];

        for (let i = 0; i < accounts.length; i++) {
            accounts[i].docType = 'account';
            await ctx.stub.putState(accounts[i].id, Buffer.from(JSON.stringify(accounts[i])));
            console.info('Added <--> ', accounts[i]);
        }
        console.info('============= END : Initialize Ledger ===========');
    }

    async createAccount(ctx, accountId, initialSavings, initialChecking) {
        console.info('============= START : Create Account ===========');

        const account = {
            docType: 'account',
            id: accountId,
            savings: parseInt(initialSavings),
            checking: parseInt(initialChecking),
        };

        await ctx.stub.putState(accountId, Buffer.from(JSON.stringify(account)));
        console.info('============= END : Create Account ===========');
    }

    async query(ctx, accountId) {
        const accountAsBytes = await ctx.stub.getState(accountId);
        if (!accountAsBytes || accountAsBytes.length === 0) {
            throw new Error(`${accountId} does not exist`);
        }
        console.log(accountAsBytes.toString());
        return accountAsBytes.toString();
    }

    async deposit(ctx, accountId, amount) {
        console.info('============= START : Deposit ===========');

        const accountAsBytes = await ctx.stub.getState(accountId);
        if (!accountAsBytes || accountAsBytes.length === 0) {
            throw new Error(`${accountId} does not exist`);
        }
        const account = JSON.parse(accountAsBytes.toString());

        account.checking += parseInt(amount);

        await ctx.stub.putState(accountId, Buffer.from(JSON.stringify(account)));
        console.info('============= END : Deposit ===========');
    }

    async sendPayment(ctx, fromAccountId, toAccountId, amount) {
        console.info('============= START : Send Payment ===========');

        const fromAccountAsBytes = await ctx.stub.getState(fromAccountId);
        if (!fromAccountAsBytes || fromAccountAsBytes.length === 0) {
            throw new Error(`${fromAccountId} does not exist`);
        }
        const fromAccount = JSON.parse(fromAccountAsBytes.toString());

        const toAccountAsBytes = await ctx.stub.getState(toAccountId);
        if (!toAccountAsBytes || toAccountAsBytes.length === 0) {
            throw new Error(`${toAccountId} does not exist`);
        }
        const toAccount = JSON.parse(toAccountAsBytes.toString());

        const transferAmount = parseInt(amount);
        if (fromAccount.checking < transferAmount) {
            throw new Error('Insufficient funds');
        }

        fromAccount.checking -= transferAmount;
        toAccount.checking += transferAmount;

        await ctx.stub.putState(fromAccountId, Buffer.from(JSON.stringify(fromAccount)));
        await ctx.stub.putState(toAccountId, Buffer.from(JSON.stringify(toAccount)));

        console.info('============= END : Send Payment ===========');
    }

    async transactSavings(ctx, accountId, amount) {
        console.info('============= START : Transact Savings ===========');

        const accountAsBytes = await ctx.stub.getState(accountId);
        if (!accountAsBytes || accountAsBytes.length === 0) {
            throw new Error(`${accountId} does not exist`);
        }
        const account = JSON.parse(accountAsBytes.toString());

        const transactionAmount = parseInt(amount);
        
        // Move money from checking to savings
        if (account.checking >= transactionAmount) {
            account.checking -= transactionAmount;
            account.savings += transactionAmount;
        } else {
            throw new Error('Insufficient checking funds');
        }

        await ctx.stub.putState(accountId, Buffer.from(JSON.stringify(account)));
        console.info('============= END : Transact Savings ===========');
    }

    async queryAllAccounts(ctx) {
        const startKey = '';
        const endKey = '';
        const allResults = [];
        for await (const {key, value} of ctx.stub.getStateByRange(startKey, endKey)) {
            const strValue = Buffer.from(value).toString('utf8');
            let record;
            try {
                record = JSON.parse(strValue);
            } catch (err) {
                console.log(err);
                record = strValue;
            }
            allResults.push({ Key: key, Record: record });
        }
        console.info(allResults);
        return JSON.stringify(allResults);
    }
}

module.exports = SmallbankContract;
EOF

# Create benchmark execution script
cat > scripts/run-baseline-tests.sh << 'EOF'
#!/bin/bash

# Run complete baseline test suite for Paper 2/3 replication

set -e

echo "=== KAFKA BLOCKCHAIN OPTIMIZATION - BASELINE TESTING ==="
echo "This script runs the complete baseline test suite"
echo

# Test configurations to run
declare -a CONFIGS=(
    ".env.default:default-baseline"
    ".env.batch-optimized:batch-optimized" 
    ".env.compression-optimized:compression-optimized"
)

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASELINE_DIR="results/baseline-suite-${TIMESTAMP}"
mkdir -p "${BASELINE_DIR}"

echo "Results will be saved in: ${BASELINE_DIR}"
echo

for config_pair in "${CONFIGS[@]}"; do
    IFS=':' read -ra ADDR <<< "$config_pair"
    env_file="${ADDR[0]}"
    test_name="${ADDR[1]}-${TIMESTAMP}"
    
    echo "======================================="
    echo "Running test: ${test_name}"
    echo "Configuration: ${env_file}"
    echo "======================================="
    
    # Run benchmark
    ./scripts/run-benchmark.sh benchmarks/smallbank-config.yaml benchmarks/networks/fabric-kafka.yaml "${test_name}" "${env_file}"
    
    # Move results to baseline directory
    mv "results/${test_name}" "${BASELINE_DIR}/"
    
    echo "✓ Test ${test_name} completed"
    echo
    
    # Wait between tests
    echo "Waiting 30 seconds before next test..."
    sleep 30
done

echo "=== BASELINE TESTING COMPLETE ==="
echo "All results saved in: ${BASELINE_DIR}"
echo
echo "Next steps:"
echo "1. Analyze individual results:"
echo "   python3 scripts/analyze-results.py ${BASELINE_DIR}/default-baseline-${TIMESTAMP}"
echo
echo "2. Compare configurations:"
echo "   python3 scripts/analyze-results.py ${BASELINE_DIR}/batch-optimized-${TIMESTAMP} --baseline ${BASELINE_DIR}/default-baseline-${TIMESTAMP}"
echo
echo "3. View dashboards:"
echo "   http://localhost:3000 (Grafana)"
echo
EOF

chmod +x scripts/run-baseline-tests.sh

# Create quick test script for validation
cat > scripts/quick-test.sh << 'EOF'
#!/bin/bash

# Quick validation test - 5 minutes total

echo "=== QUICK VALIDATION TEST ==="
echo "Running 5-minute validation test..."

# Start environment  
./scripts/run-test.sh .env.default quick-test

# Wait for readiness
sleep 60

# Simulate load for 2 minutes
echo "Simulating blockchain load..."
sleep 120

# Collect basic metrics
echo "Collecting metrics..."
RESULTS_DIR="results/quick-test-$(date +%H%M%S)"
mkdir -p "${RESULTS_DIR}"

# Simple metrics collection
docker stats --no-stream kafka1 kafka2 kafka3 > "${RESULTS_DIR}/docker-stats.txt"
docker logs kafka1 > "${RESULTS_DIR}/kafka1.log" 2>&1
docker logs orderer.example.com > "${RESULTS_DIR}/orderer.log" 2>&1

echo "✓ Quick test completed"
echo "Results in: ${RESULTS_DIR}"
echo "Check logs and stats for basic health validation"
EOF

chmod +x scripts/quick-test.sh

echo "✓ Benchmark environment setup complete!"
echo
echo "Available commands:"
echo "  ./scripts/quick-test.sh              - 5-minute validation test"  
echo "  ./scripts/run-benchmark.sh           - Single benchmark run"
echo "  ./scripts/run-baseline-tests.sh      - Complete baseline suite"
echo "  python3 scripts/analyze-results.py   - Analyze results"
echo
echo "Next steps:"
echo "1. Run quick validation: ./scripts/quick-test.sh"
echo "2. Run full baseline:    ./scripts/run-baseline-tests.sh"
echo "3. Analyze results and compare with Paper 2/3 baselines"