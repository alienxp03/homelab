.PHONY: help

# Default target
help:
	@echo "Usage:"
	@echo "  make install <app-name>   Install a Helm chart"
	@echo "  make status <app-name>    Check status of a deployment"
	@echo "  make uninstall <app-name> Uninstall a Helm chart"
	@echo ""
	@echo "Available apps:"
	@echo "  - pihole"
	@echo "  - adguard-home"
	@echo "  - traefik"
	@echo "  - metallb"
	@echo "  - nginx"
	@echo "  - coredns-custom"
	@echo "  - sealed-secrets"
	@echo "  - cert-manager-secrets (apply sealed secret)"
	@echo "  - qbittorrent"
	@echo "  - sonarr"
	@echo "  - radarr"
	@echo "  - prowlarr"
	@echo "  - flaresolverr"
	@echo "  - bazarr"
	@echo "  - jellyseerr"
	@echo ""
	@echo "Examples:"
	@echo "  make install pihole"
	@echo "  make status pihole"

setup:
	@echo "Setup.."
	@helm repo add bjw-s https://bjw-s-labs.github.io/helm-charts
	@helm repo update
	@echo "Done setup!"

setup-traefik:
	@echo "Installing Traefik..."
	@helm repo add traefik https://traefik.github.io/charts || true
	@helm repo update
	helm upgrade --install traefik traefik/traefik \
		--namespace traefik \
		--create-namespace \
		-f apps/traefik/values.yaml
	@echo "Traefik setup successfully!"

# Install targets
install-pihole:
	@echo "Installing Pi-hole..."
	@helm repo add mojo2600 https://mojo2600.github.io/pihole-kubernetes || true
	@helm repo update
	helm upgrade --install pihole mojo2600/pihole \
		--namespace pihole \
		--create-namespace \
		-f apps/pihole/values.yaml
	@echo "Pi-hole installed successfully!"

install-adguard-home:
	@echo "Installing AdGuard Home..."
	@helm repo add gabe565 https://charts.gabe565.com || true
	@helm repo update
	helm upgrade --install adguard-home gabe565/adguard-home \
		--namespace adguard-home \
		--create-namespace \
		-f apps/adguard-home/values.yaml
	@echo "AdGuard Home installed successfully!"

install-traefik:
	@echo "Installing Traefik..."
	helm upgrade --install traefik traefik/traefik \
		--namespace traefik \
		--create-namespace \
		-f apps/traefik/values.yaml
	@echo "Traefik installed successfully!"

install-metallb:
	@echo "Installing MetalLB..."
	@if [ ! -f apps/metallb/Chart.lock ]; then \
		cd apps/metallb && helm dependency build; \
	fi
	helm upgrade --install metallb apps/metallb \
		--namespace metallb-system \
		--create-namespace
	@echo "MetalLB installed successfully!"

install-nginx:
	@echo "Installing nginx..."
	helm upgrade --install nginx apps/nginx \
		--namespace nginx \
		--create-namespace
	@echo "nginx installed successfully!"

install-cert-manager:
	@echo "Installing cert-manager..."
	helm upgrade --install \
		cert-manager oci://quay.io/jetstack/charts/cert-manager \
		--version v1.18.2 \
		--namespace cert-manager \
		--create-namespace

install-sealed-secrets:
	@echo "Installing sealed-secrets..."
	@if [ ! -f infra/sealed-secrets/Chart.lock ]; then \
		cd infra/sealed-secrets && helm dependency build; \
	fi
	helm upgrade --install sealed-secrets infra/sealed-secrets \
		--namespace kube-system \
		--create-namespace
	@echo "sealed-secrets installed successfully!"

install-cert-manager-secrets:
	@echo "Applying cert-manager sealed secret..."
	kubectl apply -f apps/cert-manager/sealed-secret.yaml
	@echo "Waiting for secret to be unsealed..."
	@sleep 5
	@kubectl get secret cloudflare-api-token-secret -n cert-manager
	@echo "cert-manager secret applied successfully!"

