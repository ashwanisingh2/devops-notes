---
tags: [devops, kubernetes, configuration, security]
aliases: [K8s Config & Secrets]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #cka
---

# K8S-03 ConfigMaps and Secrets

> [!abstract] Overview
> A core principle of modern DevOps (12-Factor App) is that configuration must be strictly separated from code. You should not bake database passwords or environment-specific API URLs directly into your Docker images. Kubernetes solves this using ConfigMaps (for non-sensitive data) and Secrets (for sensitive data), allowing you to inject configuration into your Pods at runtime via environment variables or mounted files.

---

## Concept Overview

- **What it is** — **ConfigMaps** are K8s objects used to store non-confidential data in key-value pairs. **Secrets** are similar but are used to store sensitive data like passwords, OAuth tokens, and SSH keys.
- **Why DevOps engineers use it** — To make container images reusable. You build a single `my-app:v1` image, but you inject a `dev-config` ConfigMap in the Dev cluster and a `prod-config` ConfigMap in the Prod cluster. No need to rebuild images for different environments.
- **Where you encounter this in a real job** — Changing an application's log level from INFO to DEBUG without touching the code, or mounting a custom `nginx.conf` file into a web server pod.
- **Responsibility Split:**
  - **Junior DevOps**: Creates basic ConfigMaps from literal values and mounts them as environment variables.
  - **Mid DevOps**: Mounts ConfigMaps as files in volumes, and manages base64 encoding for native K8s Secrets.
  - **Senior/SRE**: Implements GitOps-friendly secret management using Sealed Secrets or the External Secrets Operator (syncing HashiCorp Vault/AWS Secrets Manager to K8s).

*Seedha simple mein: ConfigMap ek instruction manual hai aur Secret ek locker ki chabhi hai. Aap apne worker (Pod) ko kaam pe lagate waqt manual (env vars) aur chabhi (password) pakda dete ho, taaki worker ko pata ho ki kaam kaise karna hai bina code change kiye.*

---

## Technical Deep Dive

### 1. ConfigMaps: Env Vars vs. Volumes
ConfigMaps can be injected into a Pod in two ways:
1. **Environment Variables**: The key-value pairs become standard Linux env vars inside the container. Limitation: If you update the ConfigMap, the Pod *will not* see the changes until it is restarted.
2. **Volume Mounts**: The ConfigMap is mounted as a physical file (or directory) inside the container's filesystem. Benefit: If you update the ConfigMap, K8s will eventually update the mounted file automatically without restarting the pod (useful for apps that can auto-reload config files).

### 2. K8s Secrets (The Base64 Illusion)
By default, native Kubernetes Secrets are **NOT encrypted**. They are merely **Base64 encoded**. This means anyone who can run `kubectl get secret` can easily decode the password. Secrets are stored in `etcd`, so `etcd` encryption at rest must be enabled by the cluster administrator to achieve true security.
K8s supports different secret types, such as `Opaque` (generic data), `kubernetes.io/tls` (for SSL certificates), and `kubernetes.io/dockerconfigjson` (to authenticate to private Docker registries).

### 3. The GitOps Secret Problem (External/Sealed Secrets)
If we want to store all our K8s YAML files in GitHub (GitOps), we have a problem: we cannot commit plain-text or Base64 Secrets to GitHub.
To solve this, SREs use:
- **Sealed Secrets**: A tool by Bitnami that encrypts the Secret using public-key cryptography. You can safely commit the encrypted `SealedSecret` YAML to GitHub. Only the Sealed Secrets controller running *inside* the K8s cluster has the private key to decrypt it into a normal K8s Secret.
- **External Secrets Operator (ESO)**: Instead of defining secrets in K8s, you define them in AWS Secrets Manager or HashiCorp Vault. ESO runs in K8s, authenticates to AWS/Vault, fetches the secret, and automatically creates a native K8s Secret.

---

## Step-by-Step Lab

> [!warning] Pre-requisites
> - A running K8s cluster
> - Kubectl configured

