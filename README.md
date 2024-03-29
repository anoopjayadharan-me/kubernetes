# Setting up K8s Cluster using LXC/LXD

Tested on Ubuntu 20.04.6 LTS and kubernetes version 1.28

**Note:** For development purpose and not recommended for Production use. 

### Prerequisites

An Ubuntu 20.04.6 LTS VM with 4 vCPU and 10GB RAM

If you have not setup the VM yet please refer to the vagrant repo [link to repo](https://github.com/Anoopdharan1/vagrant)

### Verify the system details kernel, memory and cpu 

```
uname -a

free -m

nproc

```
### Verify LXC/LXD is installed

```
which lxc

which lxd

```

### Install LXD

```
sudo apt update

sudo snap install lxd

systemctl status snap.lxd.daemon

```

### Add vagrant user to the group

```
sudo adduser vagrant lxd

sudo adduser vagrant sudo

logout

```

Log in and ensure the user gets added to the the group lxd

### Initialize LXD

```
lxd init

**Provide default option for all except this:**

Name of the storage backend to use (zfs, ceph, btrfs, dir, lvm) [default=zfs]: dir

```

### Start the service if not running

```
systemctl status snap.lxd.daemon

systemctl start snap.lxd.daemon

git clone [link to repo](https://github.com/Anoopdharan1/kubernetes)

chmod 775 kubelx

./kubelx provision

```

### List and verify the k8s cluster

```
lxc list

```

##### Exec into kmaster node

```

lxc exec kmaster bash

```

#### Verifying cluster version

```
kubectl cluster-info

```

#### Verifying Nodes

```
kubectl get nodes

kubectl get nodes -o wide

kubectl get pods -n kube-system

```

### Let's create one nginx deployment

```
kubectl create deploy nginx --image nginx --replicas=2

```

#### Creating Service for deployment nginx

```
kubectl expose deploy nginx --port 80 --type NodePort

kubectl get all

```

### Try accessing Nginx through any of the worker node's IP address

```

curl -I <nodeip:nodeport>

*nodeip can be found using command "kubectl get nodes -o wide"

*nodeport can be found using command "kubectl get svc -o wide"

```

### We can access nginx.. !!!

#### To access k8s cluster without execing into kmaster node
### On the Ubuntu Host Machine:

```
Add entry for kmaster in the /etc/hosts file

ping kmaster

curl -LO https://dl.k8s.io/release/v1.28.7/bin/linux/amd64/kubectl

sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

```
### Create .kube directory

```
mkdir $HOME/.kube

```

### copy config from kmaster into .kube directory

```
lxc file pull kmaster/etc/kubernetes/admin.conf  ~/.kube/config

ls -l ~/.kube

```

### Try to access k8s cluster without execing into kmaster node

```
kubectl get node

```

### Get a shell to the container

```
kubectl exec -it <podname> -- /bin/bash

```

### Optional
#### Enable kubectl Autocompletion in Bash

```
sudo apt-get install -y bash-completion

echo "source <(kubectl completion bash)" >> ~/.bashrc

echo 'alias k=kubectl' >>~/.bashrc

echo 'complete -o default -F __start_kubectl k' >>~/.bashrc

source ~/.bashrc

```
