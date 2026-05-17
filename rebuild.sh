#!/bin/bash
# Clean rebuild script for litellm-proxy

echo "Stopping and removing existing containers..."
docker compose down

echo "Removing old images..."
docker rmi litellm-proxy 2>/dev/null || true

echo "Cleaning build cache..."
docker builder prune -f

echo "Rebuilding with no cache..."
docker compose build --no-cache

echo "Starting services..."
docker compose up -d

echo "Done! Check status with: docker compose ps"
