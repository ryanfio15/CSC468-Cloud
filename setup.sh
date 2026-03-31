#!/bin/bash

set -e

# Wait for Docker daemon to be fully ready after install
echo "Waiting for Docker to be ready..."
until sudo docker info >/dev/null 2>&1; do
    sleep 3
done

# Generate random Postgres credentials for this launch
POSTGRES_USER="user_$(openssl rand -hex 4)"
POSTGRES_PASSWORD="$(openssl rand -hex 16)"
POSTGRES_DB="db_$(openssl rand -hex 4)"

# Write .env file for backend and db containers
cat > /local/repository/.env <<EOF
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}
DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
API_KEY=${API_KEY}
GITHUB_TOKEN=${GITHUB_TOKEN}
EOF

echo ".env file written."

# Login to GHCR using the GitHub token
echo "${GITHUB_TOKEN}" | sudo docker login ghcr.io -u ryanfio15 --password-stdin

# Pull images and bring up all containers (db, backend, frontend)
cd /local/repository
sudo docker-compose pull
sudo docker-compose up -d

echo "All containers are up."

# Register custom hostname so the node resolves RyanFioravantiCSC468Project to itself
echo "127.0.0.1 RyanFioravantiCSC468Project" | sudo tee -a /etc/hosts
