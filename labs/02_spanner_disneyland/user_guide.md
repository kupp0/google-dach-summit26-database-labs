# Lab 2: Disneyland Agentic Codelab with Cloud Spanner & BigQuery

In this lab, you will build a federated query "bridge" linking **Cloud Spanner** and **BigQuery**. This allows real-time analytic queries across transactional and warehouse data. Then, you'll deploy the **MCP Toolbox** to grant agentic AI tools the ability to query your transactional database in real-time.

---

## Objective
- Deploy Cloud Spanner and BigQuery infrastructure using Terraform.
- Establish a federated query connection between BigQuery and Spanner.
- Inject mock Disneyland Singer dataset records.
- Install and configure the **MCP Toolbox** for agentic AI integration.
- Run verification federated queries in BigQuery Studio.

---

## Phase 1: Environment Setup

In your Google Cloud Shell, run these commands to prepare your workspace:

```bash
# Create and enter a clean project directory
mkdir my-terraform-project && cd $_

# Create the two required Terraform configuration files
touch main.tf outputs.tf
```

---

## Phase 2: Infrastructure Provisioning (Terraform)

### 1. Populate `main.tf`
Open `main.tf` in your editor (e.g., `nano main.tf`), paste the following configuration, and save:

```terraform
#--- Configuration & Variables ---
provider "google" {
  project = var.project_id
  region  = "europe-west1"
}

variable "project_id" {
  description = "The Google Cloud Project ID"
  type        = string
}

#--- 1. Cloud Spanner Setup ---
resource "google_spanner_instance" "disneyland" {
  name             = "disneyland"
  config           = "regional-europe-west1"
  display_name     = "Disneyland AI Agents"
  edition          = "ENTERPRISE"
  processing_units = 100
}

resource "google_spanner_database" "agent_lab" {
  instance         = google_spanner_instance.disneyland.name
  name             = "agent-lab"
  database_dialect = "GOOGLE_STANDARD_SQL"
}

#--- 2. BigQuery Setup ---
resource "google_bigquery_dataset" "disney_dataset" {
  dataset_id = "disney"
  location   = "europe-west1"
}

resource "google_bigquery_connection" "spanner_conn" {
  connection_id = "spanner_conn"
  location      = "europe-west1"
  friendly_name = "Spanner Connector"
  cloud_spanner {
    database = "projects/${var.project_id}/instances/${google_spanner_instance.disneyland.name}/databases/${google_spanner_database.agent_lab.name}"
  }
}

#--- 3. External Table (The Bridge) ---
resource "google_bigquery_table" "spanner_external_table" {
  dataset_id = google_bigquery_dataset.disney_dataset.dataset_id
  table_id   = "external_spanner_table"
  external_data_configuration {
    autodetect    = true
    connection_id = google_bigquery_connection.spanner_conn.name
    source_format = "GOOGLE_CLOUD_SPANNER"
    source_uris   = ["projects/${var.project_id}/instances/${google_spanner_instance.disneyland.name}/databases/${google_spanner_database.agent_lab.name}/tables/Singers"]
  }
}
```

### 2. Populate `outputs.tf`
Open `outputs.tf`, paste the following output definitions, and save:

```terraform
output "spanner_instance_id" {
  value = google_spanner_instance.disneyland.id
}

output "bq_spanner_connection_id" {
  value = google_bigquery_connection.spanner_conn.name
}

output "mcp_verify_command" {
  value = "gcloud mcp-toolbox list-resources --project=${var.project_id} --location=europe-west1"
}
```

---

## Phase 3: Deployment & Data Injection

> [!IMPORTANT]
> ⚠️ **Terraform Directory**:
> Make sure you are inside the folder containing your Terraform files. If you aren't already, navigate to it using:
> `cd my-terraform-project`

Run these shell commands in order to initialize, deploy, and populate the database:

```bash
# 1. Initialize and Deploy Terraform Infrastructure
terraform init
terraform apply -var="project_id=$(gcloud config get-value project)" -auto-approve

# 2. Create the Spanner Database Schema (DDL)
gcloud spanner databases ddl update agent-lab \
  --instance=disneyland \
  --ddl='CREATE TABLE Singers (SingerId INT64, Name STRING(1024)) PRIMARY KEY (SingerId)'

# 3. Insert Sample Disneyland Records
gcloud spanner rows insert --instance=disneyland --database=agent-lab \
  --table=Singers --data=SingerId=1,Name="Mickey Mouse"

gcloud spanner rows insert --instance=disneyland --database=agent-lab \
  --table=Singers --data=SingerId=2,Name="Donald Duck"
```

---

## Phase 4: Install and Configure MCP Toolbox

Enable agentic, AI-driven database interactions using the Google Cloud MCP Toolbox:

```bash
# 1. Install the toolbox component
gcloud components install mcp-toolbox

# 2. Verify the active resources and connections
gcloud mcp-toolbox list-resources --project=$(gcloud config get-value project) --location=europe-west1
```

---

## Phase 5: Real-Time Bridge Verification Query

Validate that the federated bridge is working correctly by executing a live query in BigQuery that fetches data directly from the Cloud Spanner transactional table.

1. Go to the **BigQuery Studio** in the Google Cloud Console.
2. Open a new **SQL Query** tab.
3. Paste and run the query below (replace `YOUR_PROJECT_ID` with your actual project ID):

```sql
SELECT * 
FROM `YOUR_PROJECT_ID.disney.external_spanner_table`
```

The output should show your Spanner records:
| SingerId | Name         |
| :---     | :---         |
| 1        | Mickey Mouse |
| 2        | Donald Duck  |

---

## Clean Up

> [!WARNING]
> **Ongoing Costs**:
> To avoid incurring ongoing charges for the regional Spanner instance, destroy the infrastructure once finished:
> `terraform destroy -var="project_id=$(gcloud config get-value project)" -auto-approve`
