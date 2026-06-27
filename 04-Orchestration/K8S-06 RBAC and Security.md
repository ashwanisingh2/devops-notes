---
tags:
  - devops
  - kubernetes
  - security
aliases:
  - K8s Security
created: 2025-06-27
status: "#complete"
difficulty: "#advanced"
cert-relevant: "#cka #ckad"
---

# RBAC and Security in Kubernetes

> [!abstract] Overview
> Kubernetes clusters run mission-critical workloads, which makes security a non-negotiable pillar of any production deployment. Role-Based Access Control (RBAC) governs **who** can do **what** on **which** resources inside the cluster. Beyond RBAC, Kubernetes offers Pod Security Standards, Security Contexts, ServiceAccounts, and integration with external tools like `kube-bench` for CIS benchmark scanning. This note covers the full security stack—from authentication to runtime hardening—so you can lock down a cluster the way enterprises demand.
>
> *Kubernetes security को समझना ऐसा है जैसे एक बड़े ऑफिस बिल्डिंग की सिक्योरिटी सेट करना — कौन किस फ्लोर पर जा सकता है, किसके पास कौन सी चाबी है, और कौन सा कमरा सबके लिए खुला है — यह सब RBAC तय करता है।*

---

## Concept Overview

### Authentication vs Authorization in Kubernetes

Kubernetes separates **identity verification** (authentication) from **permission checks** (authorization).

| Aspect | Authentication (AuthN) | Authorization (AuthZ) |
|---|---|---|
| Question answered | "Who are you?" | "Are you allowed to do this?" |
| Mechanisms | X.509 certificates, Bearer tokens, OIDC, ServiceAccount tokens | RBAC, ABAC, Webhook, Node authorizer |
| Configured via | API server flags (`--client-ca-file`, `--oidc-issuer-url`) | API server flag `--authorization-mode=RBAC` |
| Default in kubeadm | X.509 client certs for admin | RBAC enabled by default |

*Authentication ऐसे समझो जैसे गेट पर ID कार्ड दिखाना — "तुम कौन हो?" और Authorization ऐसे है जैसे गार्ड चेक करे कि "तुम्हें इस फ्लोर पर जाने की permission है या नहीं।"*

When a `kubectl` command hits the API server, it passes through:
1. **Authentication** — validates the certificate/token
2. **Authorization** — checks RBAC policies
3. **Admission Control** — mutating/validating webhooks

---

### ServiceAccounts

Every Pod in Kubernetes runs under a **ServiceAccount**. If you don't specify one, it uses the `default` ServiceAccount in the namespace.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: monitoring-sa
  namespace: monitoring
automountServiceAccountToken: true
```

**Why apps need ServiceAccounts:**
- Pods that interact with the Kubernetes API (e.g., Prometheus scraping metrics, operators managing CRDs) need an identity.
- The ServiceAccount token is auto-mounted at `/var/run/secrets/kubernetes.io/serviceaccount/token`.
- Without explicit ServiceAccounts, all pods share the `default` SA — a security anti-pattern.

*ServiceAccount एक employee ID badge जैसा है। हर Pod को एक badge मिलता है जिससे cluster को पता चलता है कि यह Pod कौन सी application चला रहा है और उसे क्या-क्या access दिया जाए।*

**Best Practice:** Always create dedicated ServiceAccounts per application. Never grant permissions to the `default` SA.

```bash
# Create a ServiceAccount
kubectl create serviceaccount monitoring-sa -n monitoring

# Check the SA
kubectl get serviceaccount monitoring-sa -n monitoring -o yaml
```

---

### Roles vs ClusterRoles

| Feature | Role | ClusterRole |
|---|---|---|
| Scope | Single namespace | Cluster-wide |
| Use case | App-level permissions | Admin/cross-namespace permissions |
| Can access cluster resources (nodes, PVs)? | No | Yes |
| Example | Read pods in `dev` namespace | Read pods in all namespaces |

**Role Example — Read-Only Pods in a Namespace:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: monitoring
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
```

