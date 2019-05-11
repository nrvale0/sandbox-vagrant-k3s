#!/bin/bash

[ ! -n "$DEBUG" ] || set -x

set -ue


function onerr {
    echo 'Cleaning up after error...'
    exit -1
}
trap onerr ERR


function prep () {

    echo 'Disable IPv6 to keep k3s networking nice and simple..'
    (set -x;
     sysctl -w net.ipv6.conf.all.disable_ipv6=1;
     sysctl -w net.ipv6.conf.default.disable_ipv6=1;
     cat <<EOF | tee /etc/sysctl.d/10-ipv6.conf
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOF
     )

    echo 'Prepping node to act as k8s/k3s worker...'
    (set -x;
     apt-get update;
     DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
		    apt-get install -y wget curl facter llmnrd libnss-resolve tshark)

    if ! command -v inspec > /dev/null 2>&1 ; then
	echo 'Installing InSpec for validation testing...'
	(set -x;
	 wget -c -O /tmp/inspec-install.sh https://omnitruck.chef.io/install.sh;
	 chmod +x /tmp/inspec-install.sh;
	 /tmp/inspec-install.sh;
	 echo "export PATH=/opt/chef/embedded/bin:${PATH}" | tee /etc/profile.d/99-chef.sh)
    fi

    echo 'Disable IPv6 to keep k3s networking nice and simple..'
    (set -x;
     sysctl -w net.ipv6.conf.all.disable_ipv6=1;
     sysctl -w net.ipv6.conf.default.disable_ipv6=1;
     cat <<EOF | tee /etc/sysctl.d/10-ipv6.conf
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOF
    )

    echo 'Enable LLMNR...'
    (set -x;
     cat <<EOF | tee /etc/systemd/network/enp0s8.network
[Match]
Name=enp0s8

[Network]
LLMNR=yes
EOF
     cat <<EOF | tee /etc/systemd/resolved.conf
[Resolve]
LLMNR=yes
EOF
     systemctl daemon-reload;
     systemctl restart systemd-networkd;
     systemctl restart systemd-resolved)
}


function k3s-bootstrap () {
    if ! test -e /usr/local/bin/k3s; then
	echo 'Bootstrapping k8s/k3s agent...'
	(set -x;
	 cp /vagrant/k3s /usr/local/bin/;
	 local node_token="$(cat /vagrant/node-token)";
	 local ipaddress="$(facter networking.interfaces.enp0s8.ip)";
	 /usr/local/bin/k3s agent --token "${node_token}" --node-ip "${ipaddress}" --server https://k8scontrol0:6443)
    else
	echo 'k3s is already installed...'
    fi

    (set -x;
     systemctl enable k3s.service;
     systemctl restart k3s.service;
     systemctl status k3s.service)
}


function main () {
    prep
    k3s-bootstrap
}


main
