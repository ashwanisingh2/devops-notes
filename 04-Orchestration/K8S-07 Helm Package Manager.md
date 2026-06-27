---
tags:
  - devops
  - kubernetes
  - helm
aliases:
  - Helm
created: 2025-06-27
status: "#complete"
difficulty: "#intermediate"
cert-relevant: "#cka"
---

# Helm — The Kubernetes Package Manager

> [!abstract] Overview
> Managing Kubernetes applications with raw YAML files quickly becomes unmanageable at scale. Helm solves this by providing a **package manager** for Kubernetes — think of it as `apt` or `yum` for your cluster. Helm packages related Kubernetes manifests into reusable **charts**, supports versioned **releases** with instant **rollback**, and allows environment-specific customization through templated values. Whether you're deploying a simple Nginx or a complex Prometheus monitoring stack, Helm is the industry-standard tool that every DevOps engineer must master.
>
> *Helm को ऐसे समझो जैसे Zomato पर ready-made meal order करना — तुम्हें खुद सब ingredients (YAML files) नहीं जोड़ने पड़ते, बस order दो (helm install) और पूरा setup तैयार हो जाता है। अगर खाना पसंद नहीं आया तो return (rollback) भी कर सकते हो!*

---

## Concept Overview

### The Kubernetes YAML Management Problem

Consider deploying a typical web application. You need:
- Deployment YAML
- Service YAML
- ConfigMap YAML
- Secret YAML
- Ingress YAML
- HPA YAML
- ServiceAccount YAML
- NetworkPolicy YAML

That's 8+ YAML files for **one** application. Now multiply by 3 environments (dev, staging, prod) with slightly different values (replicas, image tags, resource limits). You end up maintaining 24+ YAML files with copy-paste differences — a maintenance nightmare prone to drift and human error.

**Helm eliminates this problem** by:
1. **Templatizing** YAML manifests with Go template syntax
2. **Parameterizing** environment-specific values in `values.yaml`
3. **Packaging** everything into a single versioned chart
4. **Tracking** deployed releases with history and rollback capability

*बिना Helm के Kubernetes manage करना ऐसा है जैसे हर बार खाना बनाने के लिए recipe फिर से लिखना। Helm एक cookbook है — एक बार recipe (chart) बना लो, फिर हर बार बस ingredients (values) बदलो और deploy करो।*

---

### Helm Architecture

Helm 3 (current version) is a **client-only** architecture. The controversial server-side component **Tiller** was removed in Helm 3 for security reasons.

```
┌──────────────────────────────────────────────────┐
│                  HELM CLIENT (CLI)                │
│  helm install / upgrade / rollback / uninstall    │
└──────────────────┬───────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────┐
│             KUBERNETES API SERVER                 │
│  Helm communicates directly via kubeconfig        │
└──────────────────┬───────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────┐
│              RELEASE SECRETS                      │
│  Release metadata stored as K8s Secrets           │
│  (namespace: default storage driver)              │
└──────────────────────────────────────────────────┘
```

**Core Concepts:**

| Concept | Description | Analogy (Hindi) |
|---|---|---|
| **Chart** | A package containing templated K8s manifests | *Recipe (पकाने की विधि)* |
| **Release** | A running instance of a chart in a cluster | *Cooked dish (बना हुआ खाना)* |
| **Repository** | A server hosting charts (like Docker Hub for images) | *Cookbook library (रेसिपी की दुकान)* |
| **Revision** | A version of a release (each upgrade creates a new revision) | *Dish version — "इस बार ज़्यादा नमक डाला"* |

*Chart एक blueprint है, Release उस blueprint से बनी हुई चीज़ है, Repository वो जगह है जहाँ सब blueprints रखे हैं, और Revision बताता है कि blueprint में कितनी बार बदलाव हुआ।*

---

### Chart Structure

When you create a chart, Helm generates a standard directory structure:

