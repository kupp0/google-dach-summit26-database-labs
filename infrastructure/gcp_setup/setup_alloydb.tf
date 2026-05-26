# ==============================================================================
# DACH Summit 2026: Lab 1 AlloyDB & Vertex AI Core Infrastructure Setup
# ==============================================================================

variable "project_id" {
  description = "The Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for database clusters"
  type        = string
  default     = "europe-west1"
}

# Retrieve project number dynamically
data "google_project" "project" {
  project_id = var.project_id
}

#--- 1. Enable Required GCP APIs ---
resource "google_project_service" "alloydb_apis" {
  for_each = toset([
    "alloydb.googleapis.com",
    "compute.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "aiplatform.googleapis.com"
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

#--- 2. IAM Policy Bindings for Vertex AI integration ---
# Grants Vertex AI User role to the AlloyDB Service Agent to generate vector embeddings
resource "google_project_iam_member" "alloydb_vertex_user" {
  project    = var.project_id
  role       = "roles/aiplatform.user"
  member     = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-alloydb.iam.gserviceaccount.com"
  depends_on = [google_project_service.alloydb_apis]
}

#--- 3. AlloyDB Cluster Setup ---
resource "google_alloydb_cluster" "default" {
  cluster_id = "search-cluster"
  project    = var.project_id
  location   = var.region

  network_config {
    network = "projects/${var.project_id}/global/networks/default"
  }

  initial_user {
    password = "alloydb-hackathon-password"
  }

  depends_on = [google_project_service.alloydb_apis]
}

#--- 4. AlloyDB Instance Setup with database flags ---
resource "google_alloydb_instance" "primary" {
  cluster       = google_alloydb_cluster.default.name
  instance_id   = "search-primary"
  instance_type = "PRIMARY"

  database_flags = {
    "google_ml_integration.enable_model_support"             = "on"
    "google_ml_integration.enable_faster_embedding_generation" = "on"
    "scann.max_allowed_num_levels"                            = "3"
  }

  depends_on = [google_alloydb_cluster.default]
}