### Step 1: Create a ConfigMap and a Secret
```bash
# Create a ConfigMap from literal values
kubectl create configmap app-config --from-literal=APP_COLOR=blue --from-literal=LOG_LEVEL=info

# Create a Secret (kubectl handles the base64 encoding for you here)
kubectl create secret generic db-credentials --from-literal=username=admin --from-literal=password=SuperSecret123!

# Expected output:
# configmap/app-config created
# secret/db-credentials created
```

### Step 2: Decode the Secret to prove it is NOT encrypted
```bash
# Get the secret in YAML format
kubectl get secret db-credentials -o yaml

# You will see: password: U3VwZXJTZWNyZXQxMjMh
# Decode it manually using base64:
echo "U3VwZXJTZWNyZXQxMjMh" | base64 --decode

# Expected output: SuperSecret123!
```

### Step 3: Injecting Env Vars into a Pod
```yaml
# Create pod-env.yaml
cat << 'EOF' > pod-env.yaml
apiVersion: v1
kind: Pod
metadata:
  name: env-test-pod
spec:
  containers:
    - name: alpine
      image: alpine
      command: ["sleep", "3600"]
      envFrom:
        - configMapRef:
            name: app-config
        - secretRef:
            name: db-credentials
EOF

# Apply it and verify the env vars exist inside the running container
kubectl apply -f pod-env.yaml
sleep 5
kubectl exec env-test-pod -- env | grep -E "APP_COLOR|password"

# Expected output:
# APP_COLOR=blue
# password=SuperSecret123!
```

### Step 4: Mount a ConfigMap as a File (Volume)
```bash
# First, create a ConfigMap from a file
echo "server { listen 80; server_name localhost; }" > my-nginx.conf
kubectl create configmap nginx-config --from-file=my-nginx.conf

# Create pod-vol.yaml
cat << 'EOF' > pod-vol.yaml
apiVersion: v1
kind: Pod
metadata:
  name: vol-test-pod
spec:
  containers:
    - name: nginx
      image: nginx:alpine
      volumeMounts:
        - name: config-volume
          mountPath: /etc/nginx/conf.d/
  volumes:
    - name: config-volume
      configMap:
        name: nginx-config
EOF

kubectl apply -f pod-vol.yaml
```

### Step 5: Verify the Mounted File
```bash
# Exec into the pod and cat the file at the mount path
sleep 5
kubectl exec vol-test-pod -- cat /etc/nginx/conf.d/my-nginx.conf

# Expected output:
# server { listen 80; server_name localhost; }
```

> [!tip] Pro Tip
> In production, configure your ConfigMaps and Secrets as **Immutable** (`immutable: true` in the YAML). This prevents accidental changes, drastically reduces API server load (kubelet stops polling for updates), and forces a safer rollout practice (create a new ConfigMap name and update the Deployment to use it).

---

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
|---------|-------------|--------------|
| `kubectl create configmap` | Creates a CM from literals or files | `kubectl create cm my-config --from-file=config.txt` |
| `kubectl create secret` | Creates a Secret from literals or files | `kubectl create secret generic my-sec --from-literal=key=val` |
| `kubectl get cm` | Lists ConfigMaps in the namespace | `kubectl get cm` |
| `kubectl get secret` | Lists Secrets in the namespace | `kubectl get secret` |
| `kubectl describe cm` | Views the contents of a ConfigMap | `kubectl describe cm app-config` |
| `kubectl get secret -o yaml`| Dumps the Secret, revealing base64 encoded data | `kubectl get secret db-creds -o yaml` |
| `echo "txt" \| base64` | Encodes a string to base64 for manual YAML creation | `echo -n "admin" \| base64` |
| `echo "dG8=" \| base64 -d` | Decodes a base64 string | `echo "dG8=" \| base64 --decode` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| Pod stuck in `CreateContainerConfigError` | ConfigMap or Secret does not exist | Run `kubectl get cm` or `kubectl get secret`. Create the missing resource or fix the typo in your Pod YAML. |
| Env var has an unexpected newline/whitespace | Base64 encoded with a trailing newline | When encoding manually, ALWAYS use `echo -n "pass" | base64` (the `-n` removes the trailing newline). |
| App doesn't see updated ConfigMap values | Env vars were used instead of volumes | Env vars are static upon pod creation. You must restart the pod (`kubectl rollout restart deploy/name`) to load new values. |
| Cannot pull image from private registry | Missing ImagePullSecret | Create a `docker-registry` secret and add `imagePullSecrets: - name: my-secret` to the Pod spec. |
| Mounted file overwrites the entire directory | Using `mountPath: /etc/nginx` without `subPath` | If you mount to a directory, K8s hides the original contents. Use `subPath: nginx.conf` to mount a single file into an existing directory. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A developer hardcoded the staging database password in their source code and committed it to GitHub. The security team flagged it as a severe violation."

