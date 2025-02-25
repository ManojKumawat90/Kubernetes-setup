# Kubernetes Master Node Setup Script

## Overview

This script automates the setup of a Kubernetes master node on Ubuntu 22.04.5 LTS using containerd as the container runtime. It performs essential tasks such as disabling swap, loading required kernel modules, applying Kubernetes-specific sysctl settings, installing containerd and Kubernetes components (kubeadm, kubelet, kubectl), and initializing the master node. Additionally, it installs Calico for networking, Helm, the NGINX Ingress Controller, and cert-manager for TLS certificate management. The script also prompts for a hostname during execution (defaulting to `manoj-k8s-master` if no input is provided).

## Prerequisites

- Ubuntu 22.04.5 LTS
- Root or sudo privileges
- Reliable internet connectivity

## Script Details

The script performs the following steps:

1. **Prompt for Hostname:**  
   The script asks for a hostname and defaults to `manoj-k8s-master` if none is provided.

2. **Disable Swap:**  
   Swap is disabled and the corresponding entries in `/etc/fstab` are commented out.

3. **Load Required Kernel Modules:**  
   The script ensures that the `overlay` and `br_netfilter` modules are loaded, which are required for container networking.

4. **Apply Kubernetes Sysctl Settings:**  
   It sets network parameters such as enabling IP forwarding and ensuring proper iptables settings.

5. **Install Essential Dependencies:**  
   Installs tools like `net-tools`, `curl`, `gnupg2`, and others required for subsequent installations.

6. **Install and Configure Containerd:**  
   Containerd is installed, configured for systemd cgroup support, and restarted/enabled.

7. **Install Kubernetes Components:**  
   Installs `kubelet`, `kubeadm`, and `kubectl` at specific versions and holds their versions to avoid unwanted upgrades.

8. **Initialize the Kubernetes Master Node:**  
   The script runs `kubeadm init` to initialize the master node and sets up the kubectl configuration for the root user.

9. **Apply Calico Network Plugin:**  
   Calico is applied as the network plugin for pod networking.

10. **Store the Worker Join Command:**  
    The worker join command is stored in `/root/join_command.sh` for later use.

11. **Remove Control-Plane Taint:**  
    The taint that prevents pods from being scheduled on the master node is removed to allow scheduling.

12. **Install Helm and NGINX Ingress Controller:**  
    Helm is installed via snap, and the NGINX Ingress Controller is deployed using Helm. The service is patched with the node's external IP.

13. **Install Cert-Manager:**  
    Cert-manager is installed for automatic TLS certificate management.

## How to Run

1. **Save the Script:**  
   Save the script as `setup-master.sh`.

2. **Make It Executable:**  
   ```bash
   chmod +x setup-master.sh

