#!/bin/bash

set -e

echo "======================================"
echo " Deploying 3-Tier Application on AWS"
echo "======================================"

# -------------------------------
# Variables
# -------------------------------

REPO_URL="${GITHUB_REPOSITORY_URL}"
BRANCH="${GITHUB_BRANCH:-main}"
APP_DIR="${APP_DIR:-dockerized-3tier-app}"

# -------------------------------
# 1. Update system
# -------------------------------

echo "[1/7] Updating system packages..."

sudo apt-get update -y

# -------------------------------
# 2. Install Git and Docker
# -------------------------------

echo "[2/7] Installing Git and Docker..."

sudo apt-get install -y git docker.io

# Install Docker Compose plugin
sudo apt-get install -y docker-compose-plugin

# Enable Docker
sudo systemctl enable docker
sudo systemctl start docker

# -------------------------------
# 3. Clone / Update repository
# -------------------------------

echo "[3/7] Getting source code..."

if [ -d "$APP_DIR/.git" ]; then

    cd "$APP_DIR"

    git fetch origin
    git checkout "$BRANCH"
    git pull origin "$BRANCH"

else

    git clone --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
    cd "$APP_DIR"

fi

# -------------------------------
# 4. Check environment file
# -------------------------------

echo "[4/7] Checking .env file..."

if [ -f ".env.aws" ]; then

    echo ".env.aws file exists"

else

    echo "ERROR: .env.aws file not found"
    echo "Create .env.aws before deployment."
    exit 1

fi

# -------------------------------
# 5. Stop old containers
# -------------------------------

echo "[5/7] Stopping old containers..."

sudo docker compose \
    --env-file .env.aws \
    -f docker-compose.prod.yml \
    down

# -------------------------------
# 6. Build and start containers
# -------------------------------

echo "[6/7] Building and starting containers..."

sudo docker compose \
    --env-file .env.aws \
    -f docker-compose.prod.yml \
    up -d --build

# -------------------------------
# 7. Health check
# -------------------------------

echo "[7/7] Checking application health..."

sleep 10

if curl -f http://localhost/health; then

    echo ""
    echo "======================================"
    echo " Deployment successful!"
    echo "======================================"

else

    echo ""
    echo "ERROR: Application health check failed."
    echo ""
    sudo docker compose \
        --env-file .env.aws \
        -f docker-compose.prod.yml \
        ps

    exit 1

fi
