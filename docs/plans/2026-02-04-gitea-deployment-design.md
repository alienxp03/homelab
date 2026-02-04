# Gitea Deployment Design

**Date**: 2026-02-04
**Status**: Approved
**Author**: Stan & Claude

## Overview

Deploy Gitea (self-hosted Git service) with Actions CI/CD support on k3s homelab cluster using Synology NFS storage and SQLite database.

## Architecture

### Components

1. **Gitea Application**
   - Image: `gitea/gitea:latest` (or pinned version)
   - Database: SQLite (single-file, simple for homelab)
   - Storage: Single NFS volume for all data
   - Resources: 500m CPU, 512Mi memory (adjustable)
   - Replicas: 1 (SQLite limits horizontal scaling)

2. **Gitea Actions Runner**
   - Image: `gitea/act_runner:latest`
   - Execution mode: Kubernetes executor (spawns Jobs for CI tasks)
   - RBAC: ServiceAccount with permissions to create Jobs/Pods
   - Replicas: 1-2 (can scale to 0 when idle)
   - Labels: `ubuntu-latest`, `self-hosted`, `linux`, `k8s`

3. **Namespace**: `gitea`

## Storage Configuration

### NFS Persistent Volume

**Synology NAS Path**: `/volume1/family/apps/gitea/data` (already created)

**Storage Structure**:
```
/volume1/family/apps/gitea/data/
├── gitea.db              # SQLite database
├── git/repositories/     # Git repositories
├── attachments/          # Issue/PR attachments
├── avatars/              # User avatars
├── lfs/                  # Git LFS objects
├── actions_artifacts/    # CI build artifacts
├── actions_log/          # CI job logs
└── actions_cache/        # CI cache (dependencies, etc.)
```

**PV Specification**:
- Capacity: 100Gi
- Access Mode: ReadWriteOnce
- NFS Server: 192.168.68.60
- Mount Options: `nfsvers=4.1`, `rsize=1048576`, `wsize=1048576`
- Reclaim Policy: Retain

**PVC**: Binds to PV, mounts to `/data` in Gitea pod.

**Rationale**: Single volume simplifies backup and management. SQLite keeps all metadata in one file. Actions artifacts/cache stored locally. Data persists across pod restarts.

## Networking & Ingress

### HTTP/HTTPS Access

- **Service**: `gitea-http` (ClusterIP on port 3000)
- **IngressRoute**: `git.homelab.azuanz.com`
- **TLS**: Reuses `homelab-certificate-secret` from `traefik` namespace
- **Entrypoint**: `websecure` (port 443, force HTTPS)
- **Access**: Web UI, Git over HTTPS, API

### SSH Access

- **Service**: `gitea-ssh` (LoadBalancer on port 22)
- **LoadBalancer IP**: Assigned by MetalLB (e.g., 192.168.68.154)
- **Usage**: Git over SSH (recommended for Git operations)
- **Clone URL**: `git clone git@192.168.68.154:user/repo.git`
- **Optional**: Configure DNS A record `git.homelab.azuanz.com` → LoadBalancer IP

### Internal Communication

- Actions runners connect to Gitea via internal ClusterIP service
- No external exposure needed for runner communication

## Gitea Configuration

### Application Settings (via Helm values)

- **Database**: SQLite at `/data/gitea.db`
- **Repository root**: `/data/git/repositories`
- **Actions enabled**: `ACTIONS_ENABLED=true`
- **Actions retention**: 90 days for artifacts/logs (configurable)
- **SSH domain**: LoadBalancer IP or `git.homelab.azuanz.com`
- **Security**: Optionally disable public registration, require sign-in to view

### Actions Runner Configuration

1. **Registration**:
   - Generate runner token from Gitea UI: Site Administration → Actions → Runners
   - Store as Kubernetes Secret: `gitea-runner-token`

2. **Runner Labels**:
   - `ubuntu-latest:docker://node:16-bullseye` (example)
   - `self-hosted`, `linux`, `k8s`

3. **RBAC**:
   - ServiceAccount: `gitea-runner`
   - Role: Create/delete Jobs, Pods, ConfigMaps, Secrets in `gitea` namespace
   - RoleBinding: Bind role to ServiceAccount

4. **Scaling**: Start with 1 replica, manually scale to 0 when not needed

## File Structure

```
apps/gitea/
├── storage.yaml           # NFS PV/PVC (100Gi)
├── values.yaml            # Helm values for Gitea chart
├── ingress.yaml           # IngressRoute for git.homelab.azuanz.com
├── runner-rbac.yaml       # ServiceAccount, Role, RoleBinding
├── runner-secret.yaml     # Placeholder for runner token (fill after deployment)
└── runner-values.yaml     # Helm values for act_runner chart
```

## Deployment Sequence

1. **Apply storage**: `kubectl apply -f apps/gitea/storage.yaml`
2. **Install Gitea**: `helm install gitea gitea-charts/gitea -f apps/gitea/values.yaml`
3. **Apply IngressRoute**: `kubectl apply -f apps/gitea/ingress.yaml`
4. **Access UI**: Navigate to `https://git.homelab.azuanz.com`
5. **Create admin account**: First-time setup wizard
6. **Generate runner token**: Site Administration → Actions → Runners → Create token
7. **Create runner secret**: `kubectl create secret generic gitea-runner-token --from-literal=token=<TOKEN>`
8. **Apply runner RBAC**: `kubectl apply -f apps/gitea/runner-rbac.yaml`
9. **Install runner**: `helm install gitea-runner gitea-charts/gitea-runner -f apps/gitea/runner-values.yaml`

## Makefile Targets

- `install-gitea`: Deploy Gitea with storage and ingress
- `install-gitea-runner`: Deploy Actions runner (run after token setup)
- `status-gitea`: Check pods, services, ingress
- `uninstall-gitea`: Remove Gitea deployment
- `uninstall-gitea-runner`: Remove Actions runner

## Helm Repositories

- Gitea: `https://dl.gitea.com/charts/`
- Act Runner: May use manual manifest if no official chart available

## Considerations

### Advantages

- **Simple**: SQLite, single volume, no external database
- **Persistent**: All data on NFS survives pod restarts
- **Secure**: Kubernetes executor avoids privileged containers
- **Scalable**: Can handle multiple repos and users for homelab usage
- **CI/CD native**: Actions runners integrated, idle-friendly

### Limitations

- **SQLite**: Not suitable for high-concurrency (fine for homelab)
- **Single replica**: Cannot horizontally scale Gitea with SQLite
- **NFS dependency**: Performance depends on network and NAS

### Future Enhancements

- **PostgreSQL**: Migrate if concurrency becomes an issue
- **Runner auto-scaling**: HPA based on job queue length
- **Backup automation**: Scheduled backups of `/volume1/family/apps/gitea/data`
- **LFS**: Enable if storing large binary files in repos
- **Webhooks**: Integrate with external services (Discord, Slack, etc.)

## Success Criteria

- ✅ Gitea accessible at `https://git.homelab.azuanz.com`
- ✅ SSH clone working via LoadBalancer IP
- ✅ Data persists across pod restarts
- ✅ Actions runner registers successfully
- ✅ CI workflow executes and creates artifacts
- ✅ All data stored on Synology NFS
