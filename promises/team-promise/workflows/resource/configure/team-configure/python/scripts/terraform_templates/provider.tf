terraform {
  required_version = ">= 1.0"
  required_providers {
    gitea = {
      source  = "go-gitea/gitea"
      version = "~> 0.6.0"
    }
  }
}

provider "gitea" {
  base_url = var.gitea_base_url
  token    = var.gitea_admin_token
}