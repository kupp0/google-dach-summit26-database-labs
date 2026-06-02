# ==============================================================================
# 0. Terraform Configuration
# ==============================================================================
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.11.0"
    }
  }
}

# ==============================================================================
# 1. Enable Required APIs
# ==============================================================================
resource "google_project_service" "enabled_apis" {
  for_each = toset([
    "spanner.googleapis.com",
    "bigquery.googleapis.com",
    "bigqueryconnection.googleapis.com"
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# ==============================================================================
# 2. Cloud Spanner Setup
# ==============================================================================
resource "google_spanner_instance" "disneyland" {
  name             = "disneyland"
  project          = var.project_id
  config           = "regional-${var.region}"
  display_name     = "Disneyland AI Agents"
  edition          = "ENTERPRISE"
  processing_units = 100
  depends_on       = [google_project_service.enabled_apis]
}

resource "google_spanner_database" "agent_lab" {
  instance            = google_spanner_instance.disneyland.name
  name                = "agent-lab"
  project             = var.project_id
  database_dialect    = "GOOGLE_STANDARD_SQL"
  deletion_protection = false
}

# ==============================================================================
# 3. BigQuery Setup & Connection
# ==============================================================================
resource "google_bigquery_dataset" "disney_dataset" {
  dataset_id = "disney"
  location   = var.region
  project    = var.project_id
  depends_on = [google_project_service.enabled_apis]
}

resource "google_bigquery_connection" "spanner_conn" {
  connection_id = "spanner_conn"
  location      = var.region
  project       = var.project_id
  friendly_name = "Spanner Connector"
  cloud_resource {}
  depends_on    = [google_project_service.enabled_apis]
}

# Mitigates GCP's global directory registration delay for new service accounts
resource "time_sleep" "wait_for_connection_sa" {
  create_duration = "15s"
  depends_on      = [google_bigquery_connection.spanner_conn]
}

# ==============================================================================
# 4. Authoritative IAM Admin Permissions (Simplified Integration)
# ==============================================================================
resource "google_project_iam_binding" "spanner_admin_bridge" {
  project = var.project_id
  role    = "roles/spanner.admin" # <-- Grants combined metadata schema + full database row read access
  members = ["serviceAccount:${google_bigquery_connection.spanner_conn.cloud_resource[0].service_account_id}"]
  
  depends_on = [time_sleep.wait_for_connection_sa]
}

# Holds final bridge linking to give global control plane caching time to sync
resource "time_sleep" "wait_for_iam" {
  create_duration = "60s"
  depends_on      = [
    google_project_iam_binding.spanner_admin_bridge,
    google_spanner_database.agent_lab
  ]
}

# ==============================================================================
# 5. BigQuery External Dataset (The Spanner Bridge)
# ==============================================================================
resource "google_bigquery_dataset" "spanner_external_dataset" {
  dataset_id  = "disneyland_spanner_external"
  location    = var.region
  project     = var.project_id  
  
  external_dataset_reference {
    external_source = "google-cloudspanner:/projects/${var.project_id}/instances/${google_spanner_instance.disneyland.name}/databases/${google_spanner_database.agent_lab.name}"
    connection      = google_bigquery_connection.spanner_conn.id
  }
  
  depends_on = [time_sleep.wait_for_iam]
}
