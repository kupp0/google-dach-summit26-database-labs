#!/bin/bash

# Get the directory where the bootstrapping.sh script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_URL="https://raw.githubusercontent.com/kupp0/google-dach-summit26-database-labs/main/infrastructure/cloud_workstations"

echo "Starting Workstation Bootstrapping Coordination..."

# 1. Initialize Model Context Protocol configuration settings
if [ -f "$SCRIPT_DIR/setup_mcp.sh" ]; then
    echo "Running local MCP setup script..."
    bash "$SCRIPT_DIR/setup_mcp.sh"
else
    echo "setup_mcp.sh not found locally. Downloading from GitHub..."
    curl -sSL "$BASE_URL/setup_mcp.sh" -o /tmp/setup_mcp.sh
    bash /tmp/setup_mcp.sh
fi

# 2. Initialize lab folder and custom agent skills
if [ -f "$SCRIPT_DIR/setup_skills.sh" ]; then
    echo "Running local skills setup script..."
    bash "$SCRIPT_DIR/setup_skills.sh"
else
    echo "setup_skills.sh not found locally. Downloading from GitHub..."
    curl -sSL "$BASE_URL/setup_skills.sh" -o /tmp/setup_skills.sh
    bash /tmp/setup_skills.sh
fi

# 3. Initialize Lab 3 Swiss Property Search workspace
LAB3_SRC_DIR="/home/user/google-dach-summit26-database-labs/labs/03_fullstack_ai_app_property_search/src"
LAB3_DEST_DIR="/home/user/swiss-property-search"

if [ -d "$LAB3_SRC_DIR" ]; then
    echo "Initializing Lab 3 workspace at $LAB3_DEST_DIR..."
    mkdir -p "$LAB3_DEST_DIR"
    cp -rf "$LAB3_SRC_DIR"/* "$LAB3_DEST_DIR"/
else
    echo "Warning: Lab 3 source files not found at $LAB3_SRC_DIR"
fi

# 4. Ensure proper file ownership for Code-OSS user execution
echo "Fixing file permissions for Code-OSS workspace directories..."
chown -R 1000:1000 /home/user/disneyland-navigator /home/user/swiss-property-search /home/user/.gemini 2>/dev/null

echo "Workstation Bootstrapping Coordination completed successfully!"
