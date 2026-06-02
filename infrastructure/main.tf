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

resource "google_project_iam_member" "user_ai_developer" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = local.iap_member
}

