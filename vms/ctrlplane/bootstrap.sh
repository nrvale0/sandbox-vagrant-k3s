#!/bin/bash

[ ! -n "$DEBUG" ] || set -x

set -ue


function onerr {
    echo 'Cleaning up after error...'
    exit -1
}
trap onerr ERR


function  prep () {
    echo 'Prepping the system to take k8s/k3s control plane...'
    (set -x;
     apt-get update;
     apt-get upgrade -y;
     apt-get install -y httpie curl docker.io)

    if ! command -v inspec > /dev/null 2>&1 ; then
	echo 'Installing InSpec for validation testing...'
	(set -x;
	 wget -c -O /tmp/inspec-install.sh https://omnitruck.chef.io/install.sh;
	 chmod +x /tmp/inspec-install.sh;
	 /tmp/inspec-install.sh;
	 echo "export PATH=/opt/chef/embedded/bin:${PATH}" | tee /etc/profile.d/99-chef.sh)
    fi
}


function k3s-bootstrap () {
    echo 'Installing k8s/k3s control plane...'
    if ! command -v k3s > /dev/null 2>&1; then
	(set -x;
	 wget -c -O /tmp/k3s-install.sh https://get.k3s.io;
	 chmod +x /tmp/k3s-install.sh;
	 /tmp/k3s-install.sh)
    else
	echo 'k3s binary already installed...'
    fi

    (set -x;
     systemctl enable k3s.service;
     systemctl restart k3s.service;
     systemctl status k3s.service;
     k3s kubectl get node;
     cat /var/lib/rancher/k3s/server/node-token > /vagrant/node-token;
     cp /usr/local/bin/k3s /vagrant/;
     cp /etc/rancher/k3s/k3s.yaml /vagrant/)

    echo 'Applying manifests from /vagrant/manifests...'
    (set -x;
     k3s kubectl apply --overwrite=true -R -f /vagrant/manifests)
}


function main () {
    prep
    k3s-bootstrap
}


main
