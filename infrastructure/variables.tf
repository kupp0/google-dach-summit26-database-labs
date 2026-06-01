variable "project_id" {
  description = "The ID of the project where resources will be created."
  type        = string
}

variable "region" {
  description = "The region where resources will be created."
  type        = string
  default     = "europe-west3"
}

variable "network_name" {
  description = "The name of the VPC network."
  type        = string
  default     = "workstation-network"
}

variable "subnet_name" {
  description = "The name of the subnet."
  type        = string
  default     = "workstation-subnet"
}

variable "subnet_cidr" {
  description = "The CIDR range for the subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "iap_member" {
  description = "The IAM member string for the user to grant IAP access to (e.g., user:ogt-admin@google.com)."
  type        = string
}

