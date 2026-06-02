variable "project_id" {
  description = "The Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for database clusters"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC network"
  type        = string
}

variable "private_vpc_connection_id" {
  description = "The ID of the private VPC connection peering"
  type        = string
  default     = ""
}

