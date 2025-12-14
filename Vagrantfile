Vagrant.configure("2") do |config|
  config.vm.box = "debian/bookworm64"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "512"
    vb.cpus = 1
  end

  config.vm.define "db1" do |db1|
    db1.vm.hostname = "db1"
    db1.vm.network "private_network", ip: "192.168.20.20", virtualbox__intnet: "red2"
    db1.vm.provision "shell", path: "db1_aprov.sh"
  end

  config.vm.define "db2" do |db2|
    db2.vm.hostname = "db2"
    db2.vm.network "private_network", ip: "192.168.20.30", virtualbox__intnet: "red2"
    db2.vm.provision "shell", path: "db2_aprov.sh"
  end

  config.vm.define "dbHaproxy" do |dbHaproxy|
    dbHaproxy.vm.hostname = "dbHaproxy"
    dbHaproxy.vm.network "private_network", ip: "192.168.20.10", virtualbox__intnet: "red2"
    dbHaproxy.vm.network "private_network", ip: "192.168.20.11", virtualbox__intnet: "red2"
    dbHaproxy.vm.provision "shell", path: "dbHaproxy_aprov.sh"
  end

  config.vm.define "serverNfs" do |serverNfs|
    serverNfs.vm.hostname = "serverNfs"
    serverNfs.vm.network "private_network", ip: "192.168.10.10", virtualbox__intnet: "red1"
    serverNfs.vm.network "private_network", ip: "192.168.20.5", virtualbox__intnet: "red2"
    serverNfs.vm.provision "shell", path: "serverNfs_aprov.sh"
  end

  config.vm.define "web1" do |web1|
    web1.vm.hostname = "web1"
    web1.vm.network "private_network", ip: "192.168.10.11", virtualbox__intnet: "red1"
    web1.vm.provision "shell", path: "web_aprov.sh"
  end

  config.vm.define "web2" do |web2|
    web2.vm.hostname = "web2"
    web2.vm.network "private_network", ip: "192.168.10.12", virtualbox__intnet: "red1"
    web2.vm.provision "shell", path: "web_aprov.sh"
  end

  config.vm.define "balanceador" do |balanceador|
    balanceador.vm.hostname = "balanceador"
    balanceador.vm.network "private_network", ip: "192.168.10.2", virtualbox__intnet: "red1"
    balanceador.vm.network "forwarded_port", guest: 80, host: 8085
    balanceador.vm.provision "shell", path: "balanceador_aprov.sh"
  end

end