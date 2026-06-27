---
tags: [devops, kubernetes, operators]
aliases: [K8S Operators]
created: 2025-06-27
status: #complete
difficulty: #advanced
cert-relevant: #ckad
---
# Kubernetes Operators and CRDs

> [!abstract]
> This note covers how to extend Kubernetes capabilities using Custom Resource Definitions (CRDs) and the Operator pattern. We will explore how Operators act as automated software managers inside the cluster, replacing manual human intervention for complex stateful applications. We will look at practical examples like the Prometheus Operator and cert-manager.

## Concept Overview

Kubernetes natively understands resources like Pods, Services, and Deployments. But what if you want Kubernetes to understand a "Database" or a "TLSCertificate"?
- **CRDs (Custom Resource Definitions):** Extensions of the Kubernetes API. They allow you to define your own custom objects. K8s will store and serve these objects just like built-in ones.
- **Controllers:** A background process that watches the state of resources and works to move the *current* state to the *desired* state (the Reconciliation Loop).
- **Operators:** An Operator is a custom K8s Controller combined with a CRD. It encodes the operational domain knowledge of a human administrator into software. It knows how to deploy, backup, upgrade, and heal a specific complex application (like a database cluster).

*Hindi translation & analogy:* *CRDs naye nouns hain (jaise "Database") aur Operators verbs hain (jaise "Database ko scale karo"). Socho Kubernetes ek smart manager hai jise sirf basic cheezein (Pods, Deployments) aati hain. Agar aapko us manager se ek complex factory (PostgreSQL database) chalwani hai, toh aapko ek specialist (Operator) hire karna padega. Ye specialist hamesha check karta rehta hai (Reconciliation loop) ki factory waisi hi chal rahi hai jaisa aapne pucha tha, aur agar kuch kharab ho, toh khud fix karta hai.*

## Technical Deep Dive

### 1. The Reconciliation Loop
The core of Kubernetes and Operators is the reconciliation loop. It constantly executes: `Observe -> Diff -> Act`. The Operator *observes* the cluster state via K8s API watch events. It calculates the *diff* between the current state and the desired state defined in the Custom Resource. Finally, it *acts* (creates pods, configures configs, takes backups) to eliminate that diff. This declarative approach ensures self-healing.

### 2. Operators vs Helm
Helm is a package manager (like `apt` or `yum`); it templates and deploys YAML files once. If the application breaks or needs a complex stateful upgrade, Helm cannot help. Operators are continuously running. They handle "Day 2" operations. For example, a Prometheus Operator doesn't just install Prometheus; if you create a `ServiceMonitor` CRD, the Operator dynamically updates Prometheus's configuration to scrape a new target without restarting it.

### 3. Practical Implementations: cert-manager
`cert-manager` is the most popular Operator in K8s. It introduces CRDs like `Issuer`, `ClusterIssuer`, and `Certificate`. Instead of a human manually generating CSRs and renewing TLS certificates via Let's Encrypt, the human simply creates a `Certificate` CRD. The cert-manager Operator watches for this, communicates with Let's Encrypt to validate the domain (HTTP01 or DNS01 challenges), fetches the TLS cert, and stores it in a K8s `Secret` for Ingress controllers to use. It also automatically renews the cert 30 days before expiration.

## Step-by-Step Lab

**Scenario:** Install the `cert-manager` Operator using Helm, create a self-signed `ClusterIssuer`, and generate a custom `Certificate` resource.

1. **Add the Jetstack Helm Repository**
   ```bash
   helm repo add jetstack https://charts.jetstack.io
   helm repo update
   ```
2. **Install cert-manager with CRDs**
   ```bash
   helm install cert-manager jetstack/cert-manager \
     --namespace cert-manager \
     --create-namespace \
     --set installCRDs=true
   ```
3. **Verify the Operator and CRDs**
   ```bash
   kubectl get pods -n cert-manager
   kubectl get crds | grep cert-manager
   # You should see certificates.cert-manager.io, issuers, etc.
   ```
4. **Create a Self-Signed ClusterIssuer (CRD Instance)**
   Create `issuer.yaml`:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: selfsigned-issuer
   spec:
     selfSigned: {}
   ```
   ```bash
   kubectl apply -f issuer.yaml
   ```
5. **Request a TLS Certificate (CRD Instance)**
   Create `certificate.yaml`:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: Certificate
   metadata:
     name: my-app-cert
     namespace: default
   spec:
     secretName: my-app-tls-secret
     duration: 2160h # 90d
     renewBefore: 360h # 15d
     subject:
       organizations:
         - devops-corp
     isCA: false
     privateKey:
       algorithm: RSA
       encoding: PKCS1
       size: 2048
     dnsNames:
       - myapp.local
     issuerRef:
       name: selfsigned-issuer
       kind: ClusterIssuer
       group: cert-manager.io
   ```
   ```bash
   kubectl apply -f certificate.yaml
   ```
