#!/bin/bash

# Docker-based certificate generation for Windows compatibility

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Generating Fabric Certificates using Docker ===${NC}"

FABRIC_VERSION="2.4.7"
CRYPTO_CONFIG_DIR="$(pwd)/../crypto-config"

# Create crypto-config directory structure
echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p "${CRYPTO_CONFIG_DIR}/orderer"
mkdir -p "${CRYPTO_CONFIG_DIR}/org1/peer0"
mkdir -p "${CRYPTO_CONFIG_DIR}/org2/peer0"

# Generate certificates using Docker approach
generate_crypto_with_docker() {
    echo -e "${YELLOW}Attempting Docker-based certificate generation...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker not found. Please install Docker to proceed.${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Pulling Hyperledger Fabric tools image...${NC}"
    if docker pull hyperledger/fabric-tools:${FABRIC_VERSION}; then
        echo -e "${GREEN}✓ Fabric tools image pulled successfully${NC}"
    else
        echo -e "${RED}Failed to pull fabric-tools image. Using alternative approach.${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Generating certificates with cryptogen...${NC}"
    
    if docker run --rm \
        -v "$(pwd)/../crypto-config.yaml:/crypto-config.yaml" \
        -v "${CRYPTO_CONFIG_DIR}:/crypto-config" \
        hyperledger/fabric-tools:${FABRIC_VERSION} \
        cryptogen generate --config=/crypto-config.yaml --output=/crypto-config; then
        
        echo -e "${GREEN}✓ Certificates generated successfully using Docker!${NC}"
        return 0
    else
        echo -e "${RED}Docker cryptogen failed. Trying alternative approach.${NC}"
        return 1
    fi
}

# OpenSSL fallback approach
generate_crypto_with_openssl() {
    echo -e "${YELLOW}Using OpenSSL fallback approach...${NC}"
    
    if ! command -v openssl &> /dev/null; then
        echo -e "${RED}OpenSSL not found. Please install OpenSSL.${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Generating simple certificates for testing...${NC}"
    
    create_msp_structure() {
        local base_dir=$1
        local common_name=$2
        local org_name=$3
        
        echo "Creating MSP structure for $common_name..."
        
        mkdir -p "${base_dir}/msp"/{admincerts,cacerts,signcerts,keystore,tlscacerts}
        
        openssl genrsa -out "${base_dir}/msp/keystore/key.pem" 2048 2>/dev/null
        
        openssl req -new -x509 \
            -key "${base_dir}/msp/keystore/key.pem" \
            -out "${base_dir}/msp/signcerts/cert.pem" \
            -days 365 \
            -subj "/CN=${common_name}/O=${org_name}/C=US" 2>/dev/null
        
        cp "${base_dir}/msp/signcerts/cert.pem" "${base_dir}/msp/cacerts/ca.pem"
        cp "${base_dir}/msp/signcerts/cert.pem" "${base_dir}/msp/admincerts/admin.pem"
        cp "${base_dir}/msp/signcerts/cert.pem" "${base_dir}/msp/tlscacerts/tlsca.pem"
        
        echo "✓ MSP structure created for $common_name"
    }
    
    create_msp_structure "${CRYPTO_CONFIG_DIR}/orderer" "orderer.example.com" "OrdererOrg"
    create_msp_structure "${CRYPTO_CONFIG_DIR}/org1/peer0" "peer0.org1.example.com" "Org1"
    create_msp_structure "${CRYPTO_CONFIG_DIR}/org2/peer0" "peer0.org2.example.com" "Org2"
    
    echo -e "${GREEN}✓ Basic certificates generated with OpenSSL${NC}"
    return 0
}

# Main execution
main() {
    echo "Starting certificate generation process..."
    
    if generate_crypto_with_docker; then
        echo -e "${GREEN}Certificate generation completed successfully using Docker!${NC}"
    else
        echo -e "${YELLOW}Docker approach failed, trying OpenSSL fallback...${NC}"
        if generate_crypto_with_openssl; then
            echo -e "${GREEN}Certificate generation completed using OpenSSL fallback!${NC}"
        else
            echo -e "${RED}All certificate generation methods failed!${NC}"
            exit 1
        fi
    fi
    
    echo -e "${YELLOW}Verifying generated certificates...${NC}"
    
    CERT_COUNT=$(find "${CRYPTO_CONFIG_DIR}" -name "*.pem" -type f | wc -l)
    
    if [ "$CERT_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ Found ${CERT_COUNT} certificate files${NC}"
        echo -e "${GREEN}✓ Certificate generation completed successfully!${NC}"
    else
        echo -e "${RED}✗ No certificate files found!${NC}"
        exit 1
    fi
}

main

echo -e "${GREEN}"
echo "========================================="
echo "Certificate Generation Complete!"
echo "========================================="
echo -e "${NC}"
echo "You can now proceed with blockchain network setup."