```
my-app/
├── Chart.yaml          # Chart metadata (name, version, appVersion)
├── values.yaml         # Default configuration values
├── charts/             # Dependency charts (subcharts)
├── templates/          # Kubernetes manifest templates
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   ├── serviceaccount.yaml
│   ├── _helpers.tpl    # Reusable template snippets
│   ├── NOTES.txt       # Post-install usage instructions
│   └── tests/
│       └── test-connection.yaml
├── .helmignore         # Files to exclude from packaging
└── README.md           # Chart documentation
```

**Chart.yaml — The Identity Card:**

```yaml
apiVersion: v2
name: my-app
description: A Helm chart for my web application
type: application
version: 0.1.0        # Chart version (changes when chart structure changes)
appVersion: "1.16.0"   # Application version (the actual app being deployed)
dependencies:
  - name: postgresql
    version: "12.1.0"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
```

**values.yaml — The Configuration Knobs:**

```yaml
replicaCount: 3

image:
  repository: nginx
  tag: "1.25"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

ingress:
  enabled: false
  className: nginx
  hosts:
    - host: myapp.local
      paths:
        - path: /
          pathType: Prefix

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

*Chart.yaml ऐसे समझो जैसे product का label — नाम, version, description। values.yaml ऐसे है जैसे order form — "कितने pieces चाहिए, कौन सा color, कितना size" — सब customize कर सकते हो बिना main template बदले।*

---

### Template Functions

Helm uses **Go template syntax** with the Sprig function library. Here are the most important functions:

#### `{{ .Values.x }}` — Accessing Values

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-app
spec:
  replicas: {{ .Values.replicaCount }}
  template:
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
```

#### `include` and `_helpers.tpl` — Reusable Snippets

```yaml
# templates/_helpers.tpl
{{- define "my-app.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "my-app.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

```yaml
# templates/deployment.yaml
metadata:
  name: {{ include "my-app.fullname" . }}
  labels:
    {{- include "my-app.labels" . | nindent 4 }}
```

#### `toYaml` — Converting Objects to YAML

```yaml
resources:
  {{- toYaml .Values.resources | nindent 10 }}
```

#### `default` — Fallback Values

```yaml
image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default "latest" }}"
```

#### `required` — Mandatory Values

```yaml
image: "{{ required "image.repository is required" .Values.image.repository }}"
```

#### `if/else` — Conditional Rendering

```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "my-app.fullname" . }}
spec:
  # ... ingress spec
{{- end }}
```

#### `range` — Looping

```yaml
{{- range .Values.ingress.hosts }}
  - host: {{ .host | quote }}
    http:
      paths:
        {{- range .paths }}
        - path: {{ .path }}
          pathType: {{ .pathType }}
        {{- end }}
{{- end }}
```

*Template functions को ऐसे समझो — `include` मतलब "यह paragraph हर page पर copy करो", `if` मतलब "अगर customer ने extra cheese माँगा तो डालो", `range` मतलब "हर item के लिए यह step repeat करो", और `default` मतलब "अगर customer ने कुछ नहीं बोला तो medium size दे दो।"*

---

### Helm CLI Commands Deep Dive

#### Installing a Chart

```bash
# From a repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install my-release bitnami/nginx

# From a local directory
helm install my-release ./my-app

# With custom values file
helm install my-release bitnami/nginx -f prod-values.yaml

# With inline overrides
helm install my-release bitnami/nginx --set replicaCount=5 --set service.type=LoadBalancer

# Dry run (see rendered manifests without applying)
helm install my-release bitnami/nginx --dry-run --debug

# Install in a specific namespace (create if not exists)
helm install my-release bitnami/nginx -n monitoring --create-namespace
```

#### Upgrading a Release

```bash
# Upgrade with new values
helm upgrade my-release bitnami/nginx --set image.tag=1.26

# Upgrade with a values file
helm upgrade my-release bitnami/nginx -f prod-values.yaml