**ClusterRole Example — Read Nodes Cluster-Wide:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
```

*Role एक department-level access card है — सिर्फ उसी floor पर काम करता है। ClusterRole एक master key है — पूरी building में access देता है।*

---

### RoleBindings vs ClusterRoleBindings

A **RoleBinding** links a Role (or ClusterRole) to a user/group/ServiceAccount **within a namespace**. A **ClusterRoleBinding** links a ClusterRole to a subject **cluster-wide**.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: monitoring-pod-reader
  namespace: monitoring
subjects:
- kind: ServiceAccount
  name: monitoring-sa
  namespace: monitoring
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

> [!important]
> You can bind a ClusterRole with a RoleBinding to grant cluster-level permissions scoped to a single namespace. This is a powerful pattern for reusing ClusterRoles across multiple namespaces without duplicating Role definitions.

*RoleBinding ऐसे समझो कि तुमने ID badge (ServiceAccount) को एक specific floor की access list में add कर दिया। ClusterRoleBinding मतलब पूरे building की access list में नाम डाल दिया।*

---

### Least-Privilege Principle in Practice

The **principle of least privilege** means granting only the minimum permissions required for a workload to function.

**Anti-Patterns to Avoid:**
- Binding `cluster-admin` ClusterRole to application ServiceAccounts
- Using the `default` ServiceAccount with broad permissions
- Granting `*` (wildcard) verbs or resources
- Leaving `automountServiceAccountToken: true` on pods that don't need API access

**Correct Approach:**
1. Create a dedicated ServiceAccount per application
2. Define a narrow Role with only needed verbs and resources
3. Bind the Role to the ServiceAccount
4. Set `automountServiceAccountToken: false` on pods that don't call the K8s API

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: simple-web
spec:
  serviceAccountName: web-sa
  automountServiceAccountToken: false
  containers:
  - name: nginx
    image: nginx:1.25
```

*Least privilege ऐसे समझो — अगर किसी को सिर्फ canteen जाना है तो उसे server room की चाबी क्यों दें? जितना काम, उतनी permission।*

---

### Pod Security Standards (PSS)

Kubernetes defines three built-in **Pod Security Standards** enforced via the `PodSecurity` admission controller (replacing the deprecated PodSecurityPolicy):

| Standard | Description | Use Case |
|---|---|---|
| **Privileged** | No restrictions at all | System-level workloads (CNI plugins, logging agents) |
| **Baseline** | Prevents known privilege escalations | General-purpose workloads |
| **Restricted** | Heavily restricted, follows hardening best practices | Security-sensitive and multi-tenant workloads |

**Enforcement Modes:**
- `enforce` — Rejects pods that violate the standard
- `audit` — Allows but logs violations
- `warn` — Allows but shows warnings to the user

**Applying PSS to a Namespace:**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secure-apps
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

*PSS ऐसे समझो जैसे बिल्डिंग में तीन ज़ोन हों — Green Zone (privileged) में कोई भी जा सकता है, Yellow Zone (baseline) में कुछ restrictions हैं, और Red Zone (restricted) में सिर्फ verified लोग ही जा सकते हैं।*

---

### Security Context

A **SecurityContext** is defined at the pod or container level to control runtime security settings.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
          - ALL
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```

**Key Fields Explained:**

| Field | Effect |
|---|---|
| `runAsNonRoot: true` | Container must run as non-root; fails if image runs as root |
| `runAsUser: 1000` | Sets the UID for the container process |
| `readOnlyRootFilesystem: true` | Makes the root filesystem read-only; app must use mounted volumes for writes |
| `allowPrivilegeEscalation: false` | Prevents `setuid` binaries from gaining extra privileges |
| `capabilities.drop: [ALL]` | Drops all Linux capabilities (NET_RAW, SYS_ADMIN, etc.) |

*Security Context ऐसे है जैसे किसी employee को rules दे दो — "बस अपनी desk पर बैठो (readOnly), admin cabin मत जाओ (no escalation), और अपना ID हमेशा पहनो (runAsNonRoot)।"*

---

### kube-bench for CIS Scanning

**kube-bench** is an open-source tool by Aqua Security that checks Kubernetes clusters against the **CIS Kubernetes Benchmark**.

```bash
# Run kube-bench as a Job in the cluster
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml

