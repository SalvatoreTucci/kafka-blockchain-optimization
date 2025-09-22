#!/bin/bash

echo "Cleaning up Kafka-Blockchain environment..."

# Stop all containers
docker-compose down

# Remove all volumes (optional - uncomment if needed)
# docker-compose down -v

# Remove stopped containers
docker container prune -f

# Remove unused networks
docker network prune -f

echo "Cleanup completed!"
