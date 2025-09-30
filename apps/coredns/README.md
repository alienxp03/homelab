# CoreDNS Custom Configuration

This directory contains custom DNS configuration for CoreDNS in k3s to forward homelab domain queries to AdGuard Home.

## Overview

By default, CoreDNS forwards all external DNS queries to upstream resolvers (like Google DNS 8.8.8.8). This causes `*.homelab.azuanz.com` domains to resolve to Cloudflare IPs instead of local services.

This custom configuration forwards `*.homelab.azuanz.com` queries to AdGuard Home, which has DNS rewrites configured to return local IPs.

## Architecture

```
Pod → CoreDNS → AdGuard Home (192.168.68.151) → Local IP (192.168.68.153)
```

## Files

- `coredns-custom.yaml` - ConfigMap that adds custom DNS forwarding rules

## Apply

```bash
kubectl apply -f apps/coredns/coredns-custom.yaml
```

CoreDNS will automatically reload the configuration from the `coredns-custom` ConfigMap within 30 seconds (or restart the deployment to apply immediately):

```bash
kubectl rollout restart deployment coredns -n kube-system
```

## How It Works

k3s CoreDNS is configured to import custom configurations from ConfigMaps with specific naming patterns:
- `*.server` files add new DNS server blocks
- `*.override` files modify the main server block

The `homelab.server` key creates a dedicated DNS server block for `homelab.azuanz.com` that forwards to AdGuard Home.

## Verify

Test DNS resolution from any pod:

```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup traefik.homelab.azuanz.com
```

Expected result: `192.168.68.153`

## AdGuard DNS Rewrite

Ensure AdGuard Home has the following DNS rewrite configured:
- Domain: `*.homelab.azuanz.com`
- Answer: `192.168.68.153`

This can be verified at: https://adguard-home.homelab.azuanz.com/#dns_rewrites

## Troubleshooting

If domains still resolve to Cloudflare IPs:

1. Check if CoreDNS picked up the custom config:
   ```bash
   kubectl get configmap coredns-custom -n kube-system
   ```

2. Check CoreDNS logs:
   ```bash
   kubectl logs -n kube-system -l k8s-app=kube-dns
   ```

3. Restart CoreDNS:
   ```bash
   kubectl rollout restart deployment coredns -n kube-system
   ```

4. Check pod DNS resolution:
   ```bash
   kubectl exec -n <namespace> <pod> -- cat /etc/resolv.conf
   kubectl exec -n <namespace> <pod> -- nslookup traefik.homelab.azuanz.com
   ```