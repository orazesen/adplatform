# AdPlatform Infrastructure - Terraform Root

terraform {
  required_version = ">= 1.5"
  
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    ovh = {
      source  = "ovh/ovh"
      version = "~> 0.36"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    # Configure your state backend
    # bucket = "adplatform-terraform-state"
    # key    = "production/terraform.tfstate"
    # region = "us-east-1"
  }
}

# Provider selection based on variable
locals {
  is_hetzner = var.provider == "hetzner"
  is_ovh     = var.provider == "ovh"
  is_aws     = var.provider == "aws"
  is_gcp     = var.provider == "gcp"
}

# Hetzner Module
module "hetzner" {
  count  = local.is_hetzner ? 1 : 0
  source = "./modules/hetzner"
  
  environment    = var.environment
  server_count   = var.server_count
  server_type    = var.server_type
  location       = var.region
  network_cidr   = var.private_network_cidr
  ssh_keys       = var.ssh_keys
  tags           = var.tags
}

# OVH Module
module "ovh" {
  count  = local.is_ovh ? 1 : 0
  source = "./modules/ovh"
  
  environment    = var.environment
  server_count   = var.server_count
  server_plan    = var.server_type
  region         = var.region
  ssh_keys       = var.ssh_keys
  tags           = var.tags
}

# AWS Module
module "aws" {
  count  = local.is_aws ? 1 : 0
  source = "./modules/aws"
  
  environment    = var.environment
  instance_count = var.server_count
  instance_type  = var.server_type
  region         = var.region
  vpc_cidr       = var.private_network_cidr
  ssh_keys       = var.ssh_keys
  tags           = var.tags
}

# GCP Module
module "gcp" {
  count  = local.is_gcp ? 1 : 0
  source = "./modules/gcp"
  
  environment     = var.environment
  instance_count  = var.server_count
  machine_type    = var.server_type
  region          = var.region
  network_cidr    = var.private_network_cidr
  ssh_keys        = var.ssh_keys
  labels          = var.tags
}

# Outputs (unified across providers)
output "control_plane_ips" {
  value = local.is_hetzner ? module.hetzner[0].control_plane_ips : (
    local.is_ovh ? module.ovh[0].control_plane_ips : (
    local.is_aws ? module.aws[0].control_plane_ips : (
    local.is_gcp ? module.gcp[0].control_plane_ips : []
  )))
}

output "data_plane_ips" {
  value = local.is_hetzner ? module.hetzner[0].data_plane_ips : (
    local.is_ovh ? module.ovh[0].data_plane_ips : (
    local.is_aws ? module.aws[0].data_plane_ips : (
    local.is_gcp ? module.gcp[0].data_plane_ips : []
  )))
}

output "edge_ips" {
  value = local.is_hetzner ? module.hetzner[0].edge_ips : (
    local.is_ovh ? module.ovh[0].edge_ips : (
    local.is_aws ? module.aws[0].edge_ips : (
    local.is_gcp ? module.gcp[0].edge_ips : []
  )))
}

output "private_network_cidr" {
  value = var.private_network_cidr
}

output "ansible_inventory" {
  value = jsonencode({
    all = {
      children = {
        control_plane = {
          hosts = {
            for idx, ip in (local.is_hetzner ? module.hetzner[0].control_plane_ips : (
              local.is_ovh ? module.ovh[0].control_plane_ips : (
              local.is_aws ? module.aws[0].control_plane_ips : (
              local.is_gcp ? module.gcp[0].control_plane_ips : []
            )))) : "control-${idx}" => {
              ansible_host = ip
            }
          }
        }
        data_plane = {
          hosts = {
            for idx, ip in (local.is_hetzner ? module.hetzner[0].data_plane_ips : (
              local.is_ovh ? module.ovh[0].data_plane_ips : (
              local.is_aws ? module.aws[0].data_plane_ips : (
              local.is_gcp ? module.gcp[0].data_plane_ips : []
            )))) : "data-${idx}" => {
              ansible_host = ip
            }
          }
        }
        edge = {
          hosts = {
            for idx, ip in (local.is_hetzner ? module.hetzner[0].edge_ips : (
              local.is_ovh ? module.ovh[0].edge_ips : (
              local.is_aws ? module.aws[0].edge_ips : (
              local.is_gcp ? module.gcp[0].edge_ips : []
            )))) : "edge-${idx}" => {
              ansible_host = ip
            }
          }
        }
      }
    }
  })
}