# Check results
kubectl logs job/kube-bench

# Run locally (if binary installed)
kube-bench run --targets master
kube-bench run --targets node
```

**What it checks:**
- API server configuration (authentication, authorization flags)
- etcd encryption and access control
- Kubelet configuration (anonymous auth, read-only port)
- Controller manager and scheduler settings
- Pod security policies/standards

*kube-bench ऐसे समझो जैसे building का annual security audit — एक inspector आकर हर दरवाज़ा, हर lock, हर camera check करता है और report बनाता है कि क्या ठीक है और क्या fix करना है।*

---

## Step-by-Step Lab: Read-Only ServiceAccount for Monitoring

> [!note] Prerequisites
> - Minikube or Docker Desktop with Kubernetes enabled
> - `kubectl` configured and working

### Step 1: Start Minikube and Create Namespace

```bash
minikube start --driver=docker

kubectl create namespace monitoring
```

### Step 2: Create a ServiceAccount

```bash
kubectl create serviceaccount monitoring-sa -n monitoring
```

### Step 3: Create a Read-Only Role

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: monitoring
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "services", "endpoints"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
EOF
```

### Step 4: Bind the Role to the ServiceAccount

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: monitoring-pod-reader-binding
  namespace: monitoring
subjects:
- kind: ServiceAccount
  name: monitoring-sa
  namespace: monitoring
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

### Step 5: Test Permissions with `kubectl auth can-i`

```bash
# Test: Can monitoring-sa list pods? (Expected: yes)
kubectl auth can-i list pods \
  --as=system:serviceaccount:monitoring:monitoring-sa \
  -n monitoring
# Output: yes

# Test: Can monitoring-sa delete pods? (Expected: no)
kubectl auth can-i delete pods \
  --as=system:serviceaccount:monitoring:monitoring-sa \
  -n monitoring
# Output: no

# Test: Can monitoring-sa create deployments? (Expected: no)
kubectl auth can-i create deployments \
  --as=system:serviceaccount:monitoring:monitoring-sa \
  -n monitoring
# Output: no

# Test: Can monitoring-sa list pods in default namespace? (Expected: no)
kubectl auth can-i list pods \
  --as=system:serviceaccount:monitoring:monitoring-sa \
  -n default
# Output: no
```

### Step 6: Deploy a Test Pod Using the ServiceAccount

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: monitoring-pod
  namespace: monitoring
spec:
  serviceAccountName: monitoring-sa
  containers:
  - name: kubectl-container
    image: bitnami/kubectl:latest
    command: ["sleep", "3600"]
EOF
```

### Step 7: Exec Into the Pod and Verify API Access

```bash
kubectl exec -it monitoring-pod -n monitoring -- bash

# Inside the pod:
kubectl get pods -n monitoring
# Should succeed

kubectl delete pod monitoring-pod -n monitoring
# Error: pods "monitoring-pod" is forbidden: User "system:serviceaccount:monitoring:monitoring-sa"
# cannot delete resource "pods" in API group "" in the namespace "monitoring"
```

### Step 8: Test Security Context Enforcement

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: restricted-ns
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
---
apiVersion: v1
kind: Pod
metadata:
  name: root-pod
  namespace: restricted-ns
spec:
  containers:
  - name: nginx
    image: nginx:1.25
EOF
# This pod will be REJECTED because nginx runs as root by default
# Error: pods "root-pod" is forbidden: violates PodSecurity "restricted:latest"
```

### Step 9: Cleanup

```bash
kubectl delete namespace monitoring
kubectl delete namespace restricted-ns
```

---

## Commands Cheat Sheet

