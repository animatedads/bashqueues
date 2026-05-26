# VM and Container Assets

bashqueues includes first-class asset plugins for common container, VM, and orchestration platforms. These checks are worker preflight checks only; they are not sentinel-safe and should not run from the cheap control-plane loop.

## Asset families

| Family | File | Purpose |
|---|---|---|
| `docker:*` | `assets.d/docker.sh` | Docker Engine / Podman container, image, volume, network, registry, and privileged-container gates. |
| `k8s:*` | `assets.d/k8s.sh` | Kubernetes API, deployment, pod, job, node, PVC, namespace, quota, ConfigMap, and Secret existence gates. |
| `vm:*` | `assets.d/vm.sh` | libvirt/KVM domain, snapshot, storage pool, network, vCPU, and disk image gates. |
| `lxc:*` | `assets.d/lxc.sh` | LXC/LXD container, image, profile, and storage pool gates. |
| `vsphere:*` | `assets.d/vsphere.sh` | VMware vSphere / ESXi gates via `govc`. |
| `vagrant:*` | `assets.d/vagrant.sh` | Vagrant machine and box state gates. |

## Safety rules

- `queue assets list` and `queue assets list --json` are metadata-only. They source only asset plugins and call `queue_asset_facilities` / `queue_asset_hints`; they must not execute live probes.
- No check calls `exit`; every check returns normally with `asset_check_ok:` or `asset_check_blocked:`.
- Every external tool check supports a bounded `timeout=` parameter unless it is a simple local file check.
- Secret-bearing parameters such as `govc_password=` are not printed in block messages.
- `k8s:secret_exists` checks only object existence. It does not read, decode, or print secret values.

## Examples

```bash
# Docker / Podman
queue_class_shared_asset docker image_exists "python:3.12-slim"
queue_class_shared_asset docker image_age "python:3.12-slim" max_days=14
queue_class_shared_asset docker healthy "myapp-api"
queue_class_shared_asset docker no_privileged system

# Kubernetes
queue_class_shared_asset k8s reachable system
queue_class_shared_asset k8s node_ready system min_count=3
queue_class_shared_asset k8s deployment_ready "api-server" namespace=production min_ready=2
queue_class_shared_asset k8s no_crashlooping "app=payment-service" namespace=production

# libvirt / KVM
queue_class_shared_asset vm running "prod-db-01"
queue_class_shared_asset vm snapshot_exists "staging-01" snapshot=pre-migration
queue_class_shared_asset vm pool_active "default"

# LXC / LXD
queue_class_shared_asset lxc image_exists "ubuntu/22.04/amd64"
queue_class_shared_asset lxc not_running "build-worker-01"
queue_class_shared_asset lxc storage_pool_ok "local"

# vSphere / govc
queue_class_shared_asset vsphere host_connected "esxi-01.example.com"
queue_class_shared_asset vsphere datastore_free "VSANSTORE01" min_gb=100
queue_class_shared_asset vsphere vm_not_running "/dc01/vm/prod/db-primary"

# Vagrant
queue_class_shared_asset vagrant running "default" cwd=/opt/vms/integration
queue_class_shared_asset vagrant box_outdated "ubuntu/jammy64"
```
