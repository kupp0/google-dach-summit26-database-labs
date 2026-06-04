# ==============================================================================
# DACH Summit 2026: Lab 1 AlloyDB & Vertex AI Core Infrastructure Setup
# ==============================================================================

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
    "aiplatform.googleapis.com",
    "workstations.googleapis.com",
    "cloudaicompanion.googleapis.com",
    "artifactregistry.googleapis.com",
    "developerknowledge.googleapis.com",
    "run.googleapis.com",
    "discoveryengine.googleapis.com",
    "iam.googleapis.com",
    "orgpolicy.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "secretmanager.googleapis.com"
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
  depends_on = [google_project_service.alloydb_apis, google_alloydb_instance.primary]
}

#--- 3. AlloyDB Cluster Setup ---
resource "google_alloydb_cluster" "default" {
  cluster_id = "search-cluster"
  project    = var.project_id
  location   = var.region
  deletion_protection = false

  network_config {
    network = var.vpc_id
  }

  initial_user {
    password = "alloydb-hackathon-password"
  }

  depends_on = [
    google_project_service.alloydb_apis,
    var.private_vpc_connection_id
  ]
}


#--- 4. AlloyDB Instance Setup with database flags ---
resource "google_alloydb_instance" "primary" {
  provider      = google-beta
  cluster       = google_alloydb_cluster.default.name
  instance_id   = "search-primary"
  instance_type = "PRIMARY"

  machine_config {
    cpu_count = 2
  }

  database_flags = {
    "google_ml_integration.enable_model_support"               = "on"
    "google_ml_integration.enable_faster_embedding_generation" = "on"
    "alloydb_ai_nl.enabled"                                    = "on"
    "google_ml_integration.enable_ai_query_engine"             = "on"
    "scann.enable_zero_knob_index_creation"                    = "on"
    "password.enforce_complexity"                              = "on"
    "google_db_advisor.enable_auto_advisor"                    = "on"
    "google_db_advisor.auto_advisor_schedule"                  = "EVERY 24 HOURS"
    "parameterized_views.enabled"                              = "on"
  }

  observability_config {
    enabled                 = true
    max_query_string_length = 10240
    track_wait_event_types  = true
    track_wait_events       = true
    query_plans_per_minute  = 20
  }

  depends_on = [google_alloydb_cluster.default]
}