# Install if not exists, upgrade if exists
helm upgrade --install my-release bitnami/nginx -f values.yaml
```

#### Rollback

```bash
# Check release history
helm history my-release

# Rollback to previous revision
helm rollback my-release 1

# Rollback with a specific timeout
helm rollback my-release 2 --timeout 5m
```

#### Other Essential Commands

```bash
# List all releases
helm list -A

# Uninstall a release
helm uninstall my-release

# Show rendered templates
helm template my-release ./my-app

# Get release values
helm get values my-release

# Get all release info
helm get all my-release

# Search for charts
helm search repo nginx
helm search hub prometheus
```

**`--set` vs `-f` (values file):**

| Aspect | `--set` | `-f values.yaml` |
|---|---|---|
| Use case | Quick overrides, CI/CD pipelines | Environment-specific configurations |
| Readability | Hard to read with many values | Clean, version-controlled |
| Nested values | `--set ingress.hosts[0].host=myapp.com` | Natural YAML nesting |
| Best for | 1-3 overrides | Production deployments |

*`--set` ऐसे है जैसे phone पर order देते वक़्त बोलो "extra cheese डाल दो।" `-f values.yaml` ऐसे है जैसे पूरा order form भरकर दो — ज़्यादा organized और बाद में record रहता है।*

---

### Creating Your Own Chart from Scratch

```bash
# Scaffold a new chart
helm create my-webapp

# This generates the full chart structure
# Edit values.yaml and templates/ to match your application

# Validate the chart
helm lint my-webapp

# Render templates locally to verify output
helm template test-release my-webapp

# Package the chart for distribution
helm package my-webapp
# Output: my-webapp-0.1.0.tgz

# Install from the packaged chart
helm install my-release my-webapp-0.1.0.tgz
```

---

### Helmfile for Multi-Release Management

**Helmfile** is a declarative tool that manages multiple Helm releases as code.

```yaml
# helmfile.yaml
repositories:
  - name: prometheus-community
    url: https://prometheus-community.github.io/helm-charts
  - name: grafana
    url: https://grafana.github.io/helm-charts

releases:
  - name: prometheus
    namespace: monitoring
    createNamespace: true
    chart: prometheus-community/kube-prometheus-stack
    version: 55.5.0
    values:
      - ./values/prometheus-values.yaml

  - name: grafana
    namespace: monitoring
    chart: grafana/grafana
    version: 7.0.0
    values:
      - ./values/grafana-values.yaml
    needs:
      - monitoring/prometheus
```

```bash
# Install Helmfile
# (binary download from github.com/helmfile/helmfile)

# Apply all releases
helmfile apply

# Diff before applying (shows what will change)
helmfile diff

# Destroy all releases
helmfile destroy

# Sync specific releases
helmfile -l name=prometheus apply
```

*Helmfile ऐसे समझो जैसे एक event planner — "पहले catering (Prometheus) setup करो, फिर decoration (Grafana) करो" — सब कुछ एक ही file में define है, order भी और dependencies भी।*

---

## Step-by-Step Lab: Deploy Prometheus Stack via Helm

> [!note] Prerequisites
> - Minikube running with at least 4GB memory: `minikube start --memory=4096 --driver=docker`
> - Helm 3 installed: verify with `helm version`

### Step 1: Add the Prometheus Helm Repository

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### Step 2: Inspect Available Values

```bash
# See all configurable values
helm show values prometheus-community/kube-prometheus-stack > default-values.yaml

# Review the file to understand what can be customized
# Key sections: alertmanager, grafana, prometheus, nodeExporter
```

### Step 3: Create Custom Values File

```bash
cat <<EOF > custom-prom-values.yaml
# Customize Grafana
grafana:
  adminPassword: "DevOps@123"
  service:
    type: NodePort
    nodePort: 30080
  persistence:
    enabled: false