| Command | Description |
|---|---|
| `kubectl create serviceaccount <name> -n <ns>` | Create a ServiceAccount in a namespace |
| `kubectl create role <name> --verb=get,list --resource=pods -n <ns>` | Create a Role with specific verbs imperatively |
| `kubectl create rolebinding <name> --role=<role> --serviceaccount=<ns>:<sa> -n <ns>` | Bind a Role to a ServiceAccount |
| `kubectl create clusterrole <name> --verb=get,list --resource=nodes` | Create a ClusterRole for cluster-scoped resources |
| `kubectl create clusterrolebinding <name> --clusterrole=<cr> --serviceaccount=<ns>:<sa>` | Bind a ClusterRole cluster-wide |
| `kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa> -n <ns>` | Test permissions for a specific ServiceAccount |
| `kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa> -n <ns>` | List all permissions for a ServiceAccount in a namespace |
| `kubectl get roles,rolebindings -n <ns>` | List all Roles and RoleBindings in a namespace |
| `kubectl get clusterroles,clusterrolebindings` | List all ClusterRoles and ClusterRoleBindings |
| `kubectl describe role <name> -n <ns>` | Show detailed rules for a Role |
| `kubectl label namespace <ns> pod-security.kubernetes.io/enforce=restricted` | Apply Pod Security Standard to a namespace |
| `kube-bench run --targets master` | Run CIS benchmark scan on master node |

---

## Troubleshooting Guide

| Problem | Symptoms | Root Cause | Solution |
|---|---|---|---|
| Pod can't access K8s API | `forbidden` errors in pod logs; HTTP 403 from API server | Missing Role/RoleBinding or wrong ServiceAccount assigned | Verify SA with `kubectl get pod <pod> -o jsonpath='{.spec.serviceAccountName}'`; check RoleBinding subjects |
| `kubectl auth can-i` returns `no` unexpectedly | Permission denied for expected operations | Role doesn't include the required verb or resource; apiGroup mismatch | Check `kubectl describe role <role> -n <ns>` and ensure `apiGroups`, `resources`, and `verbs` are correct |
| Pod rejected by PodSecurity admission | `Error: pods "<name>" is forbidden: violates PodSecurity "restricted:latest"` | Pod spec doesn't meet the enforced Pod Security Standard | Add proper `securityContext` (runAsNonRoot, drop ALL capabilities, readOnlyRootFilesystem) |
| ServiceAccount token not mounted | No token file at `/var/run/secrets/kubernetes.io/serviceaccount/` | `automountServiceAccountToken: false` set on pod or SA | Set `automountServiceAccountToken: true` on the SA or pod spec if API access is needed |
| ClusterRoleBinding gives too much access | App SA has admin-level cluster access | Used ClusterRoleBinding with `cluster-admin` ClusterRole | Replace with a narrow Role + RoleBinding scoped to the app's namespace |
| RBAC changes not taking effect | Old permissions still active after updating Role | Kubernetes caches authorization decisions briefly; also check if multiple bindings exist | Wait a few seconds; verify with `kubectl auth can-i`; check for overlapping bindings |
| `kube-bench` shows FAIL on API server flags | CIS benchmark failures for authentication/authorization | API server started without recommended security flags | Edit API server manifest at `/etc/kubernetes/manifests/kube-apiserver.yaml` and add recommended flags |

---

## Real-World Scenario

### Scenario: Multi-Tenant SaaS Platform Security

**Company:** A fintech startup running a multi-tenant SaaS platform on EKS (AWS Kubernetes).

**Problem:** The platform had three teams (payments, analytics, frontend) sharing one cluster. A junior developer in the frontend team accidentally deleted a payments deployment during debugging, causing a 45-minute outage that affected transactions worth ₹2.3 crore.

**Root Cause Analysis:**
- All developers used the same kubeconfig with `cluster-admin` privileges.
- No namespace-level RBAC isolation existed.
- No Pod Security Standards were enforced.

**Solution Implemented:**
1. **Namespace Isolation** — Created dedicated namespaces: `payments`, `analytics`, `frontend`.
2. **Per-Team ServiceAccounts** — Each team got a ServiceAccount with access only to their namespace.
3. **Narrow Roles** — Frontend team got read-only access to their namespace. Payments team got full access to `payments` namespace only.
4. **Pod Security Standards** — Applied `restricted` PSS to `payments` namespace; `baseline` to others.
5. **Audit Logging** — Enabled Kubernetes audit logs to track who did what.
6. **kube-bench Scanning** — Ran weekly CIS scans to ensure compliance.

