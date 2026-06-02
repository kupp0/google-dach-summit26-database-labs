#!/bin/bash

# Get the directory where the bootstrapping.sh script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting Workstation Bootstrapping Coordination..."

# 1. Initialize Model Context Protocol configuration settings
if [ -f "$SCRIPT_DIR/setup_mcp.sh" ]; then
    echo "Running MCP setup script..."
    bash "$SCRIPT_DIR/setup_mcp.sh"
else
    echo "Error: setup_mcp.sh not found!"
fi

# 2. Initialize lab folder and custom agent skills
if [ -f "$SCRIPT_DIR/setup_skills.sh" ]; then
    echo "Running skills setup script..."
    bash "$SCRIPT_DIR/setup_skills.sh"
else
    echo "Error: setup_skills.sh not found!"
fi

echo "Workstation Bootstrapping Coordination completed successfully!"
