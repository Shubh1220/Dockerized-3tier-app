#!/bin/bash

set -e

echo "======================================"
echo " Deploying 3-Tier Application on AWS"
echo "======================================"

# --------------------------------------
# Project configuration
# --------------------------------------

REPO_URL="https://github.com/Shubh1220/dockerized-3tier-app.git"
BRANCH="main"

# Project root = parent directory of deploy/
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$PROJECT_DIR"

echo "Project directory: $PROJECT_DIR"

# --------------------------------------
# 1. Update system
# --------------------------------------

echo "[1/7] Updating system packages..."

sudo apt-get update -y

# --------------------------------------
# 2. Install Git and Docker
# --------------------------------------

echo "[2/7] Installing Git and Docker..."

sudo apt-get install -y git docker.io docker-compose-v2

sudo systemctl enable docker
sudo systemctl start docker

# --------------------------------------
# 3. Get source code
# --------------------------------------

echo "[3/7] Getting source code..."

if [ -d ".git" ]; then

    echo "Git repository already exists."

    git fetch origin
    git checkout "$BRANCH"
    git pull origin "$BRANCH"

else

    echo "Cloning repository..."

    git clone --branch "$BRANCH" "$REPO_URL" "$PROJECT_DIR"

fi

# --------------------------------------
# 4. Check .env.aws
# --------------------------------------

echo "[4/7] Checking .env.aws file..."

if [ -f ".env.aws" ]; then

    echo ".env.aws file exists."

else

    echo "ERROR: .env.aws file not found."
    echo "Create .env.aws before deployment."
    exit 1

fi

# --------------------------------------
# 5. Stop old containers
# --------------------------------------

echo "[5/7] Stopping old containers..."

sudo docker compose \
    --env-file .env.aws \
    -f docker-compose.prod.yml \
    down

# --------------------------------------
# 6. Build and start containers
# --------------------------------------

echo "[6/7] Building and starting containers..."

sudo docker compose \
    --env-file .env.aws \
    -f docker-compose.prod.yml \
    up -d --build

# --------------------------------------
# 7. Health check
# --------------------------------------

echo "[7/7] Checking application health..."

sleep 10

if curl -f http://localhost/healthz; then

    echo ""
    echo "======================================"
    echo " Deployment successful!"
    echo "======================================"

else

    echo ""
    echo "ERROR: Application health check failed."

    sudo docker compose \
        --env-file .env.aws \
        -f docker-compose.prod.yml \
        ps

    exit 1

fi
