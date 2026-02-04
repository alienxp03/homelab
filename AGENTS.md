# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Kubernetes homelab setup running on k3s, managing applications through Helm charts and custom manifests. The infrastructure uses Traefik as the ingress controller with automatic SSL certificates via cert-manager and Cloudflare DNS. Prioritize GitOps approach (everything is trackable in Git)

## Architecture

### Directory Structure

- `apps/` - Application deployments (Helm charts or custom manifests)
  - Each app has its own directory with `values.yaml`, `Chart.yaml` (if Helm), and related manifests
  - Some apps are custom Helm charts (nginx, metallb) with `templates/` directories
  - Some apps use external Helm charts (pihole, adguard-home, traefik)
  - Prioritize Helm charts over custom manifests whenever possible
- `stacks/` - Docker Compose stacks (not actively used)
- `stack.env` - Environment variables for Docker stacks (not actively used)

### Networking & Ingress

**Traefik** is the ingress controller:

- Deployed in `traefik` namespace
- Configured with LoadBalancer service via MetalLB
- IngressRoutes are defined using Traefik CRDs (`traefik.io/v1alpha1`)
- All apps use `websecure` entryPoint (port 443)
- Force HTTPS redirection for all apps

**Certificate Management**:

- cert-manager handles SSL certificates
- ClusterIssuer: `cloudflare-clusterissuer` (uses Cloudflare DNS-01 challenge)
- Wildcard certificate: `*.homelab.azuanz.com`
- Certificate secret: `homelab-certificate-secret` (stored in `traefik` namespace)
- Individual apps reference this shared certificate in their IngressRoutes

**Pattern for new services**:

1. Create `certificate.yaml` (optional, if not using wildcard cert). Prioritize wildcard over custom certs.
2. Create `ingress.yaml` with IngressRoute pointing to the service
3. Reference `secretName: homelab-certificate-secret` in the `tls` section
4. Use `entryPoints: [websecure]` for HTTPS-only access

### MetalLB

Provides LoadBalancer IPs for bare-metal k3s cluster. Configuration in `apps/metallb/`.

### DNS Configuration

**CoreDNS Custom Configuration**:

- CoreDNS is configured to forward `*.homelab.azuanz.com` queries to AdGuard Home (192.168.68.151)
- AdGuard Home has DNS rewrites configured to resolve `*.homelab.azuanz.com` to the Traefik LoadBalancer IP (192.168.68.153)
- This ensures all pods in the cluster correctly resolve homelab domains to local services instead of external Cloudflare IPs
- Configuration file: `apps/coredns/coredns-custom.yaml`

**DNS Resolution Flow**:

```
Pod → CoreDNS → AdGuard Home (192.168.68.151) → Local IP (192.168.68.153)
```

**Apply DNS Configuration**:

```bash
make install-coredns-custom  # Apply custom DNS forwarding rules
make status-coredns-custom   # Check CoreDNS configuration status
```

## Common Commands

### Application Management

```bash
# Install/upgrade an application
make install-<app-name>    # e.g., make install-traefik
make install-cert-manager  # cert-manager uses OCI registry

# Check application status
make status-<app-name>     # Shows pods and services

# Uninstall an application
make uninstall-<app-name>

# Available apps: pihole, adguard-home, traefik, metallb, nginx, coredns-custom, gitea
```

### Manual Deployment

```bash
# Apply manifests directly
kubectl apply -f apps/<app>/ingress.yaml
kubectl apply -f apps/<app>/certificate.yaml

# Install custom Helm chart
helm upgrade --install <name> apps/<app>/ --namespace <namespace> --create-namespace

# Install external Helm chart (see Makefile for repo URLs)
helm repo add <repo-name> <repo-url>
helm upgrade --install <name> <repo>/<chart> -f apps/<app>/values.yaml --namespace <namespace> --create-namespace
```

### Debugging

```bash
# Check ingress routes
kubectl get ingressroute -n <namespace>
kubectl describe ingressroute <name> -n <namespace>

# Check certificates
kubectl get certificate -n traefik
kubectl describe certificate <name> -n traefik

# Check certificate secrets
kubectl get secret -n traefik | grep certificate

# Test HTTPS endpoints
curl -vk https://<hostname>.homelab.azuanz.com
```

## Key Configuration Files

- `apps/cert-manager/clusterissuer.yaml` - Cloudflare DNS-01 issuer (requires `cloudflare-api-token-secret`)
- `apps/cert-manager/certificate.yaml` - Wildcard certificate definition
- `apps/traefik/values.yaml` - Traefik configuration (LoadBalancer, entryPoints)
- `apps/traefik/ingress.yaml` - Traefik dashboard IngressRoute
- `apps/coredns/coredns-custom.yaml` - CoreDNS custom DNS forwarding configuration for homelab domains
- `apps/gitea/storage.yaml` - NFS storage configuration (100Gi)
- `apps/gitea/values.yaml` - Gitea Helm chart values (SQLite, Actions enabled)
- `apps/gitea/ingress.yaml` - Traefik IngressRoute for git.homelab.azuanz.com
- `apps/gitea/runner-rbac.yaml` - RBAC for Actions runner
- `apps/gitea/runner-deployment.yaml` - Actions runner with Kubernetes executor

## Important Notes

- All certificates are managed centrally in the `traefik` namespace
- The wildcard certificate `homelab-certificate-secret` should be reused across apps
- Custom Helm charts (nginx, metallb) are stored locally in `apps/` with templates
- External Helm charts require adding repos before installation (see Makefile targets)