# Customize Prometheus
prometheus:
  prometheusSpec:
    retention: 7d
    resources:
      requests:
        memory: 512Mi
        cpu: 250m
      limits:
        memory: 1Gi
        cpu: 500m

# Disable components not needed for lab
alertmanager:
  enabled: false

nodeExporter:
  enabled: true
EOF
```

### Step 4: Install the Prometheus Stack

```bash
helm install prom-stack prometheus-community/kube-prometheus-stack \
  -f custom-prom-values.yaml \
  -n monitoring \
  --create-namespace \
  --version 55.5.0

# Verify the release
helm list -n monitoring
```

### Step 5: Verify Pods are Running

```bash
kubectl get pods -n monitoring
# Expected output:
# NAME                                                     READY   STATUS    RESTARTS   AGE
# prom-stack-grafana-xxxx                                   3/3     Running   0          2m
# prom-stack-kube-prometheus-operator-xxxx                  1/1     Running   0          2m
# prom-stack-kube-state-metrics-xxxx                        1/1     Running   0          2m
# prom-stack-prometheus-node-exporter-xxxx                  1/1     Running   0          2m
# prometheus-prom-stack-kube-prometheus-prometheus-0         2/2     Running   0          2m
```

### Step 6: Access Grafana

```bash
# Get the Grafana URL
minikube service prom-stack-grafana -n monitoring --url

# Or port-forward
kubectl port-forward svc/prom-stack-grafana 3000:80 -n monitoring

# Open http://localhost:3000
# Login: admin / DevOps@123
```

### Step 7: Upgrade the Release (Change Values)

```bash
# Increase Prometheus retention to 14 days
helm upgrade prom-stack prometheus-community/kube-prometheus-stack \
  -f custom-prom-values.yaml \
  --set prometheus.prometheusSpec.retention=14d \
  -n monitoring

# Check revision history
helm history prom-stack -n monitoring
# REVISION  UPDATED                   STATUS      CHART                            APP VERSION  DESCRIPTION
# 1         2025-06-27 10:00:00       superseded  kube-prometheus-stack-55.5.0     0.71.0       Install complete
# 2         2025-06-27 10:15:00       deployed    kube-prometheus-stack-55.5.0     0.71.0       Upgrade complete
```

### Step 8: Rollback the Release

```bash
# Rollback to revision 1
helm rollback prom-stack 1 -n monitoring

# Verify rollback
helm history prom-stack -n monitoring
# REVISION  UPDATED                   STATUS      CHART                            APP VERSION  DESCRIPTION
# 1         2025-06-27 10:00:00       superseded  kube-prometheus-stack-55.5.0     0.71.0       Install complete
# 2         2025-06-27 10:15:00       superseded  kube-prometheus-stack-55.5.0     0.71.0       Upgrade complete
# 3         2025-06-27 10:20:00       deployed    kube-prometheus-stack-55.5.0     0.71.0       Rollback to 1

# Confirm retention is back to 7d
helm get values prom-stack -n monitoring
```

### Step 9: Cleanup

```bash
helm uninstall prom-stack -n monitoring
kubectl delete namespace monitoring

