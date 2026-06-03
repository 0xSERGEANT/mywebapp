variable "libvirt_uri" {
  description = "libvirt connection URI"
  type        = string
  default     = "qemu:///system"
}

variable "ssh_public_key" {
  description = "OpenSSH public key injected into the ansible user on both VMs"
  type        = string
}

variable "ubuntu_image_url" {
  description = "Ubuntu 24.04 LTS (Noble) cloud image URL"
  type        = string
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "libvirt_pool" {
  description = "libvirt storage pool name (created by Terraform if absent)"
  type        = string
  default     = "mywebapp"
}

variable "mgmt_cidr" {
  description = "Management NAT network CIDR (Ansible + internet access)"
  type        = string
  default     = "192.168.100.0/24"
}

variable "private_cidr" {
  description = "Private isolated network CIDR (worker ↔ db only)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "worker_mgmt_ip" {
  description = "Worker management IP (must be within mgmt_cidr)"
  type        = string
  default     = "192.168.100.10"
}

variable "worker_private_ip" {
  description = "Worker private IP (must be within private_cidr)"
  type        = string
  default     = "10.0.1.10"
}

variable "db_mgmt_ip" {
  description = "Database management IP (must be within mgmt_cidr)"
  type        = string
  default     = "192.168.100.11"
}

variable "db_private_ip" {
  description = "Database private IP (must be within private_cidr)"
  type        = string
  default     = "10.0.1.11"
}

variable "memory_mib" {
  description = "RAM per VM in MiB"
  type        = number
  default     = 1024
}

variable "vcpus" {
  description = "vCPU count per VM"
  type        = number
  default     = 1
}

variable "disk_bytes" {
  description = "Root disk size per VM in bytes"
  type        = number
  default     = 10737418240 # 10 GiB
}
