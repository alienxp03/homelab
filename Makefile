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
	@echo ""
	@echo "Examples:"
	@echo "  make install pihole"
	@echo "  make status pihole"

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

install-coredns-custom:
	@echo "Installing CoreDNS custom configuration..."
	kubectl apply -f apps/coredns/coredns-custom.yaml
	kubectl rollout restart deployment coredns -n kube-system
	@echo "CoreDNS custom configuration applied successfully!"

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
