#!/bin/bash
set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables from backend/.env
ENV_FILE="$PROJECT_ROOT/backend/.env"
if [ -f "$ENV_FILE" ]; then
    echo "📄 Loading configuration from backend/.env..."
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "❌ backend/.env not found. Please run ./init.sh first in the workspace root."
    exit 1
fi

PROJECT_ID=${GCP_PROJECT_ID:-$(gcloud config get-value project)}
REGION=${GCP_LOCATION:-"europe-west1"}
INSTANCE_URI="${INSTANCE_CONNECTION_NAME}"

echo "🔧 Setting up AlloyDB Auth Proxy..."

# Bastion Configuration
BASTION_NAME="search-demo-bastion"
BASTION_ZONE="${REGION}-b"

# Kill existing proxy process on Bastion to avoid "Text file busy"
gcloud compute ssh $BASTION_NAME --zone $BASTION_ZONE --command "killall alloydb-auth-proxy || true" --quiet

# Ensure proxy binary exists on Bastion (download directly via Cloud NAT)
echo "📥 Ensuring alloydb-auth-proxy is installed on Bastion..."
gcloud compute ssh $BASTION_NAME --zone $BASTION_ZONE --command "
  if [ ! -f 'alloydb-auth-proxy' ]; then
    echo 'Downloading alloydb-auth-proxy on Bastion...'
    curl -sSL https://storage.googleapis.com/alloydb-auth-proxy/v1.10.0/alloydb-auth-proxy.linux.amd64 -o alloydb-auth-proxy
    chmod +x alloydb-auth-proxy
  fi
" --quiet

# Start Proxy on Bastion and Tunnel
echo "🔌 Establishing SSH tunnel and starting remote proxy..."
echo "   Forwarding localhost:5432 -> Bastion -> AlloyDB ($INSTANCE_URI)"

gcloud compute ssh $BASTION_NAME --zone $BASTION_ZONE \
    --command "./alloydb-auth-proxy \"$INSTANCE_URI\" --address=127.0.0.1 --port=5432" \
    -- -L 5432:127.0.0.1:5432
