locals {
  mgmt_gateway   = cidrhost(var.mgmt_cidr, 1)
  mgmt_prefix    = split("/", var.mgmt_cidr)[1]
  private_prefix = split("/", var.private_cidr)[1]
}

resource "libvirt_pool" "mywebapp" {
  name = var.libvirt_pool
  type = "dir"
  path = "/var/lib/libvirt/images/${var.libvirt_pool}"
}

resource "libvirt_network" "mgmt" {
  name      = "mywebapp-mgmt"
  mode      = "nat"
  addresses = [var.mgmt_cidr]

  dhcp { enabled = false }
  dns  { enabled = false }
}

resource "libvirt_network" "private" {
  name      = "mywebapp-private"
  mode      = "none"
  addresses = [var.private_cidr]

  dhcp { enabled = false }
}

resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu-24.04-noble-base.qcow2"
  pool   = libvirt_pool.mywebapp.name
  source = var.ubuntu_image_url
  format = "qcow2"

  depends_on = [libvirt_pool.mywebapp]
}

resource "libvirt_volume" "worker_disk" {
  name           = "mywebapp-worker.qcow2"
  pool           = libvirt_pool.mywebapp.name
  base_volume_id = libvirt_volume.ubuntu_base.id
  size           = var.disk_bytes
}

resource "libvirt_cloudinit_disk" "worker_init" {
  name = "mywebapp-worker-init.iso"
  pool = libvirt_pool.mywebapp.name

  user_data = templatefile("${path.module}/cloud-init-user.yaml.tftpl", {
    hostname               = "worker"
    ansible_ssh_public_key = var.ssh_public_key
  })

  network_config = templatefile("${path.module}/cloud-init-network.yaml.tftpl", {
    mgmt_mac       = "52:54:00:ab:cd:10"
    mgmt_ip        = var.worker_mgmt_ip
    mgmt_prefix    = local.mgmt_prefix
    gateway        = local.mgmt_gateway
    private_mac    = "52:54:00:ab:cd:20"
    private_ip     = var.worker_private_ip
    private_prefix = local.private_prefix
  })
}

resource "libvirt_domain" "worker" {
  name      = "mywebapp-worker"
  memory    = var.memory_mib
  vcpu      = var.vcpus
  cloudinit = libvirt_cloudinit_disk.worker_init.id

  cpu { mode = "host-passthrough" }

  network_interface {
    network_id     = libvirt_network.mgmt.id
    mac            = "52:54:00:ab:cd:10"
    wait_for_lease = false
  }

  network_interface {
    network_id     = libvirt_network.private.id
    mac            = "52:54:00:ab:cd:20"
    wait_for_lease = false
  }

  disk {
    volume_id = libvirt_volume.worker_disk.id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }

  depends_on = [libvirt_network.mgmt, libvirt_network.private]
}

resource "libvirt_volume" "db_disk" {
  name           = "mywebapp-db.qcow2"
  pool           = libvirt_pool.mywebapp.name
  base_volume_id = libvirt_volume.ubuntu_base.id
  size           = var.disk_bytes
}

resource "libvirt_cloudinit_disk" "db_init" {
  name = "mywebapp-db-init.iso"
  pool = libvirt_pool.mywebapp.name

  user_data = templatefile("${path.module}/cloud-init-user.yaml.tftpl", {
    hostname               = "db"
    ansible_ssh_public_key = var.ssh_public_key
  })

  network_config = templatefile("${path.module}/cloud-init-network.yaml.tftpl", {
    mgmt_mac       = "52:54:00:ab:cd:11"
    mgmt_ip        = var.db_mgmt_ip
    mgmt_prefix    = local.mgmt_prefix
    gateway        = local.mgmt_gateway
    private_mac    = "52:54:00:ab:cd:21"
    private_ip     = var.db_private_ip
    private_prefix = local.private_prefix
  })
}

resource "libvirt_domain" "db" {
  name      = "mywebapp-db"
  memory    = var.memory_mib
  vcpu      = var.vcpus
  cloudinit = libvirt_cloudinit_disk.db_init.id

  cpu { mode = "host-passthrough" }

  network_interface {
    network_id     = libvirt_network.mgmt.id
    mac            = "52:54:00:ab:cd:11"
    wait_for_lease = false
  }

  network_interface {
    network_id     = libvirt_network.private.id
    mac            = "52:54:00:ab:cd:21"
    wait_for_lease = false
  }

  disk {
    volume_id = libvirt_volume.db_disk.id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }

  depends_on = [libvirt_network.mgmt, libvirt_network.private]
}

resource "local_file" "inventory" {
  content = templatefile("${path.module}/inventory.ini.tftpl", {
    worker_ansible_host = var.worker_mgmt_ip
    worker_private_ip   = var.worker_private_ip
    db_ansible_host     = var.db_mgmt_ip
    db_private_ip       = var.db_private_ip
  })
  filename        = "${path.module}/../ansible/inventory/hosts.ini"
  file_permission = "0644"
}
