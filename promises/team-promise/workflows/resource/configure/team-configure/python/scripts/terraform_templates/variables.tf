variable "gitea_base_url" {
  description = "Base URL of the Gitea instance"
  type        = string
  default     = "https://host.docker.internal:8443"
}

variable "gitea_admin_token" {
  description = "Admin API token for Gitea instance"
  type        = string
  sensitive   = true
}