# Remove the repo
helm repo remove prometheus-community
```

---

## Commands Cheat Sheet

| Command | Description |
|---|---|
| `helm repo add <name> <url>` | Add a chart repository |
| `helm repo update` | Update local chart repository cache |
| `helm search repo <keyword>` | Search for charts in added repositories |
| `helm install <release> <chart> -n <ns> --create-namespace` | Install a chart as a named release in a namespace |
| `helm upgrade --install <release> <chart> -f values.yaml` | Upgrade or install if not present (idempotent) |
| `helm rollback <release> <revision>` | Rollback a release to a specific revision number |
| `helm uninstall <release> -n <ns>` | Delete a release and its resources |
| `helm list -A` | List all releases across all namespaces |
| `helm history <release> -n <ns>` | Show revision history of a release |
| `helm get values <release> -n <ns>` | Show user-supplied values for a release |
| `helm show values <chart>` | Show all default values of a chart |
| `helm template <release> <chart> -f values.yaml` | Render templates locally without installing |
| `helm create <name>` | Scaffold a new chart directory structure |
| `helm lint <chart-dir>` | Validate a chart for errors and best practices |
| `helm package <chart-dir>` | Package a chart into a versioned `.tgz` archive |
| `helm dependency update <chart-dir>` | Download and update chart dependencies |

---

## Troubleshooting Guide

| Problem | Symptoms | Root Cause | Solution |
|---|---|---|---|
| `Error: INSTALLATION FAILED: cannot re-use a name that is still in use` | Helm install fails | A release with the same name already exists | Use `helm upgrade --install` instead, or `helm uninstall <release>` first |
| `Error: UPGRADE FAILED: "release" has no deployed releases` | Helm upgrade fails on first run | Using `helm upgrade` without `--install` when no release exists | Always use `helm upgrade --install` for idempotent deployments |
| Rendered template has wrong values | Deployment has unexpected config | Wrong values file used or `--set` override typo | Run `helm template <release> <chart> -f values.yaml` to preview rendered output |
| `Error: chart requires kubeVersion: >=1.25.0` | Install fails with version mismatch | Kubernetes cluster version is older than chart requirement | Upgrade cluster or use an older chart version compatible with your cluster |
| `Error: INSTALLATION FAILED: unable to build kubernetes objects: unknown field "spec.ingressClassName"` | Template renders invalid YAML | Chart version incompatible with K8s API version | Check chart compatibility matrix; use `--version` to pin a compatible chart version |
| Rollback doesn't restore data | Helm rollback succeeds but database is empty | Helm rollback only rolls back K8s manifests, not PVC data | Implement separate data backup/restore procedures; Helm doesn't manage data |
| `Error: repo "bitnami" not found` | Helm install fails | Repository not added or cache outdated | Run `helm repo add bitnami https://charts.bitnami.com/bitnami && helm repo update` |

---

## Real-World Scenario

### Scenario: Standardizing Microservices Deployment at Scale

**Company:** A logistics company running 40+ microservices on GKE (Google Kubernetes Engine).

**Problem:** Each team maintained their own raw YAML files. Deployments were inconsistent — some services had health checks, some didn't. Some had resource limits, some consumed unbounded memory causing node OOM kills. Rolling out a company-wide change (like adding a sidecar proxy) required editing 40+ repositories manually.

**Solution Implemented:**

1. **Created a Base Helm Chart** — A "golden" chart called `company-service` with production best practices baked in:
   - Health checks (liveness + readiness) enabled by default
   - Resource limits required (using `required` template function)
   - Security context with `runAsNonRoot: true` by default
   - Standard labels and annotations for observability

2. **Per-Service `values.yaml`** — Each microservice only defined its unique configuration:
   ```yaml
   image:
     repository: gcr.io/company/order-service
     tag: "v2.3.1"
   replicaCount: 3
   env:
     DATABASE_URL: "postgres://..."
   ```

3. **Helmfile for Environment Management** — One `helmfile.yaml` per environment (dev, staging, prod) defining all 40+ releases with environment-specific overrides.

4. **CI/CD Integration** — GitHub Actions pipeline ran:
   ```bash
   helm lint ./charts/company-service
   helm template test ./charts/company-service -f services/order-service/values.yaml
   helm upgrade --install order-service ./charts/company-service \
     -f services/order-service/values.yaml \
     -f environments/prod-values.yaml \
     -n order-service --create-namespace
   ```

**Result:**
- Deployment consistency went from ~60% to 100% (health checks, limits on every service).
- Company-wide changes (adding a sidecar) took 1 PR to the base chart instead of 40.
- Average deployment time dropped from 25 minutes (manual YAML review) to 4 minutes (automated pipeline).
- OOM incidents reduced by 85% because resource limits were now mandatory.

