output "spanner_instance_id" {
  value       = google_spanner_instance.disneyland.id
  description = "The fully qualified unique identifier for the Spanner Instance."
}

output "bq_spanner_connection_id" {
  value       = google_bigquery_connection.spanner_conn.id
  description = "The unique identification path for the BigQuery External Connection."
}

output "mcp_verify_command" {
  value       = "gcloud alpha agent-registry mcp-servers list --project=${var.project_id} --location=${var.region}"
  description = "The terminal verification command for students to validate their Model Context Protocol service registry."
}