install-coredns-custom:
	@echo "Installing CoreDNS custom configuration..."
	kubectl apply -f apps/coredns/coredns-custom.yaml
	kubectl rollout restart deployment coredns -n kube-system
	@echo "CoreDNS custom configuration applied successfully!"

install-qbittorrent:
	@echo "Installing qBittorrent..."
	helm upgrade --install qbittorrent bjw-s/app-template \
		--namespace media \
		--create-namespace \
		-f apps/qbittorrent/values.yaml
	@echo "qBittorrent installed successfully!"

install-sonarr:
	@echo "Installing Sonarr..."
	helm upgrade --install sonarr bjw-s/app-template \
		--namespace media \
		--create-namespace \
		-f apps/sonarr/values.yaml
	@echo "Sonarr installed successfully!"

install-radarr:
	@echo "Installing Radarr..."
	helm upgrade --install radarr bjw-s/app-template \
		--namespace media \
		--create-namespace \
		-f apps/radarr/values.yaml
	@echo "Radarr installed successfully!"

install-prowlarr:
	@echo "Installing Prowlarr..."
	helm upgrade --install prowlarr bjw-s/app-template \
		--namespace media \
		--create-namespace \
		-f apps/prowlarr/values.yaml
	@echo "Prowlarr installed successfully!"

install-flaresolverr:
	@echo "Installing FlareSolverr..."
	helm upgrade --install flaresolverr bjw-s/app-template \
		--namespace media \
		--create-namespace \
		-f apps/flaresolverr/values.yaml
	@echo "FlareSolverr installed successfully!"

install-bazarr:
	@echo "Installing Bazarr..."
	helm upgrade --install bazarr bjw-s/app-template \
		--namespace media \
		--create-namespace \
		-f apps/bazarr/values.yaml
	@echo "Bazarr installed successfully!"

install-jellyseerr:
	@echo "Installing Jellyseerr..."
	helm upgrade --install jellyseerr bjw-s/app-template \
		--namespace media \
		--create-namespace \
		-f apps/jellyseerr/values.yaml
	@echo "Jellyseerr installed successfully!"

# Status targets
status-pihole:
	@echo "=== Pi-hole Status ==="
	@kubectl -n pihole get pods
	@echo ""
	@kubectl -n pihole get svc

status-adguard-home:
	@echo "=== AdGuard Home Status ==="
	@kubectl -n adguard-home get pods
	@echo ""
	@kubectl -n adguard-home get svc

status-traefik:
	@echo "=== Traefik Status ==="
	@kubectl -n traefik get pods
	@echo ""
	@kubectl -n traefik get svc

status-metallb:
	@echo "=== MetalLB Status ==="
	@kubectl -n metallb-system get pods
	@echo ""
	@kubectl -n metallb-system get svc

status-nginx:
	@echo "=== nginx Status ==="
	@kubectl -n nginx get pods
	@echo ""
	@kubectl -n nginx get svc

status-coredns-custom:
	@echo "=== CoreDNS Custom Configuration Status ==="
	@kubectl -n kube-system get configmap coredns-custom
	@echo ""
	@kubectl -n kube-system get pods -l k8s-app=kube-dns

status-sealed-secrets:
	@echo "=== Sealed Secrets Status ==="
	@kubectl -n kube-system get pods -l app.kubernetes.io/name=sealed-secrets
	@echo ""
	@kubectl -n kube-system get svc sealed-secrets

status-cert-manager-secrets:
	@echo "=== Cert Manager Secrets Status ==="
	@kubectl -n cert-manager get sealedsecret
	@echo ""
	@kubectl -n cert-manager get secret cloudflare-api-token-secret

status-qbittorrent:
	@echo "=== qBittorrent Status ==="
	@kubectl -n media get pods -l app.kubernetes.io/instance=qbittorrent
	@echo ""
	@kubectl -n media get svc -l app.kubernetes.io/instance=qbittorrent

status-sonarr:
	@echo "=== Sonarr Status ==="
	@kubectl -n media get pods -l app.kubernetes.io/instance=sonarr
	@echo ""
	@kubectl -n media get svc -l app.kubernetes.io/instance=sonarr

