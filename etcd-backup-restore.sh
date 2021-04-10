#!/bin/bash

# Install etcd - make sure to have a version that fits the etcd version of Kubernetes
sudo apt -y install wget
export ETCD_REL="3.3.13"
wget https://github.com/etcd-io/etcd/releases/download/v${ETCD_REL}/etcd-v${ETCD_REL}-linux-amd64.tar.gz

tar xvf etcd-v${ETCD_REL}-linux-amd64.tar.gz

cd etcd-v${ETCD_REL}-linux-amd64
sudo mv etcd etcdctl /usr/local/bin 


# Get more details via "man etcdctl"
export ETCDCTL_API=3

######################################################
# STOP apiserver 
######################################################

# Change it to your k8s-master
export NODE_IP=10.X.X.X
export NODE_NAME=k8s-master

# Create a backup
etcdctl snapshot save snapshot.db --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key

# Restore and use current cluster
# make sure --name <NODE-NAME> is in --initial-cluster=<NODE-NAME>=https://<NODE-IP>:2380
# this creates a "new" cluster, but with the existing initial cluster token
etcdctl snapshot restore snapshot.db --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key --initial-advertise-peer-urls=https://$NODE_IP:2380 --initial-cluster=$NODE_NAME=https://$NODE_IP:2380 --skip-hash-check --data-dir=/var/lib/etcd-from-backup --name $NODE_NAME
# Hint: This is the "complicated" way. You can simplify this command to achieve the same - feel free to find it out.

# update /etc/kubernetes/manifests/etcd.yaml to match the --data-dir directory from restore

######################################################
# Start API server
######################################################