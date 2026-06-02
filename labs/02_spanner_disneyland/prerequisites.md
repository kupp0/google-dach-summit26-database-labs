# Lab 2 Infrastructure Setup & Prerequisites (Internal Reference)

This document serves as an internal operational reference for organizers and infrastructure engineers to prepare sandbox environments for **Lab 2: Cloud Spanner & BigQuery Disneyland Lab**.

---

## 1. Sandbox Account & API Prerequisites

### A. Participant Sandbox Accounts
Participants must be assigned dedicated sandbox accounts to prevent resource conflicts.
* Reference sheet: [frictionless accounts sheet](https://docs.google.com/spreadsheets/d/1CU4at6i5aeGfFotrcKLFeytHcIqCKHDmzZMUT1EMCAg/edit?gid=1814460091#gid=1814460091)

### B. Enable Cloud Resource Manager API
Before provisioning the Spanner infrastructure via Terraform, the Cloud Resource Manager API must be enabled within the target project context:
```bash
gcloud services enable cloudresourcemanager.googleapis.com --project=$(gcloud config get-value project)
```

### C. Grant Spanner Admin & MCP Tool User Permissions
To authorize BigQuery connections to read transactional data from Cloud Spanner, and to allow the deploying user to query/interact with the registered Model Context Protocol (MCP) servers, both Spanner administration and MCP tool user roles must be granted to the active account.

Ensure the following roles are bound to the deploying account/agent:
```bash
# 1. Grant Spanner Admin permissions to deploy and configure Spanner
gcloud projects add-iam-policy-binding $(gcloud config get-value project) \
  --member="user:$(gcloud config get-value account)" \
  --role="roles/spanner.admin"

# 2. Grant MCP Tool User permissions to interact with Google-managed MCP Servers
gcloud projects add-iam-policy-binding $(gcloud config get-value project) \
  --member="user:$(gcloud config get-value account)" \
  --role="roles/mcp.toolUser"
```

---

## 2. Networking Requirements (For Cloud Workstations User)

If participants are utilizing **Cloud Workstations** rather than Google Cloud Shell, the following shared networking infrastructure must be pre-provisioned:
* **Private NAT**: Enable Private NAT inside the target VPC network.
* **Subnets**: A dedicated VPC network and subnet must be created in the primary region (`europe-west3`).
* **IAM/Security Accounts**: Ensure the Cloud Workstations service accounts have adequate IAM permissions to join resources inside the designated subnet.

---

## 3. Model Context Protocol (MCP) Toolbox Setup (Action Required)

The MCP client is installed as part of the gemini-cli 
see https://docs.cloud.google.com/spanner/docs/use-spanner-mcp


> **Action Item**:
> The coworker working on the base environment script must either:
> 1. Package/deploy the open-source Model Context Protocol (MCP) database proxy service directly to Cloud Run inside the base Terraform environment.
> 2. Provide participants with a custom component manager URL registry if a private pre-release `gcloud` build is intended for the workshop.
> 3. Or verify the MCP Toolbox status via backend logs rather than requiring participant terminal commands.
