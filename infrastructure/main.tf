module "networking" {
  source = "./networking"

  project_id   = var.project_id
  region       = var.region
  network_name = var.network_name
  subnet_name  = var.subnet_name
  subnet_cidr  = var.subnet_cidr
  iap_member   = var.iap_member
}

module "gcp_setup" {
  source = "./gcp_setup"

  project_id = var.project_id
  region     = var.region
  vpc_id     = module.networking.vpc_id
}

module "cloud_workstations" {
  source = "./cloud_workstations"

  project_id = var.project_id
  region     = var.region
  vpc_id     = module.networking.vpc_id
  subnet_id  = module.networking.subnet_id
  workstationuser = var.iap_member

  depends_on = [module.gcp_setup]
}

resource "google_project_iam_member" "user_ai_developer" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = var.iap_member
}
