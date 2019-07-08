#!/bin/bash

: ${K3S_VERSION:-v0.5.0}

[ ! -n "$DEBUG" ] || set -x

set -ue


function onerr {
    echo 'Cleaning up after error...'
    exit -1
}
trap onerr ERR


function  prep () {
    echo 'Prepping the system to take k8s/k3s control plane...'

    echo 'Disable IPv6 to keep k3s networking nice and simple..'
    (set -x;
     sysctl -w net.ipv6.conf.all.disable_ipv6=1;
     sysctl -w net.ipv6.conf.default.disable_ipv6=1;
     cat <<EOF | tee /etc/sysctl.d/10-ipv6.conf
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOF
     )

    echo 'Installing necessary/useful packages...'
    (set -x;
     apt-get update;
     apt-get upgrade -y;
     DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
		    apt-get install -y httpie curl facter)

    echo 'Checking for pre-installed InSpec...'
    if ! command -v inspec > /dev/null 2>&1 ; then
	echo 'Installing InSpec for validation testing...'
	(set -x;
	 wget -c -O /tmp/inspec-install.sh https://omnitruck.chef.io/install.sh;
	 chmod +x /tmp/inspec-install.sh;
	 /tmp/inspec-install.sh -P inspec;
	 echo "export PATH=/opt/chef/embedded/bin:${PATH}" | tee /etc/profile.d/99-chef.sh)
    fi
}


function k3s-bootstrap () {
    if ! test -e /usr/local/bin/k3s; then
	echo 'Downloading k3s installer...'
	(set -x;
	 wget -c -O - https://get.k3s.io > /usr/local/bin/k3s;
	 chmod +x /usr/local/bin/k3s;
	 local ipaddress="$(facter networking.interfaces.enp0s8.ip)";
	 /usr/local/bin/k3s server --bind-address "${ipaddress}" --node-ip "${ipaddress}" --flannel-iface enp0s8 --disable-agent)
    else
	echo 'k3s is already installed...'
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
