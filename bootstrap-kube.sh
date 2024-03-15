#!/bin/bash

# This script has been tested on Ubuntu 20.04
# For other versions of Ubuntu, you might need some tweaking

echo "[TASK 0] Install essential packages"
apt install -y net-tools curl ssh software-properties-common >/dev/null 2>&1

echo "[TASK 1] Install containerd runtime"
apt update  >/dev/null 2>&1
apt install -y containerd apt-transport-https >/dev/null 2>&1
sudo install -m 0755 -d /etc/apt/keyrings >/dev/null 2>&1
mkdir /etc/containerd
containerd config default > /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd >/dev/null 2>&1

echo "[TASK 2] Add apt repo for kubernetes"
sudo apt-get install -y apt-transport-https ca-certificates curl gpg >/dev/null 2>&1
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg >/dev/null 2>&1
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null 2>&1

echo "[TASK 3] Installing kubeadm, kubelet and kubectl"
sudo apt-get install -y apt-transport-https ca-certificates curl gpg >/dev/null 2>&1
sudo apt update >/dev/null 2>&1
sudo apt-get install -y kubelet kubeadm kubectl >/dev/null 2>&1
sudo apt-mark hold kubelet kubeadm kubectl > /dev/null 2>&1
echo 'KUBELET_EXTRA_ARGS="--fail-swap-on=false"' > /etc/default/kubelet
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
swapoff -a
systemctl restart kubelet

echo "[TASK 4] Enable ssh password authentication"
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
systemctl reload sshd

echo "[TASK 5] Set root password"
echo -e "kubeadmin\nkubeadmin" | passwd root >/dev/null 2>&1
echo "export TERM=xterm" >> /etc/bash.bashrc

echo "[TASK 6] Install additional packages"
apt install -y net-tools >/dev/null 2>&1

echo "[TASK 7] Enable the Necessary Kernel Modules"

sudo modprobe overlay >/dev/null 2>&1
sudo modprobe br_netfilter >/dev/null 2>&1
echo 'net.bridge.bridge-nf-call-ip6tables = 1' | sudo tee /etc/sysctl.d/kubernetes.conf > /dev/null 2>&1
echo 'net.bridge.bridge-nf-call-iptables = 1' | sudo tee /etc/sysctl.d/kubernetes.conf > /dev/null 2>&1
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/kubernetes.conf > /dev/null 2>&1
sysctl --system  >/dev/null 2>&1
echo 'overlay' | sudo tee /etc/modules-load.d/containerd.conf > /dev/null 2>&1
echo 'br_netfilter' | sudo tee //etc/modules-load.d/containerd.conf > /dev/null 2>&1

echo 'net.bridge.bridge-nf-call-ip6tables = 1' | sudo tee /etc/sysctl.d/kubernetes.conf > /dev/null 2>&1
echo 'net.bridge.bridge-nf-call-iptables = 1' | sudo tee /etc/sysctl.d/kubernetes.conf > /dev/null 2>&1
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/kubernetes.conf > /dev/null 2>&1

if (systemctl -q is-active containerd)
  then
      rm /etc/containerd/config.toml
      systemctl restart containerd
  else
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt update
    sudo apt install -y containerd.io
    mkdir -p /etc/containerd
    containerd config default>/etc/containerd/config.toml
    sudo systemctl restart containerd
    sudo systemctl enable containerd   
fi
sudo systemctl enable kubelet >/dev/null 2>&1

#######################################
# To be executed only on master nodes #
#######################################

if [[ $(hostname) =~ .*master.* ]]
then

  echo "[TASK 8] Pull required containers"
  kubeadm config images pull --cri-socket /run/containerd/containerd.sock  >/dev/null 2>&1

  echo "[TASK 9] Initialize Kubernetes Cluster"
  kubeadm init   --pod-network-cidr=10.244.0.0/16   --upload-certs   --control-plane-endpoint=$(hostname) --ignore-preflight-errors=all  --cri-socket /run/containerd/containerd.sock >> /root/kubeinit.log 2>&1

  echo "[TASK 10] Copy kube admin config to root user .kube directory"
  mkdir -p $HOME/.kube
  cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  chown $(id -u):$(id -g) $HOME/.kube/config  
  export KUBECONFIG=/etc/kubernetes/admin.conf

  echo "[TASK 11] Deploy Flannel network"
  kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kube-flannel.yml > /dev/null 2>&1

  echo "[TASK 12] Generate and save cluster join command to /joincluster.sh"
  joinCommand=$(kubeadm token create --print-join-command 2>/dev/null) 
  echo "$joinCommand --ignore-preflight-errors=all" > /joincluster.sh

fi

#######################################
# To be executed only on worker nodes #
#######################################

if [[ $(hostname) =~ .*worker.* ]]
then
  echo "[TASK 8] Join node to Kubernetes Cluster"
  apt install -y sshpass >/dev/null 2>&1
  sshpass -p "kubeadmin" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no kmaster.lxd:/joincluster.sh /joincluster.sh 2>/tmp/joincluster.log
  bash /joincluster.sh >> /tmp/joincluster.log 2>&1
fi
