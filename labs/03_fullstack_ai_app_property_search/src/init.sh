#!/bin/bash
set -e

# Install root requirements
if [ -f "requirements.txt" ]; then
    echo "Installing base requirements..."
    pip install -r requirements.txt
fi

# Assign IAP Tunnel Access permission to the active user account
echo "🔑 Assigning IAP Tunnel Access permissions to your gcloud account..."
gcloud projects add-iam-policy-binding $(gcloud config get-value project) \
    --member="user:$(gcloud config get-value account)" \
    --role="roles/iap.tunnelResourceAccessor"

echo "✅ Environment initialization completed successfully!"


