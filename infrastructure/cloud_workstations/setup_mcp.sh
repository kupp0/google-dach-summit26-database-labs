#!/bin/bash

# Auto-detect GCP Project ID
PROJECT_ID=""

sanitize_project_id() {
    local pid="$1"
    if [[ -z "$pid" || "$pid" == "CURRENT_PROJECT" || "$pid" == "current_project" || "$pid" == "current-project" ]]; then
        echo ""
    else
        echo "$pid"
    fi
}

# 1. Check gcloud config billing quota project
PROJECT_ID=$(gcloud config get-value billing/quota_project 2>/dev/null)
PROJECT_ID=$(sanitize_project_id "$PROJECT_ID")

# 2. Check application default credentials JSON file
if [ -z "$PROJECT_ID" ] && [ -f "/home/user/.config/gcloud/application_default_credentials.json" ]; then
    PROJECT_ID=$(jq -r '.quota_project_id // empty' "/home/user/.config/gcloud/application_default_credentials.json" 2>/dev/null)
    PROJECT_ID=$(sanitize_project_id "$PROJECT_ID")
fi

# 3. Check environment variable GOOGLE_CLOUD_PROJECT
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(sanitize_project_id "$GOOGLE_CLOUD_PROJECT")
fi

# 4. Fallback to active gcloud project
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    PROJECT_ID=$(sanitize_project_id "$PROJECT_ID")
fi

# If still not found, ask user or error
if [ -z "$PROJECT_ID" ]; then
    echo "Error: Could not auto-detect GCP Project ID."
    echo "Please set GOOGLE_CLOUD_PROJECT or authenticate with: gcloud auth application-default login"
    exit 1
fi

echo "Detected GCP Project ID: $PROJECT_ID"


INSTANCE_ID="disneyland"
DATABASE_ID="agent-lab"

# Define the JSON configuration
MCP_CONFIG_CONTENT=$(cat <<EOF
{
  "mcpServers": {
    "google-managed-spanner": {
      "url": "https://spanner.googleapis.com/mcp",
      "serverUrl": "https://spanner.googleapis.com/mcp",
      "serverURL": "https://spanner.googleapis.com/mcp",
      "authProviderType": "google_credentials"
    }
  }
}
EOF
)

PLUGIN_CONTENT=$(cat <<EOF
{
  "url": "https://spanner.googleapis.com/mcp",
  "serverUrl": "https://spanner.googleapis.com/mcp",
  "serverURL": "https://spanner.googleapis.com/mcp",
  "authProviderType": "google_credentials"
}
EOF
)

# Define general Antigravity config
CLI_CONFIG_CONTENT=$(cat <<EOF
{
  "project": "$PROJECT_ID",
  "project_id": "$PROJECT_ID",
  "location": "global",
  "theme": "dark",
  "terms_accepted": true
}
EOF
)

# Target directory paths
DIR1="/home/user/.gemini/config"
DIR2="/home/user/.gemini/antigravity-cli"
DIR3="/home/user/.gemini/antigravity-cli/plugins"

# Create directories
mkdir -p "$DIR1" "$DIR2" "$DIR3"

# Write the config files
echo "Writing configuration files..."
echo "$MCP_CONFIG_CONTENT" > "$DIR1/mcp_config.json"
echo "$MCP_CONFIG_CONTENT" > "$DIR2/mcp_config.json"
echo "$PLUGIN_CONTENT" > "$DIR3/google-managed-spanner.json"
echo "$CLI_CONFIG_CONTENT" > "$DIR1/config.json"
echo "$CLI_CONFIG_CONTENT" > "$DIR2/config.json"

# Pre-configure gcloud active project
GCLOUD_CONFIG_DIR="/home/user/.config/gcloud/configurations"
mkdir -p "$GCLOUD_CONFIG_DIR"
cat <<EOF > "$GCLOUD_CONFIG_DIR/config_default"
[core]
project = $PROJECT_ID
EOF


echo "MCP Server and Antigravity CLI configuration successfully generated!"
echo "Target files updated:"
echo " - $DIR1/mcp_config.json"
echo " - $DIR2/mcp_config.json"
echo " - $DIR3/google-managed-spanner.json"
echo " - $DIR1/config.json"
echo " - $DIR2/config.json"
