# Gitea Deployment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy Gitea with Actions CI/CD on k3s homelab using Synology NFS storage and SQLite database.

**Architecture:** Single NFS volume (100Gi) stores SQLite database, Git repositories, and CI artifacts. Gitea accessible via HTTPS (Traefik) and SSH (LoadBalancer). Actions runners use Kubernetes executor to spawn Jobs for CI tasks.

**Tech Stack:** Gitea, Helm, Traefik IngressRoute, NFS, MetalLB, Kubernetes RBAC

---

## Task 1: Create NFS Storage Configuration

**Files:**
- Create: `apps/gitea/storage.yaml`

**Step 1: Create storage manifest**

Create `apps/gitea/storage.yaml`:

```yaml
# NFS Persistent Volume for Gitea
# Uses Synology NAS at 192.168.68.60
# Folder: /volume1/family/apps/gitea/data
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-gitea-data
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  mountOptions:
    - nfsvers=4.1
    - rsize=1048576
    - wsize=1048576
  nfs:
    server: 192.168.68.60
    path: /volume1/family/apps/gitea/data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gitea-data
  namespace: gitea
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ""
  resources:
    requests:
      storage: 100Gi
  volumeName: pv-gitea-data
```

**Step 2: Verify syntax**

Run: `cat apps/gitea/storage.yaml`
Expected: Valid YAML with no syntax errors

**Step 3: Commit**

```bash
git add apps/gitea/storage.yaml
git commit -m "feat(gitea): add NFS storage configuration (100Gi)"
```

---

## Task 2: Create Gitea Helm Values

**Files:**
- Create: `apps/gitea/values.yaml`

**Step 1: Create Helm values file**

Create `apps/gitea/values.yaml`:

```yaml
# Gitea Helm Chart Values
# Official chart: https://gitea.com/gitea/helm-chart

replicaCount: 1

image:
  repository: gitea/gitea
  tag: "1.22.3"
  pullPolicy: IfNotPresent

service:
  http:
    type: ClusterIP
    port: 3000
  ssh:
    type: LoadBalancer
    port: 22
    loadBalancerIP: ""  # MetalLB will assign

ingress:
  enabled: false  # Using Traefik IngressRoute instead

persistence:
  enabled: true
  existingClaim: gitea-data
  size: 100Gi

gitea:
  admin:
    username: gitea_admin
    password: ""  # Set on first login
    email: admin@homelab.azuanz.com

  config:
    database:
      DB_TYPE: sqlite3
      PATH: /data/gitea.db

    repository:
      ROOT: /data/git/repositories

    server:
      DOMAIN: git.homelab.azuanz.com
      SSH_DOMAIN: git.homelab.azuanz.com
      ROOT_URL: https://git.homelab.azuanz.com/
      HTTP_PORT: 3000
      SSH_PORT: 22
      DISABLE_SSH: false
      START_SSH_SERVER: true
      LFS_START_SERVER: true

    actions:
      ENABLED: true
      DEFAULT_ACTIONS_URL: https://github.com

    security:
      INSTALL_LOCK: false  # Allow initial setup
      SECRET_KEY: ""  # Will be generated

    service:
      DISABLE_REGISTRATION: true
      REQUIRE_SIGNIN_VIEW: false

    log:
      LEVEL: Info

resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: "2"
    memory: 2Gi

podSecurityContext:
  fsGroup: 1000

securityContext:
  runAsUser: 1000
  runAsNonRoot: true
```

**Step 2: Verify syntax**

Run: `cat apps/gitea/values.yaml`
Expected: Valid YAML with no syntax errors

**Step 3: Commit**

```bash
git add apps/gitea/values.yaml
git commit -m "feat(gitea): add Helm chart values with SQLite and Actions"
```

---

## Task 3: Create Traefik IngressRoute

**Files:**
- Create: `apps/gitea/ingress.yaml`

**Step 1: Create IngressRoute manifest**

Create `apps/gitea/ingress.yaml`:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: gitea-ingressroute
  namespace: gitea
  annotations:
    meta.helm.sh/release-name: gitea
    meta.helm.sh/release-namespace: gitea
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`git.homelab.azuanz.com`)
      kind: Rule
      services:
        - name: gitea-http
          port: 3000
  tls:
    secretName: homelab-certificate-secret
