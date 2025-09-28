# Defaults for this first service
RELEASE ?= nginx
CHART ?= ./nginx
VALUES ?= ./nginx/values.yaml
KCTX ?= rancher-desktop

# parse namespace from chart values; set NAMESPACE=nginx if you don't have yq
NAMESPACE ?= $(shell yq '.namespace' $(CHART)/values.yaml 2>/dev/null || echo nginx)

lint:
	helm lint $(CHART)

template:
	helm template $(RELEASE) $(CHART) -f $(CHART)/values.yaml -f $(VALUES) --namespace $(NAMESPACE)

install:
	helm upgrade --install $(RELEASE) $(CHART) \
	  -f $(CHART)/values.yaml -f $(VALUES) \
	  --namespace $(NAMESPACE) \
	  --create-namespace

status:
	helm status $(RELEASE) --namespace $(NAMESPACE)

uninstall:
	helm uninstall $(RELEASE) --namespace $(NAMESPACE)

port:
	kubectl -n $(NAMESPACE) port-forward svc/$(RELEASE) 8080:80

