# ==============================================================================
# DACH Summit 2026: Lab 3 Shared Services, IAM, and Bastion Configuration
# ==============================================================================

#--- 1. Dedicated Search Application Runtime Service Account ---
resource "google_service_account" "search_backend_sa" {
  account_id   = "search-backend-sa"
  display_name = "Search Backend Service Account"
  project      = var.project_id
}

# Grant required roles to the search application service account
resource "google_project_iam_member" "sa_roles" {
  for_each = toset([
    "roles/alloydb.client",
    "roles/logging.logWriter",
    "roles/artifactregistry.repoAdmin",
    "roles/serviceusage.serviceUsageConsumer",
    "roles/aiplatform.user",
    "roles/discoveryengine.editor",
    "roles/storage.objectAdmin",
    "roles/secretmanager.secretAccessor"
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.search_backend_sa.email}"

  depends_on = [google_project_service.alloydb_apis]
}

#--- 2. Build and Service Identity Coordinators ---
resource "google_project_service_identity" "cloudbuild_sa" {
  provider = google-beta
  project  = var.project_id
  service  = "cloudbuild.googleapis.com"
  depends_on = [google_project_service.alloydb_apis]
}

resource "google_project_iam_member" "cloudbuild_sa_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.repoAdmin"
  member  = "serviceAccount:${google_project_service_identity.cloudbuild_sa.email}"
}

# Compute Engine service account roles for Cloud Build steps
resource "google_project_iam_member" "default_compute_sa_roles" {
  for_each = toset([
    "roles/storage.objectViewer",
    "roles/artifactregistry.repoAdmin",
    "roles/logging.logWriter"
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

#--- 3. GCE Bastion Host configuration for private connectivity ---
resource "google_service_account" "bastion_sa" {
  account_id   = "bastion-sa"
  display_name = "Bastion Service Account"
  project      = var.project_id
}

resource "google_project_iam_member" "bastion_sa_roles" {
  for_each = toset([
    "roles/alloydb.client",
    "roles/logging.logWriter",
    "roles/serviceusage.serviceUsageConsumer"
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.bastion_sa.email}"
}

resource "google_compute_instance" "bastion" {
  name         = "search-demo-bastion"
  machine_type = "e2-micro"
  zone         = "${var.region}-b"
  project      = var.project_id

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = var.vpc_id
    subnetwork = var.subnet_id
  }

  service_account {
    email  = google_service_account.bastion_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  # Tag with allow-iap-ssh to inherit the common networking firewall rule
  tags = ["bastion", "allow-iap-ssh"]
}

#--- 4. Shared Artifact Registry & Storage Buckets ---
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "search-demo"
  description   = "Search Demo Docker Repository"
  format        = "DOCKER"
  project       = var.project_id
  depends_on    = [google_project_service.alloydb_apis]
}

resource "google_storage_bucket" "image_bucket" {
  name          = "${var.project_id}-search-demo-images"
  location      = var.region
  project       = var.project_id
  force_destroy = true

  uniform_bucket_level_access = true
  depends_on                  = [google_project_service.alloydb_apis]
}
