# Hetzner Cloud Infrastructure Module

terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

variable "environment" {}
variable "server_count" {}
variable "server_type" {}
variable "location" {}
variable "network_cidr" {}
variable "ssh_keys" {}
variable "tags" {}

# Private Network
resource "hcloud_network" "main" {
  name     = "adplatform-${var.environment}"
  ip_range = var.network_cidr
  
  labels = var.tags
}

resource "hcloud_network_subnet" "main" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = var.network_cidr
}

# SSH Keys
resource "hcloud_ssh_key" "deploy" {
  count      = length(var.ssh_keys)
  name       = "deploy-key-${count.index}"
  public_key = var.ssh_keys[count.index]
}

# Firewall
resource "hcloud_firewall" "main" {
  name = "adplatform-${var.environment}"
  
  # SSH (management only)
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
  
  # HTTP/HTTPS
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
  
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
  
  # Kubernetes API
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "6443"
    source_ips = [
      var.network_cidr
    ]
  }
  
  # Allow all within private network
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "any"
    source_ips = [
      var.network_cidr
    ]
  }
  
  labels = var.tags
}

# Control Plane Servers (1 node)
resource "hcloud_server" "control_plane" {
  count       = 1
  name        = "adplatform-control-${var.environment}-${count.index}"
  server_type = var.server_type
  location    = var.location
  image       = "ubuntu-22.04"
  
  ssh_keys = hcloud_ssh_key.deploy[*].id
  
  firewall_ids = [hcloud_firewall.main.id]
  
  network {
    network_id = hcloud_network.main.id
    ip         = cidrhost(var.network_cidr, 10 + count.index)
  }
  
  labels = merge(var.tags, {
    role = "control-plane"
  })
  
  user_data = templatefile("${path.module}/cloud-init.yaml", {
    hostname = "control-${count.index}"
  })
}

# Data Plane Servers (3 nodes)
resource "hcloud_server" "data_plane" {
  count       = 3
  name        = "adplatform-data-${var.environment}-${count.index}"
  server_type = var.server_type
  location    = var.location
  image       = "ubuntu-22.04"
  
  ssh_keys = hcloud_ssh_key.deploy[*].id
  
  firewall_ids = [hcloud_firewall.main.id]
  
  network {
    network_id = hcloud_network.main.id
    ip         = cidrhost(var.network_cidr, 20 + count.index)
  }
  
  labels = merge(var.tags, {
    role = "data-plane"
  })
  
  user_data = templatefile("${path.module}/cloud-init.yaml", {
    hostname = "data-${count.index}"
  })
}

# Edge Servers (remaining servers)
resource "hcloud_server" "edge" {
  count       = var.server_count - 4  # Total minus control (1) and data (3)
  name        = "adplatform-edge-${var.environment}-${count.index}"
  server_type = var.server_type
  location    = var.location
  image       = "ubuntu-22.04"
  
  ssh_keys = hcloud_ssh_key.deploy[*].id
  
  firewall_ids = [hcloud_firewall.main.id]
  
  network {
    network_id = hcloud_network.main.id
    ip         = cidrhost(var.network_cidr, 30 + count.index)
  }
  
  labels = merge(var.tags, {
    role = "edge"
  })
  
  user_data = templatefile("${path.module}/cloud-init.yaml", {
    hostname = "edge-${count.index}"
  })
}

# Outputs
output "control_plane_ips" {
  value = hcloud_server.control_plane[*].ipv4_address
}

output "data_plane_ips" {
  value = hcloud_server.data_plane[*].ipv4_address
}

output "edge_ips" {
  value = hcloud_server.edge[*].ipv4_address
}

output "private_network_id" {
  value = hcloud_network.main.id
}