status-radarr:
	@echo "=== Radarr Status ==="
	@kubectl -n media get pods -l app.kubernetes.io/instance=radarr
	@echo ""
	@kubectl -n media get svc -l app.kubernetes.io/instance=radarr

status-prowlarr:
	@echo "=== Prowlarr Status ==="
	@kubectl -n media get pods -l app.kubernetes.io/instance=prowlarr
	@echo ""
	@kubectl -n media get svc -l app.kubernetes.io/instance=prowlarr

status-flaresolverr:
	@echo "=== FlareSolverr Status ==="
	@kubectl -n media get pods -l app.kubernetes.io/instance=flaresolverr
	@echo ""
	@kubectl -n media get svc -l app.kubernetes.io/instance=flaresolverr

status-bazarr:
	@echo "=== Bazarr Status ==="
	@kubectl -n media get pods -l app.kubernetes.io/instance=bazarr
	@echo ""
	@kubectl -n media get svc -l app.kubernetes.io/instance=bazarr

status-jellyseerr:
	@echo "=== Jellyseerr Status ==="
	@kubectl -n media get pods -l app.kubernetes.io/instance=jellyseerr
	@echo ""
	@kubectl -n media get svc -l app.kubernetes.io/instance=jellyseerr

# Uninstall targets
uninstall-pihole:
	@echo "Uninstalling Pi-hole..."
	helm uninstall pihole --namespace pihole
	@echo "Pi-hole uninstalled successfully!"

uninstall-adguard-home:
	@echo "Uninstalling AdGuard Home..."
	helm uninstall adguard-home --namespace adguard-home
	@echo "AdGuard Home uninstalled successfully!"

uninstall-traefik:
	@echo "Uninstalling Traefik..."
	helm uninstall traefik --namespace traefik
	@echo "Traefik uninstalled successfully!"

uninstall-metallb:
	@echo "Uninstalling MetalLB..."
	helm uninstall metallb --namespace metallb-system
	@echo "MetalLB uninstalled successfully!"

uninstall-nginx:
	@echo "Uninstalling nginx..."
	helm uninstall nginx --namespace nginx
	@echo "nginx uninstalled successfully!"

uninstall-coredns-custom:
	@echo "Uninstalling CoreDNS custom configuration..."
	kubectl delete -f apps/coredns/coredns-custom.yaml
	kubectl rollout restart deployment coredns -n kube-system
	@echo "CoreDNS custom configuration removed successfully!"

uninstall-sealed-secrets:
	@echo "Uninstalling sealed-secrets..."
	helm uninstall sealed-secrets --namespace kube-system
	@echo "sealed-secrets uninstalled successfully!"

uninstall-cert-manager-secrets:
	@echo "Uninstalling cert-manager sealed secret..."
	kubectl delete -f apps/cert-manager/sealed-secret.yaml
	@echo "cert-manager sealed secret removed successfully!"

uninstall-qbittorrent:
	@echo "Uninstalling qBittorrent..."
	helm uninstall qbittorrent --namespace media
	@echo "qBittorrent uninstalled successfully!"

uninstall-sonarr:
	@echo "Uninstalling Sonarr..."
	helm uninstall sonarr --namespace media
	@echo "Sonarr uninstalled successfully!"

uninstall-radarr:
	@echo "Uninstalling Radarr..."
	helm uninstall radarr --namespace media
	@echo "Radarr uninstalled successfully!"

uninstall-prowlarr:
	@echo "Uninstalling Prowlarr..."
	helm uninstall prowlarr --namespace media
	@echo "Prowlarr uninstalled successfully!"

uninstall-flaresolverr:
	@echo "Uninstalling FlareSolverr..."
	helm uninstall flaresolverr --namespace media
	@echo "FlareSolverr uninstalled successfully!"

uninstall-bazarr:
	@echo "Uninstalling Bazarr..."
	helm uninstall bazarr --namespace media
	@echo "Bazarr uninstalled successfully!"

uninstall-jellyseerr:
	@echo "Uninstalling Jellyseerr..."
	helm uninstall jellyseerr --namespace media
	@echo "Jellyseerr uninstalled successfully!"
