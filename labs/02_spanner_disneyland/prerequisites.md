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

### C. Grant Spanner Admin Permissions
To authorize BigQuery connections to read transactional data from Cloud Spanner, Terraform creates an IAM policy binding on the Spanner database. The sandbox account deploying the Terraform script must possess Spanner administration privileges.
Ensure the following role is bound to the deploying account/agent:
```bash
gcloud projects add-iam-policy-binding $(gcloud config get-value project) \
  --member="user:$(gcloud config get-value account)" \
  --role="roles/spanner.admin"
```

---

## 2. Networking Requirements (For Cloud Workstations User)

If participants are utilizing **Cloud Workstations** rather than Google Cloud Shell, the following shared networking infrastructure must be pre-provisioned:
* **Private NAT**: Enable Private NAT inside the target VPC network.
* **Subnets**: A dedicated VPC network and subnet must be created in the primary region (`europe-west1`).
* **IAM/Security Accounts**: Ensure the Cloud Workstations service accounts have adequate IAM permissions to join resources inside the designated subnet.

---

## 3. Model Context Protocol (MCP) Toolbox Setup (Action Required)

The original user guide contained steps to manually install the GCP MCP Toolbox client and list active tools:
```bash
gcloud components install mcp-toolbox
gcloud mcp-toolbox list-resources --project=$(gcloud config get-value project) --location=europe-west1
```

> [!WARNING]
> **gcloud Component Registration Issue**:
> Standard `gcloud` CLI environments (including Cloud Shell) currently do not recognize `mcp-toolbox` as a valid installable component, resulting in the error:
> `ERROR: (gcloud.components.install) "mcp-toolbox" are not valid component name(s).`
> 
> **Action Item**:
> The coworker working on the base environment script must either:
> 1. Package/deploy the open-source Model Context Protocol (MCP) database proxy service directly to Cloud Run inside the base Terraform environment.
> 2. Provide participants with a custom component manager URL registry if a private pre-release `gcloud` build is intended for the workshop.
> 3. Or verify the MCP Toolbox status via backend logs rather than requiring participant terminal commands.
