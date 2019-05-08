# coding: utf-8
Vagrant.require_version ">= 2.2.4"
VAGRANTFILE_API_VERSION = "2"

ENV['VAGRANT_NO_COLOR'] = 'true'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/bionic64"

  config.vm.define "k8scontrol0", autostart: true do |ctrlplane|
    ctrlplane.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
    end

    ctrlplane.vm.hostname = "k8scontrol0"
    ctrlplane.vm.network :private_network, :auto_network => true
    ctrlplane.vm.provision :hosts, :autoconfigure => true, :sync_hosts => true

    ctrlplane.vm.network "forwarded_port", guest: 6443, host: 6443 # k3s API port

    ctrlplane.vm.provision "install"  , type: "shell", keep_color: false, run: "always", path: "vms/ctrlplane/bootstrap.sh"
    ctrlplane.vm.provision "validate" , type: "shell", keep_color: false, run: "always", path: "vms/ctrlplane/validate.sh"
  end

  ["kubelet0-az0", "kubelet0-az1", "kubelet0-az2"].each do |kubelet|
    config.vm.define "#{kubelet}".chomp, autostart: true do |worker|
      worker.vm.provider "virtualbox" do |vb|
        vb.memory = "1024"
      end

      worker.vm.hostname = "#{kubelet}"
      worker.vm.network :private_network, :auto_network => true
      worker.vm.provision :hosts, :autoconfigure => true, :sync_hosts => true

      worker.vm.provision "install"  , type: "shell", keep_color: false, run: "always", path: "vms/worker/bootstrap.sh"
      worker.vm.provision "validate" , type: "shell", keep_color: false, run: "always", path: "vms/worker/validate.sh"
    end
  end
end
