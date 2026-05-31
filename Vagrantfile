Vagrant.configure("2") do |config|
  config.vm.box_check_update = false

  config.vm.define "debian", primary: true do |debian|
    debian.vm.box      = "debian/bookworm64"
    debian.vm.hostname = "mywebapp-debian"

    debian.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"

    debian.vm.provider "virtualbox" do |vb|
      vb.name   = "mywebapp-debian"
      vb.memory = 1024
      vb.cpus   = 2
      vb.gui    = false
    end

    debian.vm.provision "shell",
      inline: "DEFAULT_USER=vagrant bash /vagrant/deploy/install.sh",
      privileged: true
  end

  config.vm.define "runner", autostart: false do |runner|
    runner.vm.box      = "bento/ubuntu-24.04"
    runner.vm.hostname = "vm-runner"

    runner.vm.network "private_network", ip: "192.168.56.10"

    runner.vm.provider "virtualbox" do |vb|
      vb.name   = "vm-runner"
      vb.memory = 1024
      vb.cpus   = 2
      vb.gui    = false
    end

    runner.vm.provision "shell", privileged: true, inline: <<~SHELL
      set -euo pipefail
      cd /vagrant
      bash deploy/runner-bootstrap.sh
    SHELL
  end

  config.vm.define "target", autostart: false do |target|
    target.vm.box      = "bento/ubuntu-24.04"
    target.vm.hostname = "target"

    target.vm.network "private_network", ip: "192.168.56.11"

    target.vm.network "forwarded_port", guest: 80, host: 8088, host_ip: "127.0.0.1"

    target.vm.provider "virtualbox" do |vb|
      vb.name   = "target"
      vb.memory = 1024
      vb.cpus   = 2
      vb.gui    = false
    end

    target.vm.provision "shell", privileged: true, inline: <<~SHELL
      set -euo pipefail
      cd /vagrant
      bash deploy/target-node-install.sh
    SHELL
  end

end