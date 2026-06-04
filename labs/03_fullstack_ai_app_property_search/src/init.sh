#!/bin/bash
set -e

# Install root requirements
if [ -f "requirements.txt" ]; then
    echo "Installing base requirements..."
    pip install --break-system-packages -r requirements.txt
fi

# Assign IAP Tunnel Access permission to the active user account
echo "🔑 Assigning IAP Tunnel Access permissions to your gcloud account..."
gcloud projects add-iam-policy-binding $(gcloud config get-value project) \
    --member="user:$(gcloud config get-value account)" \
    --role="roles/iap.tunnelResourceAccessor"

# Generate backend/.env dynamically
ENV_FILE="backend/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "Creating backend/.env configuration..."
    GCP_PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
    GCP_LOCATION=$(gcloud alloydb instances list --cluster=search-cluster --format="value(location)" --limit=1 2>/dev/null || echo "")
    
    if [ -z "$GCP_LOCATION" ]; then
        GCP_LOCATION="europe-west3"
    fi
    INSTANCE_CONNECTION_NAME="projects/${GCP_PROJECT_ID}/locations/${GCP_LOCATION}/clusters/search-cluster/instances/search-primary"
    
    cat << EOF > "$ENV_FILE"
GCP_PROJECT_ID=${GCP_PROJECT_ID}
GCP_LOCATION=${GCP_LOCATION}
INSTANCE_CONNECTION_NAME=${INSTANCE_CONNECTION_NAME}
DB_NAME=postgres
DB_USER=postgres
DB_PASSWORD=alloydb-hackathon-password
VERTEX_AI_SEARCH_DATA_STORE_ID=property-listings-ds
EOF
    echo "✅ backend/.env generated successfully!"
fi

echo "✅ Environment initialization completed successfully!"


