output "worker_ssh" {
  description = "SSH command to access the worker VM"
  value       = "ssh ansible@${var.worker_mgmt_ip}"
}

output "db_ssh" {
  description = "SSH command to access the database VM"
  value       = "ssh ansible@${var.db_mgmt_ip}"
}

output "app_url" {
  description = "Application URL after Ansible deployment"
  value       = "http://${var.worker_mgmt_ip}/"
}

output "inventory_written" {
  description = "Path of the generated Ansible inventory"
  value       = local_file.inventory.filename
}

output "next_steps" {
  description = "Steps to complete the deployment"
  value       = <<-EOF

    ┌──────────────────────────────────────────────────────────────┐
    │  Terraform provisioning complete.  Next steps:               │
    │                                                              │
    │  1. Wait for cloud-init on both VMs (~60 s):                 │
    │       ssh ansible@${var.worker_mgmt_ip} cloud-init status --wait  │
    │       ssh ansible@${var.db_mgmt_ip} cloud-init status --wait      │
    │                                                              │
    │  2. Install Ansible collections (once):                      │
    │       cd iac/ansible                                         │
    │       ansible-galaxy collection install -r requirements.yml  │
    │                                                              │
    │  3. Create the vault file:                                   │
    │       cp inventory/group_vars/vault.yml.example \            │
    │          inventory/group_vars/vault.yml                      │
    │       ansible-vault encrypt inventory/group_vars/vault.yml   │
    │                                                              │
    │  4. Run the playbook:                                        │
    │       ansible-playbook site.yml --ask-vault-pass             │
    │                                                              │
    │  5. Open http://${var.worker_mgmt_ip}/ in your browser           │
    └──────────────────────────────────────────────────────────────┘
  EOF
}