**What Junior DevOps Does:**
Tells the developer to remove it from the code and passes the password via an environment variable directly in the Deployment YAML file (e.g., `env: - name: DB_PASS, value: "pass123"`). The security team flags this again because the Deployment YAML is ALSO committed to GitHub.

**Escalation Trigger:**
The team cannot deploy the app until the password is removed from all version-controlled files.

**Senior Engineer Resolution:**
1. Instructs the developer to read the password from an environment variable (`process.env.DB_PASS`).
2. Generates the password securely inside the cloud provider's secret manager (e.g., AWS Secrets Manager).
3. Installs the **External Secrets Operator** in the K8s cluster.
4. Creates an `ExternalSecret` K8s manifest (which contains no passwords, just a reference to AWS).
5. ESO fetches the password from AWS and creates a native K8s Secret dynamically.
6. The Deployment YAML references this K8s Secret using `secretKeyRef`.
7. Now, all YAMLs in GitHub are completely free of sensitive data, satisfying the security audit.

**Lesson Learned:**
Secrets belong in Secret Managers, not in Git repositories, and definitely not in container images. Use Kubernetes Secrets to bridge the gap securely at runtime.

---

## Interview Questions

**Q1 (Conceptual):** Why is a Kubernetes Secret not truly secure by default?
**A:** By default, Kubernetes Secrets are only Base64 encoded, not encrypted. Base64 is an encoding mechanism, not encryption; anyone can decode it instantly. True security requires enabling `etcd` encryption at rest and strictly managing RBAC rules to control who can run `kubectl get secret`.

**Q2 (Practical):** You need to provide a configuration file `settings.json` to a running container, but the application expects it at a specific path `/app/config/settings.json` and it must update dynamically if the ConfigMap changes. How do you configure the Pod?
**A:** I would store the JSON in a ConfigMap using `--from-file`. Then, in the Pod spec, I would define a `volume` referencing the ConfigMap. Under the container spec, I would define a `volumeMount` with `mountPath: /app/config`. Since it's mounted as a volume, K8s will automatically update the file inside the container when the ConfigMap changes.

**Q3 (Scenario-based):** You updated a ConfigMap that is injected into a Deployment via environment variables, but the application is still using the old configuration. Why, and how do you fix it?
**A:** Environment variables are injected only when the container starts. Updating the ConfigMap does not automatically restart the Pods. To fix it, I must trigger a restart of the Pods, usually by running `kubectl rollout restart deployment/<name>`.

**Q4 (Deep dive):** What is the `subPath` property used for in Volume Mounts?
**A:** Normally, when you mount a ConfigMap or Secret as a volume to a directory (e.g., `/etc/nginx/conf.d`), K8s hides any existing files in that target directory, replacing it entirely with the volume contents. If you only want to inject a single file into a directory without hiding the other files already there, you use `subPath` to mount precisely that one file.

**Q5 (Trick/Gotcha):** Can a Pod in `Namespace-A` reference a ConfigMap in `Namespace-B`?
**A:** No. ConfigMaps and Secrets are namespace-scoped. A Pod can only reference ConfigMaps and Secrets that exist in its own exact namespace. If multiple namespaces need the same config, you must create a copy of the ConfigMap in each namespace, or use a third-party tool like Kyverno or Reflector to replicate them automatically.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[04-Orchestration/K8S-02 Pods Deployments Services|Pods and Deployments]]
[[09-Security-DevSecOps/SEC-03 Secrets Management|Secrets Management]]
