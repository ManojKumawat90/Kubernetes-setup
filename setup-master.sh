#!/bin/bash
set -e

# Prompt for hostname with default value
read -p "Enter the hostname for this node (default: manoj-k8s-master): " NEW_HOSTNAME
NEW_HOSTNAME=${NEW_HOSTNAME:-manoj-k8s-master}
echo "Setting hostname to ${NEW_HOSTNAME}..."
sudo hostnamectl set-hostname "${NEW_HOSTNAME}"

# Function to wait for APT locks to be released and kill unattended-upgrade if needed
wait_for_apt_lock() {
  echo "Waiting for APT locks to be released..."
  while sudo fuser /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || pgrep -fl unattended-upgrade >/dev/null; do
    UP=$(pgrep -fl unattended-upgrade || true)
    if [ -n "$UP" ]; then
      echo "Found unattended-upgrade process: $UP. Killing it..."
      sudo pkill -9 unattended-upgrade || true
    fi
    echo "APT is locked. Waiting 5 seconds..."
    sleep 5
  done
  echo "APT locks are free. Proceeding..."
}

echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "Loading required kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf >/dev/null
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

echo "Applying Kubernetes sysctl settings..."
cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf >/dev/null
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl -p /etc/sysctl.d/kubernetes.conf

echo "Installing essential dependencies..."
wait_for_apt_lock
sudo apt-get update -y
wait_for_apt_lock
sudo apt-get install -y net-tools curl gnupg2 software-properties-common apt-transport-https ca-certificates

echo "Installing containerd..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg --yes
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" --yes
wait_for_apt_lock
sudo apt-get update -y
wait_for_apt_lock
sudo apt-get install -y containerd.io

echo "Configuring containerd..."
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "Installing Kubernetes components..."
sudo mkdir -p /etc/apt/keyrings
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmour -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
wait_for_apt_lock
sudo apt-get update -y
wait_for_apt_lock
sudo apt-get install -y kubelet=1.28.4-1.1 kubeadm=1.28.4-1.1 kubectl=1.28.4-1.1
sudo apt-mark hold kubelet kubeadm kubectl

echo "Initializing Kubernetes master node..."
sudo kubeadm init

echo "Kubernetes master node initialized."

echo "Setting up kubectl configuration..."
sudo mkdir -p /root/.kube
sudo cp -f /etc/kubernetes/admin.conf /root/.kube/config
sudo chown $(id -u):$(id -g) /root/.kube/config

echo "Applying Calico network plugin..."
sudo kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

echo "Storing the join command for worker nodes..."
kubeadm token create --print-join-command | sudo tee /root/join_command.sh

echo "Removing control-plane taint to allow pod scheduling on the master..."
sudo kubectl taint nodes ${NEW_HOSTNAME} node-role.kubernetes.io/control-plane:NoSchedule-

echo "Installing Helm..."
sudo snap install helm --classic

echo "Adding and updating the ingress-nginx repository..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

echo "Installing the NGINX Ingress Controller..."
helm install nginx-ingress ingress-nginx/ingress-nginx --set controller.publishService.enabled=true

echo "Patching the ingress-nginx service with the external IP..."
IP=$(hostname -I | awk '{print $1}')
kubectl patch svc nginx-ingress-ingress-nginx-controller -n default -p "{\"spec\": {\"type\": \"LoadBalancer\", \"externalIPs\":[\"$IP\"]}}"

echo "Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.1/cert-manager.yaml

echo "Kubernetes master node setup completed!"
