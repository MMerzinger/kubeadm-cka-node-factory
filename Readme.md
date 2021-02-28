# Kubeadm Node Factory

This repo is part of my blog post  [How I prepared for the CKA exam](https://acloudjourney.io/blog/how-i-prepared-for-the-cka-exam). 

This repo contains small helper scripts to setup virtual machines on GCP, that have all dependencies for a K8s node preinstalled. These dependencies are listed in the [K8s documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/) for creating clusters with Kubeadm.

Make sure to set a default region and zone with `gcloud config set compute/region <REGION>` respectively `gcloud config set compute/zone <ZONE>`.

The used machine types are not included in the free tier of GCP.

Currently there is no K8s version specified. The script installes the lastest available version provided through the Ubuntu repositories. Testing was done with 1.20.1 and 1.20.4.

The objective of these scripts is to help you to bootstrap K8s clusters and experiment with different CNIs or other cluster administration related topics.

## Hints

The CIDR of my regional subnet was 10.172.0.0/20. Make sure you use a CIDR in your network that does not overlap with the CIDRs used in this repo.

## Cluster Setup

Create a master node:

```
gcloud compute instances create k8s-master --machine-type n2-standard-2 \
    --image ubuntu-2004-focal-v20210129  --image-project ubuntu-os-cloud \
    --metadata-from-file startup-script=./setup-vm.sh
```

Create 3 worker nodes:

```
gcloud compute instances create k8s-worker{0..2} --machine-type n2-standard-2 \
    --image ubuntu-2004-focal-v20210129  --image-project ubuntu-os-cloud \
    --metadata-from-file startup-script=./setup-vm.sh
```

Now you have a 4 node cluster. You can now go on and install K8s with Kubeadm. Each of the following section intializes the master node and explains how to setup the CNI. The setup of the worker nodes is similar in all cases, hence it is described once.

## Build a Cluster with Weave

Login to the master node via ssh:

```
gcloud compute ssh k8s-master
```

Initialize the master node:
(Hint: If you are too fast, the setup script may still be running. You can check this via `tail /var/log/syslog`)

```
# Switch to root
sudo -i
# Get the IP of the node
export CONTROLPLANE_IP=$(hostname -I | awk -F ' ' '{print $1}')
# Initialize the master
kubeadm init --control-plane-endpoint $CONTROLPLANE_IP --pod-network-cidr 10.0.0.0/22 --service-cidr 10.96.0.0/22
```

Setup kubectl to connect to the initialized master node. These commands are also shown by the output of `kubeadm init`:

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
source <(kubectl completion bash)
```

Use the following command to install Weave:

```
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&env.IPALLOC_RANGE=10.0.0.0/22"
```

Weave uses per default 10.32.0.0/12 as pod CIDR. You can change it when applying config via a query parameter `&env.IPALLOC_RANGE=10.0.0.0/16`. You can find more details in the [docs](https://www.weave.works/docs/net/latest/kubernetes/kube-addon/) or in [GitHub](https://github.com/weaveworks/weave/issues/2736).

Go on and initialize the worker nodes as described in [Setup the Worker](#Setup-the-Worker "Goto etup-the-Worker").

## Build a Cluster with Flannel

Login to the master node via ssh:
```
gcloud compute ssh k8s-master
```

Initialize the master node:
```
# Switch to root
sudo -i
# Get the IP of the node
export CONTROLPLANE_IP=$(hostname -I | awk -F ' ' '{print $1}')
# Initialize the master
kubeadm init --control-plane-endpoint $CONTROLPLANE_IP --pod-network-cidr 10.244.0.0/16 --service-cidr 10.96.0.0/24
```

Setup kubectl to connect to the initialized master node. These commands are also shown by the output of `kubeadm init`:

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
source <(kubectl completion bash)
```

Use the following command to install Flannel:

```
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

Flannel uses 10.244.0.0/16 as the default pod CIDR. To make it simple, I used this CIDR in the privious `kubeadm init` command. To use a custom CIDR, you have to edit the YAMLs before applying them or by editing the file "net-conf.json" in the config map "kube-flannel-cfg".

Go on and initialize the worker nodes as described in [Setup the Worker](#Setup-the-Worker "Goto etup-the-Worker").

## Build a Cluster with Calico

Login to the master node via ssh:
```
gcloud compute ssh k8s-master
```

Initialize the master node:
```
# Switch to root
sudo -i
# Get the IP of the node
export CONTROLPLANE_IP=$(hostname -I | awk -F ' ' '{print $1}')
# Initialize the master
kubeadm init --control-plane-endpoint $CONTROLPLANE_IP --pod-network-cidr 192.168.0.0/16 --service-cidr 10.96.0.0/24
```

Setup kubectl to connect to the initialized master node. These commands are also shown by the output of `kubeadm init`:

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
source <(kubectl completion bash)
```

Use the following command to install Calico:

```
kubectl apply -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
kubectl apply -f https://docs.projectcalico.org/manifests/custom-resources.yaml
```

If you want to change the pod CIDR of Calico, you have to adapt it in the "custom-resources.yaml" file. Otherwise it uses the default 192.168.0.0/16. Please find more information in the [Calico docs](https://docs.projectcalico.org/getting-started/kubernetes/quickstart).

Go on and initialize the worker nodes as described in [Setup the Worker](#Setup-the-Worker "Goto etup-the-Worker").

## Setup the Worker

The setup of the worker nodes is idenpendent of the CNI, therefore you can use the same commands for all workers. Login to the worker nodes via ssh. Use separate terminals or a terminal multiplexer to work on them in parallel:

```
gcloud compute ssh k8s-worker0
gcloud compute ssh k8s-worker1
gcloud compute ssh k8s-worker2
```

Now you can initialize each worker by switching to root and applying the join command provided by the output of `kubeadm init`:

```
# Switch to root
sudo -i

echo "----------------------------------------------------------------------"
echo "Insert the kubeadm join command as shown in the output of kubeadm init"
echo "----------------------------------------------------------------------"
```

Your cluster is now ready. Go on and experiment with it :) 

## Delete the Cluster

After experimenting with the cluster you can simply delete it with the following command:
```
gcloud compute instances delete k8s-master k8s-worker{0..2}
```

## Important Notes

This repo was used to prepare for the CKA exam or just to experiment with Kubeadm cluster. You can find my blog post to this repo [here](https://acloudjourney.io/blog/how-i-prepared-for-the-cka-exam). These scripts are just a collection of commands that you can find in the K8s docs, to simplify cluster setup. Please adapt and use them to prepare yourself for the CKA exam as well. I do not provide any kind of support to these scripts.