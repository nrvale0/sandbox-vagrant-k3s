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
     apt-get install -y wget curl)

    if ! command -v inspec > /dev/null 2>&1 ; then
	echo 'Installing InSpec for validation testing...'
	(set -x;
	 wget -c -O /tmp/inspec-install.sh https://omnitruck.chef.io/install.sh;
	 chmod +x /tmp/inspec-install.sh;
	 /tmp/inspec-install.sh;
	 echo "export PATH=/opt/chef/embedded/bin:${PATH}" | tee /etc/profile.d/99-chef.sh)
    fi

    echo 'Copying k3s binary...'
    (set -x;
     cp /vagrant/k3s /usr/local/bin/;
     chmod +x /usr/local/bin/k3s)
}


function k3s-bootstrap () {
    echo 'Bootstrapping k8s/k3s agent...'

    local node_token="$(cat /vagrant/node-token)"
    tee /etc/systemd/system/k3s-agent.service <<EOF
[Unit]
Description=k3s agent
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/var/k3s-agent
ExecStart=/usr/local/bin/k3s agent --server https://k8scontrol0:6443 --token ${node_token}
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

    (set -x;
     mkdir -p /var/k3s-agent;
     chmod 644 /etc/systemd/system/k3s-agent.service;
     systemctl enable k3s-agent.service;
     systemctl restart k3s-agent.service)
}


function main () {
    prep
    k3s-bootstrap
}


main
