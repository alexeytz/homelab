# homelab

Infrastructure-as-code for a self-hosted lab: virtualization, Kubernetes,
networking and AI serving, built to be rebuilt. Every environment here is
reproducible from scripts rather than remembered — the point is that a rebuild is
a procedure, not an archaeology project.

Kept for my own records, and public in case any of it saves someone else an
afternoon. Several sections have their own README with more detail, and six of
them have a video walkthrough.

## Layout

| Directory | What's in it |
|---|---|
| **`Vagrant/`** | Reproducible multi-distribution VM environments — RHEL 8/9/10, Ubuntu 22.04, Alpine 3.22. Config-driven: pick a distro config, get a named, addressed, provisioned cluster of VMs |
| **`K8/RH8v1.31/`** | Bare-metal Kubernetes 1.31 on RHEL 8 from nothing — containerd, kubeadm, Calico, MetalLB, NGINX ingress, as numbered steps |
| **`K8/RSE/`** | Redis Enterprise on Kubernetes: cluster lifecycle, databases, TLS ingress, active-active, and the cleanup utilities you need when it goes wrong |
| **`ProxMox/`** | Hypervisor-side helpers — LXC shell access, podman-hosted local services, OpenMediaVault for NFS/SMB/rsync |
| **`VPN/`** | Three gateway stacks — Hysteria2, VLESS, and VLESS-over-Hysteria2 — each with user management scripts and config templates |
| **`Ai/`** | Local model serving and tooling — Ollama, open-webui, Claude Code — plus `vllm-benchmarks/`, a measured NVLink A/B on a dual RTX 3090 pair |
| **`Ubuntu/`** | Host prep and post-clone fixes |
| **`common/`** | `bash_lib.sh` — shared logging and helpers used across the scripts |
| **`tools-settings/`** | Terminal and tooling configuration |

## Walkthroughs

| Topic | Video |
|---|---|
| Creating a Vagrant environment | https://youtu.be/yBE_PNqfqmg |
| Kubernetes 1.31 on RHEL 8 | https://youtu.be/bRulDwualeU |
| Redis Enterprise cluster — install | https://youtu.be/qSjYFDKAVaY |
| Redis Enterprise cluster — uninstall | https://youtu.be/HJf7nbCutKw |
| Adding a Redis database (REDB) | https://youtu.be/V8iQRFFVfqg |
| Configuring REDB ingress | https://youtu.be/0QHg22mK_tA |

## Vagrant — the part most likely to be useful

`CREATE_ENV_config.sh` plus a `config_*.sh` file builds an environment folder and
writes its `config.yaml`. You choose the distro, hostname prefix, IP range, RAM,
CPU count and node count; provisioning does the rest.

```bash
cd Vagrant
./CREATE_ENV_config.sh config_RHEL9.sh   # creates the environment folder
cd _RHEL9 && vagrant up
```

Three layers, so nothing is written twice:

- **`BluePrint/`** — the template environment. The `Vagrantfile` reads
  `config.yaml`, so adding a distro means adding a config, not editing Ruby.
- **`COMMON/`** — provisioning shared by distro *family*: `RHx-*` for Red Hat,
  `Ux-*` for Ubuntu, plus per-release overrides. Each family has a
  config/script pair, so declarative settings stay separate from imperative steps.
- **`SHARED/`** — mounted into every guest, for moving files without scp.

A note that saved me repeatedly: `Ubuntu/postclone-change-hostname_and_machine_id.sh`.
Cloned VMs that share a machine-id will fight over DHCP leases and confuse
systemd-journald. Reset it before you wonder why two hosts have the same address.

## Kubernetes

`K8/RH8v1.31/` runs in order, `00` through `06` — prerequisites, containerd,
kubernetes packages, control-plane creation, worker join, Calico CNI, MetalLB,
NGINX ingress. `install-control_plane.sh` and `install-worker_node.sh` wrap the
sequence.

The component choices are deliberate: containerd because that is what kubeadm
expects post-1.24; Calico for network policy, which matters once you are running
someone else's database next to their applications; MetalLB because bare metal
has no cloud load balancer to hand you an external IP; NGINX ingress with TLS
passthrough because Redis Enterprise terminates its own TLS.

## Redis Enterprise on Kubernetes

`K8/RSE/` sits on top of that cluster. Scripts are grouped by object:

- `_REC-*` — cluster: install, uninstall, credentials, ingress, exec into pod, DNS
- `_REDB-*` — databases: add, add custom, list, credentials, ingress
- `_AA-*` — active-active: the secret, the remote-cluster object, the replicated DB
- `_DEL_stuck_namespace.sh` — for when a namespace hangs in `Terminating`
  because a webhook's service is already gone. You will need this eventually.
- `RSE_config-8x.sh` / `RSE_config-18x.sh` — per Redis Enterprise version

## Ai — measuring instead of assuming

`Ai/vllm-benchmarks/` is the one part of this repository that is an experiment
rather than automation. It asks what an NVLink bridge is actually worth on a dual
RTX 3090 pair serving tensor-parallel vLLM, because I had spent a year assuming.

Five arms, every serving flag held identical, adaptive sampling to a 2% confidence
interval. NVLink turns out to be worth **~35-37% on prefill and ~2% on decode** —
most of the apparent decode gain is vLLM's custom all-reduce kernel rather than the
bridge itself. Separating those two needed a fifth arm, because the first
"bridge off" run changed the transport *and* the kernel at once and produced a
clean, tight, confidently wrong answer.

The raw result files are published alongside it, the derived figures were all
recomputed from them, and the whole matrix was later re-run from a clean checkout
on a newer client to check that the runbook and the findings both hold. Two
recorded numbers did not survive that check and are corrected in place.

## Requirements

Vagrant and VirtualBox for the VM environments; a RHEL 8 host or VM for the
Kubernetes scripts; Proxmox for the hypervisor helpers. On Windows, disable
Hyper-V — it interferes with VirtualBox — and use Git Bash or MobaXterm for a
shell.

## State

Actively used, unevenly maintained. The Vagrant and Kubernetes material is the
most exercised; some sections are notes rather than automation. Scripts assume
my address ranges and naming conventions — read the config before running
anything, and expect to change IPs.

## Author

Alexey Tsygankov — SRE / Platform Engineer
[LinkedIn](https://www.linkedin.com/in/alexey-g-tsygankov) | [Portfolio](https://alexey.tsygankov.net)

## License

MIT. See `LICENSE`.
