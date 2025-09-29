# Pi-hole Helm Deployment

Minimal values for deploying Pi-hole with the public `mojo2600/pihole` Helm chart. The release expects MetalLB to hand out `192.168.68.153` from the `lan-pool` address pool and allows the DNS and HTTP services to share that IP.

Run the commands below from the repository root or `cd apps/pihole` first so Helm picks up `values.yaml`.

## Prerequisites
- Helm repository added: `helm repo add mojo2600 https://mojo2600.github.io/pihole-kubernetes`
- MetalLB address pool named `lan-pool` and shared-IP support enabled for `pihole-shared`.

## Install

```sh
helm upgrade --install pihole mojo2600/pihole \
  --namespace pihole \
  --create-namespace \
  -f apps/pihole/values.yaml
```

## Verify

```sh
kubectl -n pihole get pods
kubectl -n pihole get svc
```

You should see the Pi-hole pod running and both DNS and web services bound to `192.168.68.153`.

## Uninstall

```sh
helm uninstall pihole --namespace pihole
```
