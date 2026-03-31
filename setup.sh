#!/bin/bash

set -e

# Wait for Docker daemon to be fully ready after install
echo "Waiting for Docker to be ready..."
until sudo docker info >/dev/null 2>&1; do
    sleep 3
done

# Detect the CloudLab user (owns /local/repository)
RUNNER_USER=$(stat -c '%U' /local/repository)
RUNNER_HOME=$(getent passwd ${RUNNER_USER} | cut -d: -f6)
echo "Detected CloudLab user: ${RUNNER_USER}"

# Generate random Postgres credentials for this launch
POSTGRES_USER="user_$(openssl rand -hex 4)"
POSTGRES_PASSWORD="$(openssl rand -hex 16)"
POSTGRES_DB="db_$(openssl rand -hex 4)"
SECRET_KEY="$(openssl rand -hex 32)"

# Write .env file for backend and db containers
cat > /local/repository/.env <<EOF
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}
DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
ANTHROPIC_API_KEY=${API_KEY}
GITHUB_TOKEN=${GITHUB_TOKEN}
SECRET_KEY=${SECRET_KEY}
EOF

echo ".env file written."

# Login to GHCR as the runner user so deploy jobs can pull images
echo "${GITHUB_TOKEN}" | sudo -u ${RUNNER_USER} docker login ghcr.io -u ryanfio15 --password-stdin

# Pull images and bring up all containers
cd /local/repository
sudo docker-compose pull || true
sudo docker-compose up -d

echo "All containers are up."

# Register custom hostname so the node resolves RyanFioravantiCSC468Project to itself
echo "127.0.0.1 RyanFioravantiCSC468Project" | sudo tee -a /etc/hosts

# ── GitHub Actions self-hosted runner setup ──────────────────────────────────

RUNNER_DIR="/opt/actions-runner"
REPO="ryanfio15/ai-code-review-system"

# Remove any stale runners registered with GitHub from previous experiments
echo "Removing stale runners from GitHub..."
RUNNER_IDS=$(curl -s \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${REPO}/actions/runners" \
  | grep '"id"' | awk -F: '{print $2}' | tr -d ', ')

for ID in $RUNNER_IDS; do
  curl -s -X DELETE \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${REPO}/actions/runners/${ID}"
  echo "Removed stale runner ID: ${ID}"
done

# Download and install the runner agent
mkdir -p ${RUNNER_DIR}
chown ${RUNNER_USER} ${RUNNER_DIR}
cd ${RUNNER_DIR}

RUNNER_VERSION="2.323.0"
curl -sL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
  | tar xz

chown -R ${RUNNER_USER} ${RUNNER_DIR}

# Get a fresh registration token via the GitHub API
REG_TOKEN=$(curl -s -X POST \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${REPO}/actions/runners/registration-token" \
  | grep '"token"' | awk -F'"' '{print $4}')

# Configure and register the runner as the CloudLab user
sudo -u ${RUNNER_USER} ./config.sh \
  --url "https://github.com/${REPO}" \
  --token "${REG_TOKEN}" \
  --name "cloudlab-node" \
  --labels "cloudlab" \
  --unattended \
  --replace

# Start the runner as a background service under the CloudLab user
sudo -u ${RUNNER_USER} nohup ./run.sh &>/var/log/actions-runner.log &

echo "GitHub Actions runner registered and started as ${RUNNER_USER}."
