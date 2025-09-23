#!/bin/bash

echo "Cleaning up simplified Kafka environment..."

# Stop containers
docker-compose down

# Optional: clean volumes
if [ "$1" = "volumes" ]; then
    echo "Cleaning volumes..."
    docker-compose down -v
fi

# Clean unused containers
docker container prune -f

echo "Cleanup completed!"
