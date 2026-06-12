#!/usr/bin/env bash
# Wrapper to run the infrastructure deploy script from the repository root
#
# Usage:
#   ./deploy.sh [START_ID] [END_ID]
#
# Default Range:
#   3900 to 3999 (devstar3900 to devstar3999)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/infrastructure"

exec ./deploy.sh "$@"