*यह story बताती है कि Helm सिर्फ install tool नहीं है — यह standardization tool है। जैसे एक franchise (McDonald's) में हर outlet एक ही recipe follow करता है, वैसे ही Helm chart ensure करता है कि हर microservice एक ही production standard follow करे।*

---

## Interview Questions

### Q1: What problem does Helm solve in Kubernetes?
**Answer:** Helm solves the YAML management problem. Without Helm, deploying an application requires creating and maintaining multiple YAML files (Deployment, Service, ConfigMap, etc.) for each environment. Helm packages these into templated charts where environment-specific values are parameterized, enables versioned releases with rollback capability, and provides a standardized way to share and distribute application packages via repositories.

### Q2: Explain the difference between `helm install` and `helm upgrade --install`.
**Answer:** `helm install` creates a new release and fails if a release with that name already exists. `helm upgrade --install` is idempotent — it installs the release if it doesn't exist, and upgrades it if it does. In CI/CD pipelines, `helm upgrade --install` is the preferred pattern because it works regardless of whether the release has been deployed before.

### Q3: What is the difference between Chart version and App version in Chart.yaml?
**Answer:** The **chart version** (`version` field) tracks changes to the chart itself — template modifications, new values, structural changes. The **app version** (`appVersion` field) tracks the version of the application being deployed (e.g., Nginx 1.25). They are versioned independently. You might bump the chart version to add a new template without changing the app version.

### Q4: How does Helm handle rollbacks internally?
**Answer:** Helm stores release metadata as Kubernetes Secrets (by default) in the release namespace. Each install or upgrade creates a new revision. When you run `helm rollback <release> <revision>`, Helm retrieves the manifest from the specified revision's Secret and applies it to the cluster. It creates a new revision entry (not a delete). Importantly, Helm only rolls back Kubernetes resource definitions — it does not roll back data in PersistentVolumes.

### Q5: What is the difference between `--set` and `-f` when overriding values?
**Answer:** `--set` provides inline value overrides on the command line (e.g., `--set replicaCount=5`). It's useful for quick overrides or CI/CD variable injection. `-f` (or `--values`) takes a YAML file with overrides. It's more readable, version-controllable, and suitable for complex configurations. Multiple `-f` flags can be used, with later files taking precedence. In production, `-f` is preferred for traceability.

### Q6: How would you manage Helm charts for 50+ microservices across multiple environments?
**Answer:** Use **Helmfile** to declaratively manage all releases in a single `helmfile.yaml` per environment. Create a base Helm chart with production best practices and have each service provide only its `values.yaml`. Use Helmfile's `environments` feature for dev/staging/prod differentiation. Store everything in Git for auditability. In CI/CD, use `helmfile diff` to preview changes and `helmfile apply` to deploy.

### Q7: What happens when you run `helm uninstall`? Does it delete PVCs?
**Answer:** `helm uninstall` removes all Kubernetes resources that were created by the chart (Deployments, Services, ConfigMaps, etc.) and deletes the release metadata (Secrets). However, PersistentVolumeClaims (PVCs) created by StatefulSets are **not** deleted by default because they may contain critical data. You must manually delete PVCs after uninstalling. Some charts have a `persistence.resourcePolicy` annotation to control this behavior.

---

## Related Notes

- [[K8S-01 Architecture & Components]] — Understanding the API server that Helm communicates with
- [[K8S-02 Pods & Workloads]] — Deployments, StatefulSets managed by Helm charts
- [[K8S-04 Storage]] — PersistentVolumeClaims in Helm charts and rollback limitations
- [[K8S-05 ConfigMaps & Secrets]] — Templating ConfigMaps and Secrets in Helm
- [[K8S-06 RBAC and Security]] — RBAC for Helm ServiceAccounts and Tiller (v2) security
- [[Docker-01 Foundations]] — Container images referenced in Helm values
