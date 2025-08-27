#!/bin/bash
# Check system prerequisites

echo "🔍 Checking system requirements..."

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker."
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose not found. Please install Docker Compose."
    exit 1
fi

# Check available memory
MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
if [ $MEM_GB -lt 8 ]; then
    echo "⚠️  Warning: Less than 8GB RAM available. Performance may be impacted."
fi

# Check available disk space
DISK_GB=$(df -BG . | awk 'NR==2{gsub(/G/,"",$4); print $4}')
if [ $DISK_GB -lt 10 ]; then
    echo "❌ Less than 10GB disk space available."
    exit 1
fi

echo "✅ System requirements satisfied"