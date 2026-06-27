---
tags: [devops, security, kubernetes, docker, container-security]
aliases: [Container & K8s Security]
created: 2025-06-27
status: #complete
difficulty: #advanced
cert-relevant: #cka #ckad
---

# SEC-04 Container and Kubernetes Security

> [!abstract] Overview
> Containers are not VMs. They share the same underlying Linux kernel as the host machine. If a hacker breaks out of a container running as root, they own the entire Kubernetes node. Securing Kubernetes requires a multi-layered approach: hardening the container image, locking down the Pod execution privileges, restricting network traffic, and enforcing cluster-wide security policies. Without these guardrails, Kubernetes is incredibly vulnerable by default.

---

## Concept Overview

- **What it is** — The application of security controls to the container runtime lifecycle and the Kubernetes orchestrator.
- **Why DevOps engineers use it** — To achieve "Defense in Depth." If application security (SAST) fails and a hacker executes remote code inside your container, runtime security (like read-only filesystems or dropped capabilities) ensures the hacker is trapped and cannot do any damage or spread to other pods.
- **Where you encounter this in a real job** — Writing PodSecurityContexts, configuring NetworkPolicies to isolate namespaces, implementing OPA Gatekeeper to ban privileged pods, or migrating to Rootless containers.
- **Responsibility Split:**
  - **Junior DevOps**: Ensures Dockerfiles use the `USER` instruction instead of running as root.
  - **Mid DevOps**: Configures Kubernetes `SecurityContext` for Deployments and applies basic NetworkPolicies.
  - **Senior/SRE**: Implements Admission Controllers (Kyverno/OPA), configures Seccomp/AppArmor profiles, and utilizes runtime threat detection tools like Falco.

*Seedha simple mein: Container ek kamre jaisa hai aur Kernel uski building ka foundation hai. Agar container ke andar root access mil gaya, toh hacker zameen khod kar foundation tak pahunch jayega. Humari job hai container ki zameen ko cement se block karna (dropping capabilities, read-only file system) taaki hacker kamre ke andar hi qaid rahe.*

---

## Technical Deep Dive

### 1. Image and Runtime Hardening (The Docker Layer)
- **Rootless Containers**: By default, the `root` user inside a container is the `root` user on the host OS. You must use the `USER` directive in the Dockerfile to run as a non-privileged user (e.g., `USER 1000`).
- **Read-Only Root Filesystem**: Hackers need to download malware or modify binaries to escalate privileges. If you mount the container filesystem as read-only (`readOnlyRootFilesystem: true`), they cannot write malware to disk. (App data must be written to explicit `/tmp` volumes).

### 2. Kubernetes Pod Security Standards (PSS)
Kubernetes deprecated PodSecurityPolicies (PSP) in favor of PSS, enforced via Namespace labels.
- **Privileged**: Open and entirely insecure. (Never use in production).
- **Baseline**: Prevents known privilege escalations, allows default capabilities. Good starting point.
- **Restricted**: Highly secure. Enforces running as non-root, dropping ALL capabilities, and requires Seccomp profiles.

### 3. Admission Controllers and Policy as Code
When a user runs `kubectl apply`, the API server intercepts the request before saving it to `etcd`.
Tools like **OPA Gatekeeper** or **Kyverno** act as Admission Controllers. They evaluate the YAML against security rules (e.g., "Does this YAML try to mount the host network?"). If the YAML violates the rule, the deployment is instantly rejected.

---

## Step-by-Step Lab (Hardening a Pod)

> [!warning] Pre-requisites
> - A running Kubernetes cluster
> - `kubectl` installed

### Step 1: The Insecure Pod (The Baseline)
This is how most developers write their YAML. It is dangerous.
```yaml
# insecure-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: insecure-app
spec:
  containers:
  - name: myapp
    image: nginx:latest
```

