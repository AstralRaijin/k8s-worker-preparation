#!/bin/bash

# Exit on any error
set -e

# Function to display script usage
function display_usage() {
    echo "Usage: $0 -h <hostname>"
    echo "  -h    Set the hostname for this worker node"
    exit 1
}

# Process command line arguments
while getopts "h:" opt; do
    case $opt in
        h) NEW_HOSTNAME=$OPTARG ;;
        *) display_usage ;;
    esac
done

# Check if hostname parameter was provided
if [ -z "$NEW_HOSTNAME" ]; then
    display_usage
fi

# Set hostname
echo "Setting hostname to $NEW_HOSTNAME..."
sudo hostnamectl set-hostname $NEW_HOSTNAME
echo "127.0.0.1 $NEW_HOSTNAME" | sudo tee -a /etc/hosts

# Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install dependencies
echo "Installing dependencies..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Disable swap
echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/swap/s/^/#/' /etc/fstab

# Set up required kernel modules
echo "Setting up kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Set up required sysctl parameters
echo "Setting up sysctl parameters..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# Install container runtime (containerd)
echo "Installing containerd..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y containerd.io

# Configure containerd
echo "Configuring containerd..."
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Add Kubernetes apt repository
echo "Adding Kubernetes repository..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo tee /etc/apt/trusted.gpg.d/kubernetes.asc
echo "deb https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes components
echo "Installing Kubernetes components..."
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Enable kubelet service
echo "Enabling kubelet service..."
sudo systemctl enable kubelet

echo "========================================================"
echo "Worker node preparation complete!"
echo "You can now join this node to your Kubernetes cluster by running:"
echo "sudo kubeadm join <control-plane-host>:<control-plane-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
echo "Get this command from your control plane node by running:"
echo "sudo kubeadm token create --print-join-command"
echo "========================================================"
