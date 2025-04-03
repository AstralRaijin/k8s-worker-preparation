#!/bin/bash

# Exit on error
set -e

# Check for hostname argument
if [ -z "$1" ]; then
    echo "Usage: $0 <worker_hostname>"
    exit 1
fi

# 1. Set hostname using hostnamectl
sudo hostnamectl set-hostname "$1"
echo "Hostname has been set to: $1"

# 2. Update and install dependencies
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl

# 3. Add Kubernetes repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo tee /etc/apt/trusted.gpg.d/kubernetes.asc
echo "deb https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# 4. Install Kubernetes components
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# 5. Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
echo "Swap status:"
free -h

# 6. Install and configure containerd
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
echo "Containerd status:"
sudo systemctl status containerd

# 7. Kernel modules and sysctl configuration
sudo modprobe br_netfilter
sudo modprobe overlay
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# 8. Clean previous installations (if any)
sudo kubeadm reset -f

echo "Setup complete. Use kubeadm join command to add to cluster."
