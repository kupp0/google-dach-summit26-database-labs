# ==============================================================================
# DACH Summit 2026: Google Cloud Workstations config for participant workspaces
# ==============================================================================

# Enable Workstations API (if not already handled in gcp_setup)
resource "google_project_service" "workstation" {
  project            = var.project_id
  service            = "workstations.googleapis.com"
  disable_on_destroy = false
}

resource "google_workstations_workstation_cluster" "default" {
  workstation_cluster_id = "workstation-cluster"
  location              = var.region
  network               = var.vpc_id
  subnetwork            = var.subnet_id
  project               = var.project_id

  depends_on = [google_project_service.workstation]
}

resource "google_workstations_workstation_config" "default" {
  workstation_config_id  = "workstation-config"
  workstation_cluster_id = google_workstations_workstation_cluster.default.workstation_cluster_id
  location              = var.region
  project               = var.project_id

  host {
    gce_instance {
      machine_type                = "e2-standard-4"
      boot_disk_size_gb          = 50
      disable_public_ip_addresses = true
      shielded_instance_config {
        enable_secure_boot = true
        enable_vtpm        = true
      }
    }
  }

  container {
    image = "us-central1-docker.pkg.dev/cloud-workstations-images/predefined/code-oss:latest"
  }

  persistent_directories {
    mount_path = "/home"
    gce_pd {
      size_gb        = 100
      disk_type      = "pd-balanced"
      reclaim_policy = "RETAIN"
    }
  }

  depends_on = [google_workstations_workstation_cluster.default]
}

resource "google_workstations_workstation" "default" {
  workstation_id         = "my-workstation"
  workstation_config_id  = google_workstations_workstation_config.default.workstation_config_id
  workstation_cluster_id = google_workstations_workstation_cluster.default.workstation_cluster_id
  location              = var.region
  project               = var.project_id

  depends_on = [google_workstations_workstation_config.default]
}
