#!/usr/bin/env bash
#
# Batch deploy script for DACH Summit 2026 Database Labs.
# Uses Terraform Workspaces to isolate state per participant so deploying
# one project does not destroy resources in another project.
#
# Usage:
#   ./deploy.sh [START_ID] [END_ID]
#
# Default Range:
#   3900 to 3999 (devstar3900 to devstar3999)

set -euo pipefail

START_ID="${1:-3900}"
END_ID="${2:-3999}"

# Ensure we run from the infrastructure directory containing main.tf
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Ensure we switch back to the default workspace when the script exits
trap 'terraform workspace select default 2>/dev/null || true' EXIT

echo "================================================================="
echo "Starting DACH Summit 2026 Batch Deployment"
echo "Target User Range : ${START_ID} to ${END_ID}"
echo "Operating Dir     : $(pwd)"
echo "Using Isolation   : Terraform Workspaces"
echo "================================================================="

SUCCESSFUL=()
FAILED=()

for (( i = START_ID; i <= END_ID; i++ )); do
  USER="user:devstar${i}@gcplab.me"
  PROJECT="dach-databases26fra-${i}"
  WORKSPACE="devstar${i}"

  echo ""
  echo "-----------------------------------------------------------------"
  echo "Processing Participant ID : ${i}"
  echo "IAP Member                : ${USER}"
  echo "Project ID                : ${PROJECT}"
  echo "Terraform Workspace       : ${WORKSPACE}"
  echo "-----------------------------------------------------------------"

  echo ">>> Switching Terraform workspace to ${WORKSPACE}..."
  terraform workspace select "${WORKSPACE}" 2>/dev/null || terraform workspace new "${WORKSPACE}"

  echo ">>> [1/2] Running Terraform Plan for ${PROJECT}..."
  if terraform plan -var="iap_member=${USER}" -var="project_id=${PROJECT}"; then
    echo ">>> [2/2] Running Terraform Apply (Auto-Approve) for ${PROJECT}..."
    if terraform apply -auto-approve -var="iap_member=${USER}" -var="project_id=${PROJECT}"; then
      echo "✔ Successfully deployed participant ${i} (${PROJECT})"
      SUCCESSFUL+=("${i}")
    else
      echo "❌ ERROR: Terraform apply failed for participant ${i} (${PROJECT})"
      FAILED+=("${i}")
    fi
  else
    echo "❌ ERROR: Terraform plan failed for participant ${i} (${PROJECT})"
    FAILED+=("${i}")
  fi
done

# Switch back to default workspace before printing summary
terraform workspace select default 2>/dev/null || true

echo ""
echo "================================================================="
echo "Batch Deployment Final Summary (${START_ID} to ${END_ID})"
echo "================================================================="
echo "Total Attempted : $(( END_ID - START_ID + 1 ))"
echo "Successful      : ${#SUCCESSFUL[@]}"
echo "Failed          : ${#FAILED[@]}"

if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "Failed IDs      : ${FAILED[*]}"
  exit 1
fi