```

**Step 2: Verify syntax**

Run: `cat apps/gitea/ingress.yaml`
Expected: Valid YAML with no syntax errors

**Step 3: Commit**

```bash
git add apps/gitea/ingress.yaml
git commit -m "feat(gitea): add Traefik IngressRoute for git.homelab.azuanz.com"
```

---

## Task 4: Create Actions Runner RBAC

**Files:**
- Create: `apps/gitea/runner-rbac.yaml`

**Step 1: Create RBAC manifest**

Create `apps/gitea/runner-rbac.yaml`:

```yaml
# RBAC for Gitea Actions Runner
# Allows runner to create Jobs and Pods for CI execution
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitea-runner
  namespace: gitea
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: gitea-runner
  namespace: gitea
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "pods/exec"]
    verbs: ["get", "list", "watch", "create", "delete", "update", "patch"]
  - apiGroups: [""]
    resources: ["secrets", "configmaps"]
    verbs: ["get", "list", "create", "delete"]
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["get", "list", "watch", "create", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: gitea-runner
  namespace: gitea
subjects:
  - kind: ServiceAccount
    name: gitea-runner
    namespace: gitea
roleRef:
  kind: Role
  name: gitea-runner
  apiGroup: rbac.authorization.k8s.io
```

**Step 2: Verify syntax**

Run: `cat apps/gitea/runner-rbac.yaml`
Expected: Valid YAML with no syntax errors

**Step 3: Commit**

```bash
git add apps/gitea/runner-rbac.yaml
git commit -m "feat(gitea): add RBAC for Actions runner with Kubernetes executor"
```

---

## Task 5: Create Runner Secret Placeholder

**Files:**
- Create: `apps/gitea/runner-secret.yaml`

**Step 1: Create secret placeholder**

Create `apps/gitea/runner-secret.yaml`:

```yaml
# Gitea Actions Runner Token Secret
#
# MANUAL STEP REQUIRED:
# 1. Deploy Gitea first
# 2. Access https://git.homelab.azuanz.com
# 3. Log in as admin
# 4. Navigate to: Site Administration → Actions → Runners
# 5. Click "Create new Runner" and copy the registration token
# 6. Replace <PASTE_TOKEN_HERE> below with the actual token
# 7. Apply this manifest: kubectl apply -f apps/gitea/runner-secret.yaml
#
---
apiVersion: v1
kind: Secret
metadata:
  name: gitea-runner-token
  namespace: gitea
type: Opaque
stringData:
  token: "<PASTE_TOKEN_HERE>"
```

**Step 2: Verify syntax**

Run: `cat apps/gitea/runner-secret.yaml`
Expected: Valid YAML with placeholder token

**Step 3: Commit**

```bash
git add apps/gitea/runner-secret.yaml
git commit -m "feat(gitea): add runner token secret placeholder"
```

---

## Task 6: Create Actions Runner Deployment

**Files:**
- Create: `apps/gitea/runner-deployment.yaml`

**Step 1: Create runner deployment manifest**

Create `apps/gitea/runner-deployment.yaml`:

```yaml
# Gitea Actions Runner Deployment
# Uses Kubernetes executor to spawn Jobs for CI tasks
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitea-runner
  namespace: gitea
  labels:
    app: gitea-runner
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gitea-runner
  template:
    metadata:
      labels:
        app: gitea-runner
    spec:
      serviceAccountName: gitea-runner
      containers:
        - name: runner
          image: gitea/act_runner:latest
          imagePullPolicy: Always
          env:
            - name: GITEA_INSTANCE_URL
              value: "http://gitea-http:3000"
            - name: GITEA_RUNNER_REGISTRATION_TOKEN
              valueFrom:
                secretKeyRef:
                  name: gitea-runner-token
                  key: token
            - name: GITEA_RUNNER_NAME
              value: "k8s-runner-1"
            - name: GITEA_RUNNER_LABELS
              value: "ubuntu-latest:docker://node:20-bullseye,self-hosted,linux,k8s"
          command:
            - /bin/sh
            - -c
            - |
              # Configure runner to use Kubernetes executor
              cat > /data/config.yaml <<EOF
              log:
                level: info
              runner:
                name: k8s-runner-1
                capacity: 10
                timeout: 3h
                labels:
                  - "ubuntu-latest:docker://node:20-bullseye"
                  - "self-hosted"
                  - "linux"
                  - "k8s"
              EOF

              # Register and start runner
              act_runner register --no-interactive \
                --instance "$GITEA_INSTANCE_URL" \
                --token "$GITEA_RUNNER_REGISTRATION_TOKEN" \
                --name "$GITEA_RUNNER_NAME" \
                --labels "$GITEA_RUNNER_LABELS"

              act_runner daemon
          volumeMounts:
            - name: runner-data
              mountPath: /data
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: "1"
              memory: 512Mi
      volumes:
        - name: runner-data
          emptyDir: {}
```

**Step 2: Verify syntax**

Run: `cat apps/gitea/runner-deployment.yaml`
Expected: Valid YAML with no syntax errors

**Step 3: Commit**

```bash
git add apps/gitea/runner-deployment.yaml
git commit -m "feat(gitea): add Actions runner deployment with k8s executor"
```

---

## Task 7: Add Makefile Targets

**Files:**
- Modify: `Makefile`

**Step 1: Add Gitea to help section**

Find the help section (around line 30) and add `gitea` to the list:

```makefile
	@echo "  - gitea"
```

**Step 2: Add install-gitea target**

Add at the end of the install targets section (after `install-redis`):

```makefile
install-gitea:
	@echo "Installing Gitea..."
	@helm repo add gitea-charts https://dl.gitea.com/charts/ || true
	@helm repo update
	@echo "Creating gitea namespace..."
	@kubectl create namespace gitea --dry-run=client -o yaml | kubectl apply -f -
	@echo "Applying Gitea storage..."
	@kubectl apply -f apps/gitea/storage.yaml
	@echo "Installing Gitea chart..."
	helm upgrade --install gitea gitea-charts/gitea \
		--namespace gitea \
		--create-namespace \
		-f apps/gitea/values.yaml
	@echo "Waiting for Gitea to be ready..."
	@kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=gitea -n gitea --timeout=300s
	@echo "Applying Gitea IngressRoute..."
	@kubectl apply -f apps/gitea/ingress.yaml
	@echo ""
	@echo "Gitea installed successfully!"
	@echo ""
	@echo "Access Gitea at: https://git.homelab.azuanz.com"
	@echo ""
	@echo "Next steps:"
	@echo "1. Complete initial setup and create admin account"
	@echo "2. Generate runner token: Site Administration → Actions → Runners"
	@echo "3. Update apps/gitea/runner-secret.yaml with the token"
	@echo "4. Run: make install-gitea-runner"
```

**Step 3: Add install-gitea-runner target**

Add after `install-gitea`:

```makefile
install-gitea-runner:
	@echo "Installing Gitea Actions Runner..."
	@echo "Applying runner RBAC..."
	@kubectl apply -f apps/gitea/runner-rbac.yaml
	@echo "Applying runner secret..."
	@kubectl apply -f apps/gitea/runner-secret.yaml
	@echo "Deploying runner..."
	@kubectl apply -f apps/gitea/runner-deployment.yaml
	@echo "Gitea Actions Runner installed successfully!"
	@echo ""
	@echo "Check runner status with: make status-gitea-runner"
```

**Step 4: Add status-gitea target**

Add in the status targets section (after `status-redis`):

```makefile
status-gitea:
	@echo "=== Gitea Status ==="
	@kubectl -n gitea get pods
	@echo ""
	@kubectl -n gitea get svc
	@echo ""
	@kubectl -n gitea get ingressroute
	@echo ""
	@echo "SSH LoadBalancer IP:"
	@kubectl -n gitea get svc gitea-ssh -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
	@echo ""
```

**Step 5: Add status-gitea-runner target**

Add after `status-gitea`:

```makefile
status-gitea-runner:
	@echo "=== Gitea Actions Runner Status ==="
	@kubectl -n gitea get pods -l app=gitea-runner
	@echo ""
	@kubectl -n gitea logs -l app=gitea-runner --tail=50
```

**Step 6: Add uninstall-gitea target**

Add in the uninstall targets section (after `uninstall-redis`):

```makefile
uninstall-gitea:
	@echo "Uninstalling Gitea..."
	@kubectl delete -f apps/gitea/ingress.yaml || true
	helm uninstall gitea --namespace gitea
	@echo "Gitea uninstalled successfully!"
	@echo ""
	@echo "Note: PersistentVolume and data retained. To remove:"
	@echo "  kubectl delete -f apps/gitea/storage.yaml"
```

**Step 7: Add uninstall-gitea-runner target**

Add after `uninstall-gitea`:

```makefile
uninstall-gitea-runner:
	@echo "Uninstalling Gitea Actions Runner..."
	@kubectl delete -f apps/gitea/runner-deployment.yaml || true
	@kubectl delete -f apps/gitea/runner-secret.yaml || true
	@kubectl delete -f apps/gitea/runner-rbac.yaml || true
	@echo "Gitea Actions Runner uninstalled successfully!"
```

**Step 8: Commit**

```bash
git add Makefile
git commit -m "feat(gitea): add Makefile targets for deployment and management"
```

---

## Task 8: Update Documentation

**Files:**
- Modify: `AGENTS.md`

**Step 1: Add Gitea to Available apps section**

Find the line with "Available apps:" (around line 85) and add:

```markdown
# Available apps: pihole, adguard-home, traefik, metallb, nginx, coredns-custom, gitea
```

**Step 2: Add Gitea configuration section**

Add after the "Key Configuration Files" section (around line 115):

```markdown
- `apps/gitea/storage.yaml` - NFS storage configuration (100Gi)
- `apps/gitea/values.yaml` - Gitea Helm chart values (SQLite, Actions enabled)
- `apps/gitea/ingress.yaml` - Traefik IngressRoute for git.homelab.azuanz.com
- `apps/gitea/runner-rbac.yaml` - RBAC for Actions runner
- `apps/gitea/runner-deployment.yaml` - Actions runner with Kubernetes executor
```

**Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "docs: add Gitea configuration to AGENTS.md"
```

---

## Deployment Steps (Manual)

After all files are committed, follow these steps:

### Phase 1: Deploy Gitea

```bash
# Install Gitea
make install-gitea

# Check status
make status-gitea

# Get SSH LoadBalancer IP
kubectl -n gitea get svc gitea-ssh
```

Expected output: Gitea pod running, IngressRoute created, SSH service has LoadBalancer IP

### Phase 2: Initial Setup

1. Navigate to: `https://git.homelab.azuanz.com`
2. Complete initial setup wizard (should auto-configure based on values.yaml)
3. Create admin account
4. Log in as admin

### Phase 3: Generate Runner Token

1. Go to: Site Administration → Actions → Runners
2. Click "Create new Runner"
3. Copy the registration token

### Phase 4: Deploy Actions Runner

1. Edit `apps/gitea/runner-secret.yaml`
2. Replace `<PASTE_TOKEN_HERE>` with actual token
3. Run:

```bash
make install-gitea-runner
make status-gitea-runner
```

Expected output: Runner pod running, logs show successful registration

### Phase 5: Verify

1. Check runner appears in Gitea UI: Site Administration → Actions → Runners
2. Create test repository with simple workflow:

```yaml
# .gitea/workflows/test.yaml
name: Test Workflow
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "Hello from Gitea Actions!"
```

3. Push to repository, verify workflow executes
4. Check artifacts stored in NFS: `/volume1/family/apps/gitea/data/actions_artifacts/`

---

## Success Criteria

- ✅ Gitea accessible at `https://git.homelab.azuanz.com`
- ✅ SSH clone working via LoadBalancer IP
- ✅ Admin account created and functional
- ✅ Actions runner registered and visible in UI
- ✅ Test workflow executes successfully
- ✅ Workflow logs appear in UI
- ✅ All data persists in NFS storage
- ✅ Pod restart doesn't lose data

---

## Troubleshooting

### Issue: PVC stuck in Pending

**Check:**
```bash
kubectl describe pvc gitea-data -n gitea
```

**Fix:** Ensure NFS path exists on Synology and PV is created before PVC

### Issue: Ingress not accessible

**Check:**
```bash
kubectl describe ingressroute gitea-ingressroute -n gitea
kubectl get secret -n traefik | grep homelab-certificate
```

**Fix:** Ensure certificate secret exists in traefik namespace

### Issue: Runner fails to register

**Check:**
```bash
kubectl logs -n gitea -l app=gitea-runner
```

**Fix:**
- Verify token is correct in runner-secret.yaml
- Ensure Gitea service is reachable: `kubectl exec -n gitea <gitea-pod> -- wget -O- http://gitea-http:3000`
- Check RBAC permissions applied

### Issue: Workflow fails to start

**Check:**
```bash
kubectl get jobs -n gitea
kubectl logs -n gitea -l app=gitea-runner
```

**Fix:**
- Verify runner has RBAC permissions to create Jobs
- Check runner labels match workflow `runs-on` value

---

## Notes

- SQLite limits Gitea to single replica - do not scale
- Runner can be scaled to 0 when not in use: `kubectl scale deployment gitea-runner -n gitea --replicas=0`
- Backup strategy: Snapshot `/volume1/family/apps/gitea/data/` on Synology
- To migrate to PostgreSQL later: Export repos, switch DB config, reimport