6. **Verify the generated TLS Secret**
   ```bash
   kubectl get certificate my-app-cert
   # Status should be Ready: True
   kubectl get secret my-app-tls-secret -o yaml
   ```

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
| :--- | :--- | :--- |
| `kubectl get crds` | Lists all Custom Resource Definitions | `kubectl get crds \| grep prometheus` |
| `kubectl explain crd_name` | Shows the schema/docs for a CRD | `kubectl explain certificate.spec` |
| `helm install --set installCRDs=true` | Installs an Operator and its CRDs | `helm install cert-manager jetstack/cert-manager --set installCRDs=true` |
| `kubectl describe certificate` | Troubleshoots cert-manager certs | `kubectl describe certificate my-app-cert` |
| `kubectl logs -f deployment/operator` | Views Operator reconciliation logs | `kubectl logs -f deploy/cert-manager -n cert-manager` |
| `kubectl get events` | Shows cluster events including Operator actions | `kubectl get events -n cert-manager --sort-by='.metadata.creationTimestamp'` |
| `operator-sdk create api` | Scaffolds a new Operator project | `operator-sdk create api --group db --version v1 --kind MySQL` |
| `kubectl api-resources` | Lists all resources, K8s native and CRDs | `kubectl api-resources` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| **`error: the server doesn't have a resource type...`** | The CRD is not installed in the cluster. | 1. Ensure the Operator is installed. 2. Verify CRDs: `kubectl get crds`. 3. Re-install Operator with CRD flag enabled. |
| **CRD object created, but nothing happens** | The Operator controller pod is crashed or not running. | 1. Check Operator pods: `kubectl get pods -n <operator-namespace>`. 2. View logs: `kubectl logs deploy/<operator>`. |
| **cert-manager Certificate stuck in 'False' Ready state** | Issue with the Issuer configuration or DNS challenge failing. | 1. `kubectl describe certificate <name>`. 2. Check `Order` and `Challenge` objects. 3. Verify DNS records if using DNS01. |
| **Cannot delete a custom resource (hangs indefinitely)** | A Finalizer on the resource is blocking deletion, but the Operator is dead and cannot remove it. | 1. Edit the resource: `kubectl edit <crd-type> <name>`. 2. Find the `finalizers:` array under metadata. 3. Delete the finalizers section and save. |
| **Operator consumes too much CPU/Memory** | Operator is reconciling too frequently or watching too many namespaces. | 1. Review Operator configuration to restrict it to specific namespaces (Role vs ClusterRole). 2. Increase pod resource limits. |

## Real-World Job Scenario

**Scenario:** The company needs to deploy a highly available PostgreSQL cluster on Kubernetes. They need automated backups to S3, automatic failover if the primary node dies, and seamless version upgrades.

**Junior DevOps Action:** Uses a basic Helm chart to deploy PostgreSQL StatefulSets. Writes custom cronjobs for backups. When a node dies, they manually SSH or `kubectl exec` to promote a read-replica to primary.
**Senior DevOps Action:** Deploys a PostgreSQL Operator (like CrunchyData or Zalando). Creates a simple `PostgresCluster` Custom Resource YAML defining the desired state (3 instances, S3 backup bucket). The Operator handles the complex bootstrapping, configures streaming replication, automatically handles failovers in seconds, and manages Point-In-Time-Recovery (PITR) backups without human intervention.

## Interview Questions

**Q1: What is a Custom Resource Definition (CRD)?**
A1: A CRD is a way to extend the Kubernetes API. It allows you to define custom objects that Kubernetes will store in etcd and expose via its REST API, functioning exactly like native objects (Pods, Deployments) but tailored to your specific application domain.

**Q2: Explain the Operator Pattern in Kubernetes.**
A2: The Operator pattern combines CRDs and custom Controllers. It encodes human operational knowledge into software. The Operator constantly watches the state of custom resources and uses the Kubernetes API to manage complex, stateful applications (like databases or monitoring stacks) throughout their lifecycle (Day 2 operations).

**Q3: How does Helm differ from a Kubernetes Operator?**
A3: Helm is a package manager that templates and deploys manifests (Day 1 operations). Once deployed, Helm's job is largely done. An Operator is a continuously running process that actively manages and heals the application (Day 2 operations), handling tasks like backups, scaling, and automated upgrades that simple YAML templates cannot do.

**Q4: Describe the reconciliation loop.**
A4: The reconciliation loop is a continuous process run by controllers: Observe, Diff, Act. It observes the current state of the cluster, compares it against the desired state defined in the API (the diff), and acts to make the current state match the desired state, ensuring self-healing.

**Q5: What is the purpose of `cert-manager` in Kubernetes?**
A5: `cert-manager` is an Operator that automates the management and issuance of TLS certificates from various issuing sources (like Let's Encrypt or HashiCorp Vault). It ensures certificates are valid and up to date, automatically attempting to renew certificates at a configured time before expiration.

## Related Notes
- [[Master Index]]
- [[04-Orchestration/K8S-01 Kubernetes Architecture]]
- [[04-Orchestration/K8S-05 Helm Package Manager]]
