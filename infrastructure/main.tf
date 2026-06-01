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
}

module "cloud_workstations" {
  source = "./cloud_workstations"

  project_id = var.project_id
  region     = var.region
  vpc_id     = module.networking.vpc_id
  subnet_id  = module.networking.subnet_id

  depends_on = [module.gcp_setup]
}