### Step 2: Applying the SecurityContext
We will harden this pod so even if compromised, the attacker is paralyzed.
```yaml
# secure-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
spec:
  # Pod-level security
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    fsGroup: 10001
    # Ensures a seccomp profile is applied, blocking dangerous system calls
    seccompProfile:
      type: RuntimeDefault

  containers:
  - name: myapp
    image: nginxinc/nginx-unprivileged:latest # Use an image designed for non-root
    
    # Container-level security
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
          - ALL # Drops all Linux root capabilities (like raw networking, chown)
          
    # Since the root filesystem is read-only, Nginx needs a place to write logs/temp files
    volumeMounts:
    - mountPath: /tmp
      name: tmp-volume
    - mountPath: /var/cache/nginx
      name: cache-volume
      
  volumes:
  - name: tmp-volume
    emptyDir: {}
  - name: cache-volume
    emptyDir: {}
```

### Step 3: Enforcing PSS via Namespace Labels
Instead of trusting developers to write secure YAML, force them at the namespace level.
```bash
# Label the default namespace to ENFORCE the 'restricted' standard
kubectl label namespace default pod-security.kubernetes.io/enforce=restricted

# Now try to apply the insecure pod from Step 1
kubectl apply -f insecure-pod.yaml

# Expected output:
# Error from server (Forbidden): error when creating "insecure-pod.yaml": 
# pods "insecure-app" is forbidden: violates PodSecurity "restricted": 
# allowPrivilegeEscalation != false, runAsNonRoot != true...
```

### Step 4: Network Isolation (NetworkPolicies)
By default, any pod in K8s can talk to any other pod. We must isolate them.
```yaml
# deny-all.yaml
# This policy drops ALL inbound traffic to the 'default' namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: default
spec:
  podSelector: {} # Selects ALL pods
  policyTypes:
  - Ingress
```
*After applying this, you must write explicit "Allow" rules for services that actually need to communicate (like Frontend to Backend).*

> [!tip] Pro Tip
> Never mount the `/var/run/docker.sock` file inside a container. Doing this gives the container full, unhindered root access to the host's Docker daemon. A hacker inside the container can use this socket to spin up a new container with the host's root filesystem mounted, completely taking over the underlying server.

---

## Common Commands Cheat Sheet

| Command / Tool | What It Does | Real Example |
|----------------|-------------|--------------|
| `kubectl auth can-i` | Checks your RBAC permissions | `kubectl auth can-i delete pods --as=johndoe` |
| `kube-bench` | Scans cluster against CIS security benchmarks | `kube-bench run --targets node` |
| `kube-score` | Static analysis of K8s YAML for security | `kube-score score deployment.yaml` |
| `kubectl create sa` | Creates a dedicated ServiceAccount | `kubectl create sa api-service-account` |
| `capsh --print` | Prints Linux capabilities of current shell | `docker run --rm alpine capsh --print` |
| `falco` | Runtime threat detection (e.g., shell spawned in pod) | (Runs as a DaemonSet in cluster) |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| Pod stuck in `CreateContainerError` | `runAsNonRoot: true` but image runs as root | The Dockerfile must use `USER <uid>`. If the image is built to run as root (like standard `nginx:latest`), Kubernetes will refuse to start it. Use an unprivileged image variant. |
| Application crashes with `Read-only file system` | `readOnlyRootFilesystem: true` enabled | The app is trying to write to disk (e.g., logs, caches, temp files). Find out where it writes, and mount an `emptyDir` volume to that specific path so it has a writable scratchpad. |
| Frontend Pod cannot reach Backend Pod | Default Deny NetworkPolicy | You implemented a default deny. You must create a new NetworkPolicy selecting the Backend Pod, allowing `Ingress` from the Frontend Pod based on its `podSelector` labels. |
| Pod requires elevated permissions to bind to Port 80 | Dropped `NET_BIND_SERVICE` capability | By default, Linux prevents non-root users from binding to ports below 1024. Change your application to listen on Port 8080 instead, and use a K8s Service to route Port 80 to 8080. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A massive crypto-mining botnet infects a company's Kubernetes cluster. The Security team finds that a hacker exploited a vulnerability in an Apache Struts container, gained root access, downloaded a crypto-miner, and ran it, maxing out the AWS EC2 bill."

