#!/bin/bash

[ ! -n "$DEBUG" ] || set -x

set -ue


function onerr {
    echo 'Cleaning up after error...'
    exit -1
}
trap onerr ERR


function validate () {
    echo 'Validating k8s/k3s control plane...'
    (set -x;
     inspec detect --chef-license=accept-silent;
     inspec exec /vagrant/vms/ctrlplane/validate.d/inspec)
}


function main () {
    validate
}


main
