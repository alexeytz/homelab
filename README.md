# Homelab — Infrastructure Automation Scripts

Reproducible scripts for Kubernetes deployment, Redis Enterprise lifecycle management, VPN infrastructure, and multi-platform system automation.

## Contents

### Kubernetes 1.31 on RHEL 8
Complete cluster provisioning from bare metal to production-ready. Includes prerequisites, containerd, kubeadm, Calico CNI, MetalLB, and NGINX ingress.

**Tutorial:** [Deploy K8s 1.31 on RHEL 8](https://youtu.be/bRulDwualeU)

### Redis Enterprise on Kubernetes
Full lifecycle management for Redis Enterprise clusters on Kubernetes — install, configure, troubleshoot, and uninstall.

- **Cluster provisioning:** Custom Resource Definitions, admission webhooks, certificate management
- **Database management:** Create/configure databases with ReJSON and search modules
- **Ingress:** SSL/TLS passthrough with NGINX ingress for UI and REST API endpoints
- **Multi-cluster:** Active-active cross-cluster replication configuration
- **Troubleshooting:** Stuck namespace cleanup, DNS automation, pod diagnostics

**Tutorials:**
- [Install Redis Enterprise Cluster](https://youtu.be/qSjYFDKAVaY)
- [Uninstall Redis Enterprise Cluster](https://youtu.be/HJf7nbCutKw)
- [Add Redis Database](https://youtu.be/V8iQRFFVfqg)
- [Configure Database Ingress](https://youtu.be/0QHg22mK_tA)

### VPN Infrastructure
Hysteria2 and VLESS proxy configurations with user management scripts.

### Vagrant Environments
Multi-platform VM configurations (RHEL 8/9/10, Ubuntu, Alpine) with automation scripts for consistent lab environments.

### Proxmox & LXC
Container management and OpenMediaVault integration scripts.

## Author

Alexey Tsygankov — SRE / Platform Engineer
[LinkedIn](https://www.linkedin.com/in/alexey-g-tsygankov) | [Portfolio](https://alexey.tsygankov.net)