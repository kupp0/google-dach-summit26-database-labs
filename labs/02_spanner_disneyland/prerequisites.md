# Prerequisites for Lab 2: Cloud Spanner & BigQuery Disneyland Lab

Before deploying the Terraform infrastructure and starting the lab, you must complete the following setup steps in your Google Cloud environment.

---

## 1. Sandbox / frictionless Account Setup

To avoid resource conflicts and permission issues, you must use an assigned sandbox account.
1. Open the [frictionless accounts sheet](https://docs.google.com/spreadsheets/d/1CU4at6i5aeGfFotrcKLFeytHcIqCKHDmzZMUT1EMCAg/edit?gid=1814460091#gid=1814460091).
2. Select a free account.
3. Mark the account with your name in the **"Printout"** column.

---

## 2. Enable the Cloud Resource Manager API

Terraform requires the Cloud Resource Manager API to dynamically look up project information and configure the Google Provider context.

In your Google Cloud Shell (or active terminal), run this command:

```bash
gcloud services enable cloudresourcemanager.googleapis.com --project=$(gcloud config get-value project)
```

> [!IMPORTANT]
> If you do not enable this API first, Terraform will fail to initialize data sources with the error:
> `Error: Error when reading or editing Project: Cloud Resource Manager API has not been used in project before or it is disabled.`

---

## 3. Create Workspace Directory & Configuration Files

Prepare a clean workspace in your Cloud Shell:

```bash
# 1. Create and enter a clean project directory
mkdir my-terraform-project && cd my-terraform-project

# 2. Create the two required Terraform configuration files
touch main.tf outputs.tf
```

---

## 4. Networking Requirements (For Cloud Workstations User)

If you or other participants plan to use **Cloud Workstations** instead of Cloud Shell:
* You must enable **Private NAT** in your VPC network.
* A dedicated VPC network setup and a subnet must be pre-provisioned in the `europe-west1` region.
* Ensure the service accounts have permissions to join resources into this subnet.