**What Junior DevOps Does:**
Deletes the infected pod. The ReplicaSet immediately recreates it. The hacker exploits the new pod 5 minutes later and restarts the miner.

**Escalation Trigger:**
The cluster is fundamentally compromised, and deleting pods doesn't fix the architectural security flaws that allowed the lateral movement.

**Senior Engineer Resolution:**
1. Fixes the underlying application code vulnerability (the actual entry point).
2. Modifies the K8s Deployment `securityContext`:
   - Adds `readOnlyRootFilesystem: true`. Now, even if the hacker breaks in again, they cannot `wget` or save the crypto-mining malware to disk.
   - Drops all capabilities (`drop: - ALL`). The hacker cannot modify network rules or escalate privileges.
3. Implements **Falco** (a CNCF runtime security tool). Falco monitors Linux system calls.
4. Writes a Falco rule: "If any terminal shell (`/bin/bash` or `sh`) is spawned inside a container, trigger a PagerDuty alert immediately."
5. The cluster is now completely hardened against runtime exploitation.

**Lesson Learned:**
Assume your application *will* be breached. Container security is about minimizing the blast radius and preventing the attacker from turning a compromised app into a compromised cluster.

---

## Interview Questions

**Q1 (Conceptual):** What is the difference between Authentication (AuthN) and Authorization (AuthZ) in Kubernetes?
**A:** Authentication (AuthN) determines *who* is making the request (e.g., verifying a user's X.509 certificate or OIDC token). Authorization (AuthZ) determines *what* that verified user is allowed to do. In Kubernetes, AuthZ is handled by RBAC (Role-Based Access Control) using Roles and RoleBindings to explicitly grant permissions (e.g., "John is allowed to delete pods in the dev namespace").

**Q2 (Practical):** You want to ensure that no developer can deploy a container using the `latest` tag, because it causes unpredictable production issues. How do you enforce this across the entire Kubernetes cluster?
**A:** I would use an Admission Controller, such as OPA Gatekeeper or Kyverno. I would write a policy-as-code rule that intercepts every `Pod` or `Deployment` creation request. The rule checks the `image` string. If it ends in `:latest` or has no tag at all, the Admission Controller will instantly reject the API request, returning a custom error message to the developer.

**Q3 (Scenario-based):** A developer requests that their Pod be granted `privileged: true` because their application "needs it to run properly." Why is this a massive red flag, and what should you do?
**A:** `privileged: true` effectively disables all container isolation. It gives the container almost the exact same access to the host node as a process running directly on the host as root, allowing them to format drives, alter network stacks, and reboot the node. I would deny the request and work with the developer to identify the exact Linux capability they need (e.g., `NET_ADMIN`), and grant *only* that specific capability via `cap_add`, following the Principle of Least Privilege.

**Q4 (Deep dive):** Explain how NetworkPolicies work in Kubernetes and what component is responsible for enforcing them.
**A:** NetworkPolicies act as a Layer 3/4 firewall for pods. They use pod labels and namespaces to define rules for Ingress (incoming) and Egress (outgoing) traffic. Crucially, Kubernetes itself does *not* enforce NetworkPolicies; they are just API objects. You must install a CNI (Container Network Interface) plugin that supports NetworkPolicies (like Calico or Cilium) to actually enforce the rules via IPtables or eBPF in the Linux kernel. If you use Flannel, your NetworkPolicies will be completely ignored.

**Q5 (Trick/Gotcha):** If you create a K8s `RoleBinding` granting a user Admin rights in the `dev` namespace, can that user read cluster-wide resources like `Nodes` or `PersistentVolumes`?
**A:** No. `Nodes` and `PersistentVolumes` are non-namespaced, cluster-scoped resources. A standard `RoleBinding` only grants access within a specific namespace. To grant access to cluster-scoped resources, you must use a `ClusterRole` and a `ClusterRoleBinding`.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[04-Orchestration/K8S-06 RBAC and Security|K8s RBAC Fundamentals]]
[[09-Security-DevSecOps/SEC-01 DevSecOps Fundamentals|DevSecOps Fundamentals]]
