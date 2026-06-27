---
tags: [devops, cicd, gitops, kubernetes, argocd]
aliases: [ArgoCD & GitOps]
created: 2025-06-27
status: #complete
difficulty: #advanced
cert-relevant: #cka
---

# CICD-05 ArgoCD and GitOps

> [!abstract] Overview
> Traditional CI/CD tools (like Jenkins) use a "Push" model to deploy to Kubernetes: the pipeline finishes building an image, authenticates to the K8s cluster, and pushes the new YAML. This violates security (giving Jenkins cluster admin rights) and breaks the single source of truth (someone can manually run `kubectl edit` and the pipeline won't know). GitOps solves this by using a "Pull" model. ArgoCD sits *inside* the K8s cluster, watches a Git repository, and continuously pulls changes to ensure the cluster state perfectly matches the Git state.

---

## Concept Overview

- **What it is** — **GitOps** is an operational framework that takes DevOps best practices used for application development (version control, compliance, CI/CD) and applies them to infrastructure automation. **ArgoCD** is a declarative, GitOps continuous delivery tool for Kubernetes.
- **Why DevOps engineers use it** — For automated reconciliation and disaster recovery. If a developer accidentally deletes a production deployment using `kubectl delete`, ArgoCD detects the K8s state no longer matches Git, and automatically recreates it in seconds. 
- **Where you encounter this in a real job** — Managing 50 microservices across Dev, Staging, and Prod clusters. Instead of complex Jenkins pipelines, you just merge a PR changing the `image: tag` in Git, and ArgoCD automatically syncs it to K8s.
- **Responsibility Split:**
  - **Junior DevOps**: Monitors the ArgoCD UI for "OutOfSync" applications and investigates sync failures.
  - **Mid DevOps**: Writes Kustomize or Helm charts, creates ArgoCD `Application` CRDs to deploy them, and manages Secrets integration.
  - **Senior/SRE**: Architects the "App-of-Apps" pattern, implements Argo Rollouts for Canary deployments, and locks down ArgoCD RBAC via Single Sign-On (SSO).

*Seedha simple mein: GitOps ka matlab hai "Jo Git mein likha hai, wahi sach hai". Jenkins bahar se aake cluster ko order deta tha. ArgoCD cluster ke andar baitha ek watchman hai. Wo har 3 minute mein Git check karta hai. Agar Git aur Cluster alag dikhe, toh wo Cluster ko wapas Git jaisa bana deta hai.*

---

## Technical Deep Dive

### 1. The Pull Model vs. Push Model
- **Push (Jenkins/GitHub Actions)**: CI builds the image -> CI runs `kubectl apply`. The CI server needs powerful credentials to access the K8s API. If Jenkins is hacked, your cluster is hacked.
- **Pull (ArgoCD)**: CI builds the image -> CI updates a Git repo -> Done. ArgoCD, running *inside* K8s, notices the Git repo changed. It reaches out, pulls the YAML, and applies it locally. Your K8s cluster API is never exposed to the outside world.

### 2. ArgoCD Architecture and Sync Policies
ArgoCD uses Custom Resource Definitions (CRDs). You define an `Application` resource specifying a Source (Git repo URL + path) and a Destination (K8s cluster URL + namespace).
- **Manual Sync**: ArgoCD shows the app as "OutOfSync" in the UI. A human must click "Sync".
- **Auto Sync**: ArgoCD automatically applies changes.
- **Self-Heal**: If enabled, if someone manually modifies resources directly via `kubectl`, ArgoCD immediately overwrites their changes to match Git, enforcing immutability.
- **Prune**: If enabled, if you delete a YAML file from Git, ArgoCD will delete the corresponding resource from Kubernetes.

### 3. App-of-Apps Pattern
Managing hundreds of `Application` CRDs manually is a nightmare. The App-of-Apps pattern solves this. You create *one* master ArgoCD Application that points to a Git folder containing the YAMLs of *other* ArgoCD Applications. When you want to onboard a new microservice, you simply commit its `Application.yaml` to that folder, and ArgoCD recursively discovers and deploys the entire stack automatically.

---

## Step-by-Step Lab

> [!warning] Pre-requisites
> - A running K8s cluster (minikube/kind)
> - `kubectl` configured

### Step 1: Install ArgoCD in your Cluster
```bash
# Create namespace
kubectl create namespace argocd

# Apply the official ArgoCD installation manifests
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Expected output:
# Dozens of CustomResourceDefinitions, Deployments, and Services created.
```

### Step 2: Access the UI
```bash
# Forward the ArgoCD UI port to your local machine
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get the auto-generated admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# Open https://localhost:8080 in browser, login with 'admin' and the password.
```

### Step 3: Create an ArgoCD Application via CLI/YAML
```yaml
# Create an application pointing to a public sample repo
cat << 'EOF' > my-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

kubectl apply -f my-app.yaml
```

### Step 4: Verify the Deployment and Test Self-Healing
```bash
# ArgoCD will instantly deploy the app. Verify it:
kubectl get pods -n default

# Let's test GitOps Self-Healing! Delete the deployment manually.
kubectl delete deployment guestbook-ui

# Immediately run get pods again
kubectl get pods -n default

# Expected output:
# The pods are already spinning back up! ArgoCD saw the manual deletion,
# noticed it violated the Git state, and instantly recreated the deployment.
```

> [!tip] Pro Tip
> Never put your source code and your Kubernetes manifests in the same repository if you are using auto-sync. If you do, the CI pipeline building the image will commit the new image tag back to the same repo, triggering *another* CI build, creating an infinite loop. Always use a separate "App-Config" repository for GitOps.

---

## Common Commands Cheat Sheet
*(Usually done via UI, but CLI is useful for automation)*

| Command | What It Does | Real Example |
|---------|-------------|--------------|
| `argocd login` | Authenticates CLI to ArgoCD server | `argocd login localhost:8080` |
| `argocd app create` | Creates a new application | `argocd app create my-app --repo <url> --path <path> --dest-server <server> --dest-namespace <ns>` |
| `argocd app sync` | Manually triggers a sync | `argocd app sync guestbook` |
| `argocd app list` | Lists all applications and their status | `argocd app list` |
| `argocd app history`| Shows deployment history | `argocd app history guestbook` |
| `argocd app rollback`| Rolls back to a previous Git commit state | `argocd app rollback guestbook 1` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| App shows as `OutOfSync` but never updates | Auto-sync is disabled | By default, ArgoCD only detects drift. You must edit the App and enable `syncPolicy.automated` for it to apply changes automatically. |
| Sync Fails with `Forbidden` error | ArgoCD ServiceAccount lacks RBAC | ArgoCD needs K8s permissions to create resources. Ensure it has the correct ClusterRole assigned to manage resources in the target namespace. |
| Private Git repo cannot be fetched | Missing repository credentials | Go to Settings -> Repositories in the UI and add the SSH Key or HTTPS Token for your private GitHub repository. |
| Infinite sync loop | Templating mismatch | If your Helm chart generates random labels on every render, ArgoCD thinks it's constantly drifted. Remove random generation in K8s manifests. |
| App stuck in `Progressing` | Deployment is failing to start | The K8s deployment is likely crashing (e.g., ImagePullBackOff). ArgoCD waits for K8s to report the object as 'Healthy'. Debug the K8s pod logs. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A senior engineer left the company. The next day, the website goes down. Someone logs in and finds the entire Production namespace is gone. No one knows what the exact replica counts or resource limits were."

**What Junior DevOps Does:**
Panics. Starts digging through Slack history and old Jira tickets trying to piece together the YAML files to rebuild the deployment manually via `kubectl apply`. It takes 6 hours to restore service.

**Escalation Trigger:**
The CEO demands an explanation for the 6-hour outage and a guarantee it will never happen again.

**Senior Engineer Resolution:**
1. Implements ArgoCD and strict GitOps.
2. All K8s YAMLs are stored in a locked GitHub repository. No human is granted write access to the Production K8s cluster anymore.
3. Fast forward: Someone accidentally deletes the namespace again (or the cluster burns down).
4. The Senior spins up a fresh K8s cluster, installs ArgoCD, and points it at the GitHub repo.
5. Within 5 minutes, ArgoCD rebuilds the entire production environment with 100% accuracy, exactly as it was defined in Git.

**Lesson Learned:**
GitOps transforms your infrastructure into disposable compute. If the state is stored securely in Git, recovering a cluster takes minutes, not hours.

---

## Interview Questions

**Q1 (Conceptual):** What is the core difference between Jenkins deploying to Kubernetes and ArgoCD deploying to Kubernetes?
**A:** Jenkins uses a "Push" model, meaning the CI server pushes changes directly to the K8s API, requiring external secrets and breaking the Git single-source-of-truth. ArgoCD uses a "Pull" model, running continuously inside the cluster, watching Git, and pulling changes inwards, which is vastly more secure and robust.

**Q2 (Practical):** Your developers want the staging environment to update automatically when code is merged, but they want production to require a human click. How do you configure this in ArgoCD?
**A:** I would configure the Staging `Application` CRD with `syncPolicy.automated` enabled, so it auto-syncs on Git changes. I would configure the Production `Application` CRD with NO automated sync policy. It will detect the drift (show OutOfSync), but a human must log into the ArgoCD UI (or run the CLI) to explicitly click the "Sync" button for production.

**Q3 (Scenario-based):** A rogue developer manually runs `kubectl scale deployment myapp --replicas=100` on a cluster managed by ArgoCD with Self-Heal enabled. What exactly happens?
**A:** ArgoCD constantly polls the cluster state against the Git state. It will immediately notice that the cluster has 100 replicas, but the Git repository says 3 replicas. Because `selfHeal` is enabled, ArgoCD will ruthlessly overwrite the manual change, immediately scaling the deployment back down to 3 to match Git.

**Q4 (Deep dive):** How do you handle K8s Secrets in a GitOps workflow since you cannot commit plain-text passwords to Git?
**A:** You cannot use native K8s Secrets in raw Git. The industry standard is to use tools like **Sealed Secrets** (Bitnami) or the **External Secrets Operator**. With Sealed Secrets, you encrypt the secret using a public key, commit the encrypted YAML to Git, and ArgoCD applies it. The controller inside the cluster decrypts it. With ESO, you commit a reference YAML to Git, and the cluster fetches the real secret from AWS/Vault.

**Q5 (Trick/Gotcha):** Should your CI pipeline (running unit tests and building Docker images) be migrated into ArgoCD?
**A:** No. ArgoCD is specifically a Continuous Delivery (CD) tool focused on Kubernetes manifest synchronization. It does not compile code, run unit tests, or build Docker images. You still need a CI tool (like GitHub Actions or GitLab CI) to build the image, push it to a registry, and update the image tag in the Git repository. ArgoCD takes over from that point.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[05-CI-CD/CICD-01 CI-CD Concepts|CI/CD Concepts]]
[[04-Orchestration/K8S-07 Helm Package Manager|Helm (often deployed via ArgoCD)]]