**Result:**
- Zero cross-team incidents in the following 8 months.
- Passed SOC 2 Type II audit partially due to RBAC controls.
- Developer onboarding became faster because permissions were self-documenting via Role definitions.

*यह real-world example बताता है कि RBAC सिर्फ exam topic नहीं है — यह production में पैसे बचाता है और incidents रोकता है। जैसे हर department का अपना lock और key system होना चाहिए, वैसे ही हर team का अपना namespace और Role होना चाहिए।*

---

## Interview Questions

### Q1: What is the difference between a Role and a ClusterRole?
**Answer:** A **Role** grants permissions within a single namespace (e.g., read pods in `dev` namespace). A **ClusterRole** grants permissions cluster-wide or on cluster-scoped resources like Nodes, PersistentVolumes, and Namespaces. ClusterRoles can also be reused across namespaces when bound with a RoleBinding.

### Q2: How does Kubernetes authentication work?
**Answer:** Kubernetes does not have a built-in user database. It relies on external identity providers through mechanisms like X.509 client certificates, Bearer tokens, OIDC tokens, and ServiceAccount tokens. The API server validates these credentials during the authentication phase. ServiceAccounts are the only identity type managed natively by Kubernetes.

### Q3: What happens if no RBAC policy matches a request?
**Answer:** The request is **denied by default**. RBAC in Kubernetes is deny-by-default — if no Role or ClusterRole explicitly grants the permission, the action is forbidden. There is no explicit "deny" rule in RBAC; you simply don't grant the permission.

### Q4: Explain the principle of least privilege in Kubernetes context.
**Answer:** It means granting a workload or user only the minimum permissions they need to function. In practice: create a dedicated ServiceAccount per app, define a narrow Role with specific verbs (get/list vs. wildcard *), bind it only to the required namespace, set `automountServiceAccountToken: false` on pods that don't need API access, and drop all Linux capabilities in the security context.

### Q5: What are Pod Security Standards and how do they replace PodSecurityPolicy?
**Answer:** Pod Security Standards (PSS) are three built-in security profiles — Privileged, Baseline, and Restricted — enforced by the PodSecurity admission controller. Unlike the deprecated PodSecurityPolicy (removed in K8s 1.25), PSS is simpler to configure via namespace labels and doesn't require creating custom policy objects. You can set enforcement modes (enforce, audit, warn) per namespace.

### Q6: How would you audit RBAC permissions in a production cluster?
**Answer:** Use `kubectl auth can-i --list --as=<user>` to check permissions, run `kubectl get rolebindings,clusterrolebindings -A` to list all bindings, review Kubernetes audit logs for unauthorized access attempts, use tools like `rakkess` or `kubectl-who-can` to visualize access matrices, and regularly run `kube-bench` for CIS compliance scanning.

### Q7: What is the security risk of using the `default` ServiceAccount?
**Answer:** The `default` SA exists in every namespace and is automatically assigned to pods that don't specify one. If any RoleBinding grants permissions to the `default` SA, every pod in that namespace inherits those permissions — violating least privilege. Best practice is to always create dedicated SAs and set `automountServiceAccountToken: false` on the default SA.

---

## Related Notes

- [[K8S-01 Architecture & Components]] — Understanding API server authentication flow
- [[K8S-02 Pods & Workloads]] — Pod spec and serviceAccountName field
- [[K8S-03 Networking]] — NetworkPolicy for network-level isolation
- [[K8S-04 Storage]] — PV access control with ClusterRoles
- [[K8S-05 ConfigMaps & Secrets]] — Secrets access restricted via RBAC
- [[K8S-07 Helm Package Manager]] — Helm Tiller (v2) security concerns and RBAC for Helm SA
- [[Docker-01 Foundations]] — Container runtime security basics
