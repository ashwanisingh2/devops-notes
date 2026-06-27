---
tags: [devops, gitops, flux, argocd]
aliases: [Flux vs ArgoCD, GitOps]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #cka
---

# MISC-01 GitOps Flux vs ArgoCD

> [!abstract] Overview
> GitOps is an operational framework that takes DevOps best practices used for application development, such as version control, collaboration, compliance, and CI/CD, and applies them to infrastructure automation. The core principle is that a Git repository acts as the single source of truth for the desired state of your entire system. This note explores GitOps, the difference between push and pull-based CD, and compares the two heavyweight GitOps tools in the Kubernetes ecosystem: Flux and ArgoCD.

## Concept Overview
In traditional CI/CD (Push-based), your CI tool (like Jenkins or GitHub Actions) runs a pipeline, builds an image, and then runs `kubectl apply` to push the changes into your Kubernetes cluster. The CI tool needs credentials to access the cluster.
In GitOps (Pull-based), an agent runs *inside* the Kubernetes cluster. It continuously monitors a Git repository. When a change is pushed to Git, the agent pulls the new configuration and applies it to the cluster, ensuring the actual state matches the desired state in Git.

*Hindi Explanation: Push-based mein aapka Jenkins bahar se Kubernetes ke andar ghus kar changes daalta hai (jiske liye usko cluster ki chabi chahiye). Pull-based (GitOps) mein, Kubernetes ke andar ek agent baitha hota hai jo continuously Git repo ko check karta hai. Jaise hi repo mein kuch change hota hai, woh agent usko cluster mein apply kar deta hai. Isme cluster ki chabi bahar nahi deni padti.*

**Key Concepts:**
- **Push-based CD:** External CI/CD system pushes changes to the destination.
- **Pull-based CD (GitOps):** Internal agent pulls changes from a source (Git).
- **ArgoCD:** A declarative, GitOps continuous delivery tool for Kubernetes, known for its excellent web UI and multi-cluster management capabilities.
- **Flux:** A set of continuous and progressive delivery solutions for Kubernetes, known for its modular architecture (GitOps Toolkit) and native Kubernetes feel.

**Desi Analogy:**
Think of **Push-based CD** as food delivery (Zomato/Swiggy). The delivery boy (Jenkins) needs the key or permission to enter your gated society (Kubernetes) to deliver the food (App).
Think of **Pull-based CD (GitOps)** as a society watchman (Flux/ArgoCD) who has a list (Git Repo) of what needs to come inside. The watchman periodically checks the gate, and if the items match the list, he brings them in himself. The society remains secure from outsiders.

## Technical Deep Dive

### 1. Push-based vs. Pull-based Deployments
**Push-based:**
- **Pros:** Easier to set up initially, familiar to most developers, pipeline can cover the entire end-to-end flow.
- **Cons:** Security risk (CI server needs cluster admin access). If someone manually changes a resource in the cluster via `kubectl`, the CI server doesn't know, leading to "configuration drift".
**Pull-based (GitOps):**
- **Pros:** Highly secure (cluster pulls from Git; no inbound firewall rules needed). Automatic drift reconciliation (if someone manual alters the cluster, the GitOps agent immediately reverts it back to what Git says).
- **Cons:** Steeper learning curve, requires dedicated tools like Flux or ArgoCD.

### 2. ArgoCD Architecture and Features
ArgoCD uses a centralized controller that continuously monitors running applications and compares their live state against the desired target state defined in a Git repository. 
- **User Interface:** ArgoCD shines with its beautiful, interactive Web UI that visualizes application health, sync status, and the hierarchy of Kubernetes resources.
- **Multi-cluster:** ArgoCD is typically installed in one management cluster and can deploy to dozens of other worker clusters.
- **Application CRD:** It uses an `Application` Custom Resource to map a Git path to a target cluster namespace.

