variable "gitea_base_url" {
  description = "Base URL of the Gitea instance"
  type        = string
  default     = "https://gitea-http.gitea.svc.cluster.local:443"
}

variable "gitea_admin_token" {
  description = "Admin API token for Gitea instance"
  type        = string
  sensitive   = true
}