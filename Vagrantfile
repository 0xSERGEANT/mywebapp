Vagrant.configure("2") do |config|
  config.vm.box = "debian/bookworm64"
  config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"
  config.vm.provider "virtualbox" do |vb|
    vb.name   = "mywebapp-debian"
    vb.memory = 1024
    vb.cpus   = 2
  end

  config.vm.provision "shell",
    path: "scripts/setup.sh",
    privileged: true
end