### 3. Flux (v2) Architecture and Features
Flux is built on the GitOps Toolkit, a set of modular, specialized controllers (Source Controller, Kustomize Controller, Helm Controller).
- **Design Philosophy:** Flux feels much more like native Kubernetes. It doesn't rely heavily on a UI (though external UIs exist). You manage Flux entirely through Kubernetes manifests and Git.
- **Decentralized:** Instead of one massive controller, Flux separates the downloading of artifacts (Source Controller) from the applying of manifests (Kustomize/Helm Controller).
- **Image Automation:** Flux has native components to scan container registries, automatically update the Git repository with new image tags, and deploy them.

## Step-by-Step Lab
**Scenario:** We will bootstrap Flux into a Kubernetes cluster and link it to a GitHub repository. We will then deploy a simple application purely by committing a manifest to the Git repository.

**Step 1: Install the Flux CLI**
```bash
curl -s https://fluxcd.io/install.sh | sudo bash
```
*Expected output: Flux CLI installed. Verify with `flux --version`.*

**Step 2: Export your GitHub Personal Access Token**
You need a PAT with `repo` permissions to allow Flux to create a repository and deploy its own manifests.
```bash
export GITHUB_TOKEN="ghp_your_token_here"
export GITHUB_USER="your-github-username"
```
*Expected output: Variables exported silently.*

**Step 3: Bootstrap Flux**
This command installs the Flux controllers in your cluster, creates a new repo in GitHub, and configures the cluster to sync from that repo.
```bash
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=fleet-infra \
  --branch=main \
  --path=./clusters/my-cluster \
  --personal
```
*Expected output: Clones repo, applies CRDs, starts controllers, and confirms "all components are healthy".*

**Step 4: Clone the newly created repository**
```bash
git clone https://github.com/$GITHUB_USER/fleet-infra.git
cd fleet-infra
```
*Expected output: Repository cloned. You'll see a `clusters/my-cluster/flux-system` folder containing Flux's own configuration.*

**Step 5: Create a namespace manifest**
Let's add a custom application to our GitOps flow.
```bash
mkdir -p clusters/my-cluster/webapp
cat <<EOF > clusters/my-cluster/webapp/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: webapp-prod
EOF
```
*Expected output: File created.*

**Step 6: Commit and Push**
```bash
git add .
git commit -m "Add webapp-prod namespace"
git push origin main
```
*Expected output: Pushed to GitHub.*

**Step 7: Watch Flux sync the change**
Flux checks for changes every 1 minute by default. You can force it or just wait.
```bash
# Force sync
flux reconcile kustomization flux-system --with-source

# Verify the namespace was created
kubectl get ns webapp-prod
```
*Expected output: The namespace `webapp-prod` appears in the cluster, created entirely by GitOps!*

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
| :--- | :--- | :--- |
| `flux check --pre` | Verifies cluster meets Flux prerequisites | `flux check --pre` |
| `flux bootstrap github ...` | Installs Flux and links to GitHub | `flux bootstrap github --owner=user --repository=repo ...` |
| `flux get kustomizations` | Lists all Kustomizations and sync status | `flux get kustomizations` |
| `flux reconcile source git flux-system` | Forces Flux to immediately pull from Git | `flux reconcile source git flux-system` |
| `argocd app create ...` | Creates an ArgoCD application (imperative) | `argocd app create guestbook --repo https://... --path guestbook` |
| `argocd app sync <appname>` | Triggers an ArgoCD sync manually | `argocd app sync guestbook` |
| `argocd admin initial-password -n argocd`| Gets the default ArgoCD admin password | `argocd admin initial-password -n argocd` |
| `kubectl get applications -n argocd`| Lists ArgoCD apps via Kubernetes API | `kubectl get applications -n argocd` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| Flux bootstrap fails with 'Bad credentials' | The GITHUB_TOKEN is invalid or lacks 'repo' scope. | 1. Create a new Personal Access Token in GitHub. 2. Ensure 'repo' checkbox is ticked. 3. Re-export `GITHUB_TOKEN` and retry. |
| Manifest pushed to Git but not appearing in cluster. | Syntax error in YAML or path not covered by Flux Kustomization. | 1. Run `flux get kustomizations`. 2. If status is False, check `flux logs`. 3. Ensure the file is actually inside the directory path specified during bootstrap. |
| ArgoCD UI shows 'OutOfSync' | Someone modified a resource manually via kubectl. | 1. Click on the App in ArgoCD UI. 2. Click "Diff" to see what changed manually. 3. Click "Sync" to overwrite the manual change and restore Git state. |
| Git repository connection timeout. | Network policy blocking outbound traffic from Flux/ArgoCD pods. | 1. Check pod logs. 2. Ensure the namespace has outbound internet access (port 443) to reach github.com. |
| Helm chart fails to deploy via Flux. | HelmRepository source not configured or chart version mismatch. | 1. Run `flux get helmreleases`. 2. Check the Events. 3. Ensure the referenced `HelmRepository` CRD exists and is healthy. |

