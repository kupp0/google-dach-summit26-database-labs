# Infrastructure Setup & Automations Hierarchy

This directory houses all Terraform and shell automations for provisioning the hands-on database lab workspaces for the DACH Summit 2026. 

During the hackathon event, participants will receive empty, fresh GCP projects. This suite of tools automates the base networking, identity/access management, workstation deployment, and database instance configurations to prepare a fully Frictionless environment.

---

## Directory Structure

```
infrastructure/
├── README.md                       # This overview and operations guide
├── gcp_setup/
│   ├── automations.sh              # Bootstrap script (APIs, Billing, IAM binding)
│   └── setup_alloydb.tf            # Terraform script enabling APIs and Vertex AI bindings for Lab 1
├── networking/
│   └── setup_vpc.tf                # VPC Network, Subnets, Cloud NAT, and IAP Firewalls
└── cloud_workstations/
    └── workstations.tf             # Google Cloud Workstations config for participants
```

---

## Infrastructure Component Descriptions

### 1. [GCP Setup Automations](file:///usr/local/google/home/kupczak/dev/google-dach-summit26-database-labs/infrastructure/gcp_setup/automations.sh)
An orchestrator script that loops through all active user projects to:
- Link billing accounts to the empty participant projects.
- Enable all required services (AlloyDB, Spanner, BigQuery, Vertex AI, Cloud Workstations).
- Bind appropriate IAM roles to user profiles and service agents.

### 2. [Networking Core](file:///usr/local/google/home/kupczak/dev/google-dach-summit26-database-labs/infrastructure/networking/setup_vpc.tf)
A standard Terraform configuration that sets up the shared network boundaries:
- **VPC Network**: Custom VPC with subnets per lab.
- **Cloud NAT & Gateway**: For secure internet access without external IPs.
- **Firewall Ingress Rules**: Restricted TCP traffic ingress from Google's IAP range (`35.235.240.0/20`) for secure terminal access.

### 3. [Cloud Workstations](file:///usr/local/google/home/kupczak/dev/google-dach-summit26-database-labs/infrastructure/cloud_workstations/workstations.tf)
Provisioning files for **Google Cloud Workstations**, providing participants with:
- High-performance, pre-configured browser-based IDE development nodes.
- Pre-loaded developer SDKs (gcloud CLI, Terraform, pgadmin, psql, node.js).
- Automated container runtime mounts for secure IAP proxy tunnels.

---

## Environment Setup for Gemini

Before calling Gemini, make sure to set the following environment variables in your terminal:

### Authenticate as your user - not the service account
Open the link using CTRL + Click and login as the devstar user. Agree to the terms. Copy the code back the terminal. You need to run both commands

```bash
gcloud auth login

gcloud auth application-default login
```


```bash
export GOOGLE_CLOUD_PROJECT="your-project-id"
export GOOGLE_CLOUD_LOCATION="global"
```

---

> [!NOTE]
> *Operational Status: Under Development.*  
> Placeholder templates have been established. Automated scripts are currently being integrated by the core infrastructure team.
