#!/bin/bash

# Get the directory where the bootstrapping.sh script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_URL="https://raw.githubusercontent.com/kupp0/google-dach-summit26-database-labs/main/infrastructure/cloud_workstations"

echo "Starting Workstation Bootstrapping Coordination..."

# Pre-clone the repository if not already present in the workspace
if [ ! -d "/home/user/google-dach-summit26-database-labs" ]; then
    echo "Cloning database-labs repository..."
    git clone https://github.com/kupp0/google-dach-summit26-database-labs.git /home/user/google-dach-summit26-database-labs
    # Fix permissions for the cloned repo right away
    chown -R 1000:1000 /home/user/google-dach-summit26-database-labs
fi

REPO_DIR="/home/user/google-dach-summit26-database-labs"

# 1. Initialize Model Context Protocol configuration settings
if [ -f "$REPO_DIR/infrastructure/cloud_workstations/setup_mcp.sh" ]; then
    echo "Running local MCP setup script..."
    bash "$REPO_DIR/infrastructure/cloud_workstations/setup_mcp.sh"
else
    echo "setup_mcp.sh not found locally. Downloading from GitHub..."
    curl -sSL "$BASE_URL/setup_mcp.sh" -o "/tmp/setup_mcp_${USER}.sh"
    bash "/tmp/setup_mcp_${USER}.sh"
fi

# 2. Initialize lab folder and custom agent skills
if [ -f "$REPO_DIR/infrastructure/cloud_workstations/setup_skills.sh" ]; then
    echo "Running local skills setup script..."
    bash "$REPO_DIR/infrastructure/cloud_workstations/setup_skills.sh"
else
    echo "setup_skills.sh not found locally. Downloading from GitHub..."
    curl -sSL "$BASE_URL/setup_skills.sh" -o "/tmp/setup_skills_${USER}.sh"
    bash "/tmp/setup_skills_${USER}.sh"
fi

# 3. Initialize Lab 3 Swiss Property Search workspace
LAB3_SRC_DIR="/home/user/google-dach-summit26-database-labs/labs/03_fullstack_ai_app_property_search/src"
LAB3_DEST_DIR="/home/user/lab03_swiss_property_search"

if [ ! -d "$LAB3_DEST_DIR" ]; then
    if [ -d "$LAB3_SRC_DIR" ]; then
        echo "Initializing Lab 3 workspace at $LAB3_DEST_DIR..."
        mkdir -p "$LAB3_DEST_DIR"
        cp -rf "$LAB3_SRC_DIR"/* "$LAB3_DEST_DIR"/
    else
        echo "Warning: Lab 3 source files not found at $LAB3_SRC_DIR"
    fi
fi

# 4. Ensure proper file ownership for Code-OSS user execution
echo "Fixing file permissions for Code-OSS workspace directories..."
chown -R 1000:1000 /home/user/lab02_disneyland_navigator /home/user/lab03_swiss_property_search /home/user/.gemini 2>/dev/null

# 5. Clean up the cloned repository to keep workspace clean
echo "Removing cloned template repository..."
rm -rf /home/user/google-dach-summit26-database-labs

echo "Workstation Bootstrapping Coordination completed successfully!"