## Real-World Job Scenario
**The Situation:** During a critical production incident, a developer manually ran `kubectl edit deployment my-app` and changed the replica count from 3 to 10 to handle a traffic spike. The incident resolved, but they forgot to revert it or update the helm chart in Git.

**Without GitOps (Push-based):**
- The cluster is now drifted. The next time the CI pipeline runs (maybe a week later for a minor UI update), it overwrites the replica count back to 3, potentially causing an unexpected outage because traffic might still be high, or simply causing confusion about why the replicas dropped.

**With GitOps (Flux/ArgoCD):**
- **Action:** The developer edits the deployment via `kubectl`.
- **Result:** Within 1-3 minutes, Flux/ArgoCD detects that the live state (10 replicas) no longer matches the Git state (3 replicas).
- **Resolution:** The GitOps agent automatically reverts the deployment back to 3 replicas immediately. The developer quickly realizes they cannot bypass Git. To fix the issue properly, they must commit the change to `values.yaml` in the Git repo, ensuring the single source of truth is maintained.

## Interview Questions

**Q1: Explain the main security advantage of Pull-based GitOps over Push-based CI/CD.**
**A:** In Push-based CI/CD, the CI server (e.g., Jenkins) must hold the credentials/kubeconfig to access the production cluster. If Jenkins is compromised, the cluster is compromised. In Pull-based GitOps, the agent lives inside the cluster and only needs read access to a Git repository. There are no inbound firewall rules or external cluster credentials to manage, significantly reducing the attack surface.

**Q2: What is "Configuration Drift" and how does GitOps handle it?**
**A:** Configuration drift occurs when the actual state of the infrastructure (e.g., manual `kubectl` changes) diverges from the desired state defined in source code. GitOps tools like Flux and ArgoCD continuously monitor the cluster. If they detect drift, they automatically "reconcile" by overwriting the manual changes with the state defined in Git.

**Q3: Name one key architectural difference between Flux and ArgoCD.**
**A:** ArgoCD uses a centralized controller architecture and provides a very robust, feature-rich web UI for managing applications, making it great for multi-cluster management from a single pane of glass. Flux uses a decentralized, modular architecture based on the GitOps Toolkit (separate controllers for source, kustomize, helm) and is primarily driven via Git and Kubernetes CRDs without a built-in heavy UI.

**Q4: If the Git repository goes down (e.g., GitHub outage), what happens to the applications running in the cluster?**
**A:** Nothing happens to the running applications. The GitOps agent will simply fail to pull the latest changes and will log an error. The applications will continue to run in their last known good state. Once the Git repo is back online, the agent will resume syncing.

**Q5: How do you handle secrets in a GitOps workflow since you shouldn't store plain text secrets in Git?**
**A:** You use tools like Sealed Secrets (Bitnami) or External Secrets Operator (ESO). With Sealed Secrets, you encrypt the secret using a public key and store the `SealedSecret` custom resource in Git. The controller in the cluster uses the private key to decrypt it into a standard Kubernetes Secret. With ESO, you store a reference in Git, and the operator fetches the actual secret from AWS Secrets Manager or HashiCorp Vault.

## Related Notes
- [[Master Index]]
- [[K8S-05 Helm and Kustomize]]
- [[MISC-03 Infrastructure Testing]]
