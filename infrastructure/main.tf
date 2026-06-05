terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.34.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 7.35.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

locals {
  # If the member string already has an IAM prefix, use it as is. Otherwise, default to prepending "user:".
  iap_member = can(regex("^[a-z]+:", var.iap_member)) ? var.iap_member : "user:${var.iap_member}"
}

module "networking" {
  source = "./networking"

  project_id   = var.project_id
  region       = var.region
  network_name = var.network_name
  subnet_name  = var.subnet_name
  subnet_cidr  = var.subnet_cidr
  iap_member   = local.iap_member
}

module "gcp_setup" {
  source = "./gcp_setup"

  project_id                = var.project_id
  region                    = var.region
  vpc_id                    = module.networking.vpc_id
  private_vpc_connection_id = module.networking.private_vpc_connection_id
  subnet_id                 = module.networking.subnet_id
  iap_member                = local.iap_member

  providers = {
    google      = google
    google-beta = google-beta
  }
}


module "cloud_workstations" {
  source = "./cloud_workstations"

  project_id = var.project_id
  region     = var.region
  vpc_id     = module.networking.vpc_id
  subnet_id  = module.networking.subnet_id
  workstationuser = local.iap_member

  depends_on = [module.gcp_setup]
}

resource "google_project_iam_member" "user_roles" {
  for_each = toset([
    "roles/aiplatform.user",
    "roles/spanner.admin",
    "roles/mcp.toolUser",
    "roles/oauthconfig.editor"
  ])

  project = var.project_id
  role    = each.key
  member  = local.iap_member
}

module "spanner_lab" {
  source = "./02_spanner_lab"
  project_id = var.project_id
  region     = var.region
}


