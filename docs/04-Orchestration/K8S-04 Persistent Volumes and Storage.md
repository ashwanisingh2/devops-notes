---
tags:
  - devops
  - kubernetes
  - storage
aliases:
  - K8s Storage
created: 2025-06-27
status: "#complete"
difficulty: "#intermediate"
cert-relevant: "#cka"
---

# Persistent Volumes and Storage in Kubernetes

> [!abstract] Overview
> Containers are ephemeral by design — when a pod dies, everything inside it vanishes like it never existed. This is a catastrophic problem for databases, file uploads, and any application that needs to remember state across restarts. Kubernetes solves this through its **Persistent Volume (PV)** subsystem, which decouples storage lifecycle from pod lifecycle. This note covers the complete storage stack: PersistentVolumes, PersistentVolumeClaims, StorageClasses, access modes, reclaim policies, static vs dynamic provisioning, and when to choose StatefulSets over Deployments. You will deploy a production-style PostgreSQL StatefulSet and verify that your data survives pod deletion.
>
> *Containers ephemeral hote hain — jab pod marta hai, uske andar ka sab kuch gayab ho jaata hai. Ye databases ke liye bahut bada problem hai. Kubernetes ne is problem ko PV (Persistent Volume) system se solve kiya hai, jisme storage ki life pod ki life se alag hoti hai. Is note mein hum poora storage stack cover karenge aur ek PostgreSQL StatefulSet deploy karke data persistence verify karenge.*

---

## Concept Overview

### The Storage Problem in Containers

By default, a container's filesystem is a **writable layer** on top of the image's read-only layers. When the container restarts, this writable layer is destroyed and recreated from scratch. Consider a MySQL container — every table, every row, every transaction is gone on restart.

*Samjho aise — container ek whiteboard jaisa hai. Tum uspe likho, magar jaise hi koi board saaf kare (pod restart), sab mit jaata hai. Database ke liye toh ye bilkul chalega nahi — tumhe ek permanent notebook chahiye jisme data safe rahe.*

Docker partially solved this with **volumes** and **bind mounts**, but in a multi-node Kubernetes cluster, storage needs to be:

- **Portable** — usable across nodes
- **Provisioned** — automatically or manually
- **Protected** — with proper access controls and lifecycle policies

This is where Kubernetes' PV/PVC/StorageClass architecture comes in.

### PV / PVC / StorageClass — The Hotel Room Analogy 🏨

Think of Kubernetes storage like a hotel booking system:

| Storage Concept | Hotel Analogy | Description |
|---|---|---|
| **PersistentVolume (PV)** | Hotel Room | The actual physical storage resource (NFS share, AWS EBS disk, local SSD). Created by the admin or dynamically by the system. |
| **PersistentVolumeClaim (PVC)** | Room Booking | A user's request for storage — "I need 10Gi with ReadWriteOnce access." The cluster matches this claim to an available PV. |
| **StorageClass** | Room Category (Deluxe/Suite) | Defines *how* storage is provisioned — which provisioner, what parameters, what reclaim policy. Enables dynamic provisioning. |

*PV matlab hotel ka kamra — already bana hua hai. PVC matlab booking — "mujhe ek 10GB wala kamra chahiye." StorageClass matlab room category — Deluxe mein fast SSD milega, Standard mein HDD. Jab tum booking karte ho (PVC), hotel (Kubernetes) tumhe available kamra (PV) de deta hai.*

The flow works like this:

```
Admin creates StorageClass → User creates PVC → Kubernetes dynamically provisions PV → Pod mounts PVC
```

Or in static provisioning:

```
Admin creates PV manually → User creates PVC → Kubernetes binds PVC to matching PV → Pod mounts PVC
```

### Access Modes — Who Can Read/Write

Access modes define how a volume can be mounted across nodes:

| Mode | Short | Description | Use Case |
|---|---|---|---|
| **ReadWriteOnce** | RWO | Single node read-write | Databases (PostgreSQL, MySQL) — only one node writes |
| **ReadOnlyMany** | ROX | Many nodes read-only | Shared config files, static assets served by multiple pods |
| **ReadWriteMany** | RWX | Many nodes read-write | Shared upload directories, CMS media folders (NFS/CephFS) |
| **ReadWriteOncePod** | RWOP | Single pod read-write (K8s 1.27+) | Strict single-writer guarantee for critical data |

*RWO matlab ek kamre mein ek hi insaan reh sakta hai (database server). ROX matlab bahut log dekh sakte hain par koi change nahi kar sakta (museum). RWX matlab shared office — sab log likh bhi sakte hain padh bhi sakte hain. RWOP matlab private locker — sirf ek pod use kar sakta hai.*

> [!warning] Cloud Provider Support
> Not all storage backends support all access modes. AWS EBS only supports RWO. For RWX, you need NFS, CephFS, or AWS EFS.

### Reclaim Policies — What Happens When PVC is Deleted

When a PVC is deleted, the bound PV's reclaim policy decides the fate of the data:

| Policy | Behavior | When to Use |
|---|---|---|
| **Retain** | PV and data preserved. Admin must manually clean up and re-provision. | Production databases — you never want automatic deletion. |
| **Delete** | PV and underlying storage (e.g., EBS volume) are deleted automatically. | Dev/test environments where data is disposable. |
| **Recycle** | Data is wiped (`rm -rf /thevolume/*`) and PV is made available again. **Deprecated** — use dynamic provisioning instead. | Legacy setups only. |

*Retain matlab checkout ke baad hotel kamra lock ho jaata hai — manager khud aake saaf karega. Delete matlab kamra aur uska saamaan sab hata diya jaata hai. Recycle matlab kamra saaf karke dubara available — par ye ab outdated ho gaya hai.*

> [!important] CKA Exam Tip
> The default reclaim policy for dynamically provisioned PVs is **Delete**. For production, always set it to **Retain** in your StorageClass.

### Static vs Dynamic Provisioning

**Static Provisioning:** Admin manually creates PVs with specific sizes and access modes. Users create PVCs that bind to these pre-created PVs. This is like pre-building hotel rooms before guests arrive.

```yaml
# Static PV Example
apiVersion: v1
kind: PersistentVolume
metadata:
  name: manual-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /mnt/data
```

**Dynamic Provisioning:** Admin creates a StorageClass. When a PVC references that StorageClass, Kubernetes automatically creates a PV using the configured provisioner. This is like a hotel that builds rooms on-demand based on bookings.

```yaml
# StorageClass for Dynamic Provisioning
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: k8s.io/minikube-hostpath
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
```

*Static provisioning matlab admin pehle se kamre bana ke rakhta hai — PV manually create karo. Dynamic provisioning matlab jaise hi booking aaye (PVC), system automatically kamra bana deta hai (PV create). Production mein mostly dynamic provisioning use hoti hai kyunki manual PV banana scalable nahi hai.*

### StatefulSets vs Deployments — When State Matters

| Feature | Deployment | StatefulSet |
|---|---|---|
| Pod Identity | Random names (`app-7d9f8b-x4k2`) | Stable ordinal names (`db-0`, `db-1`, `db-2`) |
| Storage | All pods share one PVC (or each gets ephemeral) | Each pod gets its own PVC via `volumeClaimTemplates` |
| Scaling | Parallel creation/deletion | Ordered — `db-0` → `db-1` → `db-2` |
| Network | Random IP, shared Service | Stable DNS via **Headless Service** (`db-0.db-svc.ns.svc.cluster.local`) |
| Use Case | Stateless apps (web servers, APIs) | Databases, Kafka, ZooKeeper, Elasticsearch |

**Headless Service** — A Service with `clusterIP: None` that doesn't load-balance but gives each pod its own DNS record. StatefulSets require a headless service for stable network identity.

*StatefulSet samjho aise — ek school mein har bachche ka roll number fixed hota hai (db-0, db-1). Agar ek bachcha absent ho (pod restart), toh uska roll number nahi badalta. Deployment mein roll number random hota hai — har baar naya mil sakta hai. Database jaise kaam ke liye fixed identity zaroori hai isliye StatefulSet use karte hain.*

> [!tip] Key Rule of Thumb
> If your application needs **stable storage**, **stable network identity**, or **ordered deployment**, use a StatefulSet. For everything else, use a Deployment.

---

## Technical Deep Dive

### PV Lifecycle States

A PersistentVolume transitions through these phases:

```
Available → Bound → Released → (Failed)
    ↓          ↓        ↓
  No PVC    PVC bound  PVC deleted,
  bound     to this PV  PV retained
```

- **Available** — PV is free and ready to be claimed.
- **Bound** — PV is bound to a PVC. One-to-one mapping.
- **Released** — PVC deleted, but PV still has data. Cannot be rebound until admin cleans it.
- **Failed** — Automatic reclamation failed.

### Volume Binding Modes

StorageClass supports two `volumeBindingMode` values:

- **Immediate** — PV is provisioned as soon as PVC is created (default).
- **WaitForFirstConsumer** — PV provisioning is delayed until a pod using the PVC is scheduled. This ensures the PV is created in the same availability zone as the pod.

*Immediate matlab PVC banate hi PV ban jaata hai — chahe pod schedule hua ho ya nahi. WaitForFirstConsumer matlab jab tak pod schedule nahi hota, PV nahi banega — ye ensure karta hai ki PV usi zone mein bane jahan pod chalega.*

### Under the Hood: CSI (Container Storage Interface)

Modern Kubernetes uses the **CSI** standard to interact with storage backends. CSI drivers run as pods in the cluster and handle:

- Volume creation/deletion
- Volume attach/detach to nodes
- Volume mount/unmount in pods
- Snapshot and clone operations

Common CSI drivers: `ebs.csi.aws.com` (AWS), `disk.csi.azure.com` (Azure), `pd.csi.storage.gke.io` (GCP).

---

## Step-by-Step Lab: PostgreSQL StatefulSet with Persistent Storage

> [!info] Prerequisites
> - Minikube installed and running (`minikube start`)
> - `kubectl` configured
> - Basic understanding of YAML

### Step 1: Create the StorageClass

```bash
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: postgres-storage
provisioner: k8s.io/minikube-hostpath
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF
```

### Step 2: Create the Headless Service

StatefulSets require a headless service for stable DNS:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
  labels:
    app: postgres
spec:
  ports:
    - port: 5432
      name: postgres
  clusterIP: None
  selector:
    app: postgres
EOF
```

### Step 3: Create a Secret for PostgreSQL Password

```bash
kubectl create secret generic postgres-secret \
  --from-literal=POSTGRES_PASSWORD=devops2025secure
```

### Step 4: Deploy the PostgreSQL StatefulSet

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: "postgres-headless"
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:15-alpine
          ports:
            - containerPort: 5432
              name: postgres
          env:
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: POSTGRES_PASSWORD
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
  volumeClaimTemplates:
    - metadata:
        name: postgres-data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: postgres-storage
        resources:
          requests:
            storage: 1Gi
EOF
```

### Step 5: Verify Pod and PVC Creation

```bash
# Check StatefulSet status
kubectl get statefulset postgres

# Check pods — should see postgres-0
kubectl get pods -l app=postgres

# Check PVC — should see postgres-data-postgres-0
kubectl get pvc

# Check PV — dynamically created
kubectl get pv
```

### Step 6: Insert Test Data

```bash
# Connect to PostgreSQL
kubectl exec -it postgres-0 -- psql -U postgres

# Inside psql, run:
CREATE DATABASE devopslab;
\c devopslab
CREATE TABLE deployments (id SERIAL PRIMARY KEY, name VARCHAR(100), status VARCHAR(20));
INSERT INTO deployments (name, status) VALUES ('frontend-v2', 'success');
INSERT INTO deployments (name, status) VALUES ('backend-v3', 'failed');
INSERT INTO deployments (name, status) VALUES ('api-gateway', 'success');
SELECT * FROM deployments;
\q
```

### Step 7: Delete the Pod and Verify Data Persistence

```bash
# Delete the pod
kubectl delete pod postgres-0

# Wait for StatefulSet to recreate it
kubectl get pods -l app=postgres -w

# Once Running, reconnect and check data
kubectl exec -it postgres-0 -- psql -U postgres -d devopslab -c "SELECT * FROM deployments;"
```

**Expected Output:** All three rows should still be present! The data survived because it's stored on the PVC, not inside the container.

*Dekho — pod delete kiya, naya pod aaya, par data wahi hai! Ye PVC ki taakat hai — data pod ke andar nahi, bahar ek permanent disk pe stored hai. Jaise tum hotel room se checkout karo par tumhara saamaan locker mein safe hai.*

### Step 8: Cleanup

```bash
kubectl delete statefulset postgres
kubectl delete svc postgres-headless
kubectl delete secret postgres-secret
kubectl delete pvc postgres-data-postgres-0
kubectl get pv  # Check if PV is in "Released" state (because reclaimPolicy: Retain)
```

---

## Commands Cheat Sheet

| Command | Description |
|---|---|
| `kubectl get pv` | List all PersistentVolumes in the cluster |
| `kubectl get pvc` | List all PersistentVolumeClaims in the current namespace |
| `kubectl get pvc -A` | List PVCs across all namespaces |
| `kubectl describe pv <pv-name>` | Show detailed info about a PV — capacity, access modes, status, claim |
| `kubectl describe pvc <pvc-name>` | Show PVC details — bound PV, storage class, events |
| `kubectl get storageclass` | List all StorageClasses available in the cluster |
| `kubectl get statefulset` | List all StatefulSets in current namespace |
| `kubectl describe statefulset <name>` | Show StatefulSet details including volumeClaimTemplates |
| `kubectl patch pv <pv-name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'` | Change reclaim policy of an existing PV to Retain |
| `kubectl get pv -o jsonpath='{.items[*].spec.claimRef.name}'` | List which PVCs are bound to which PVs |
| `kubectl delete pvc <pvc-name>` | Delete a PVC (triggers reclaim policy on bound PV) |
| `kubectl exec -it <pod> -- df -h` | Check mounted volumes and disk usage inside a pod |

---

## Troubleshooting Guide

| Problem | Symptoms | Root Cause | Solution |
|---|---|---|---|
| PVC stuck in `Pending` | `kubectl get pvc` shows Pending indefinitely | No matching PV available, or StorageClass provisioner not installed | Check `kubectl describe pvc <name>` events. Ensure StorageClass exists and provisioner is running. For minikube: `minikube addons enable default-storageclass` |
| Pod stuck in `ContainerCreating` | Pod never reaches Running state | Volume mount failure — PV not attached or filesystem not formatted | Run `kubectl describe pod <name>` — look for `FailedMount` or `FailedAttachVolume` events. Check node has access to storage backend. |
| PV shows `Released` but cannot be rebound | After PVC deletion, PV status is Released | Retain policy keeps PV locked with old `claimRef` | Remove the `claimRef` from PV: `kubectl patch pv <pv-name> -p '{"spec":{"claimRef": null}}'` |
| Data lost after pod restart | Database tables missing after pod recreation | Pod was using `emptyDir` instead of PVC, or `PGDATA` path doesn't match volume mount | Verify `volumeMounts` path matches the application's data directory. Ensure PVC is in the pod spec. |
| `Permission denied` writing to mounted volume | Application logs show write errors on mount path | Security context mismatch — container runs as non-root but volume owned by root | Add `securityContext.fsGroup` to pod spec or use an `initContainer` to `chown` the mount directory. |
| StorageClass provisioner failing | PVCs pending, events show provisioner errors | CSI driver not installed or misconfigured | Check CSI driver pods: `kubectl get pods -n kube-system`. Reinstall the CSI driver for your platform. |
| Multi-attach error on RWO volume | `Multi-Attach error for volume` in pod events | Two pods on different nodes trying to mount same RWO volume | Ensure only one pod uses the PVC, or switch to RWX-compatible storage (NFS/EFS). |

---

## Real-World Scenario

### Scenario: E-Commerce Platform Database Migration

**Company:** ShopKart — a growing e-commerce platform running on Kubernetes.

**Problem:** The team initially deployed their PostgreSQL database as a **Deployment** with a single PVC. Everything worked until they needed to scale to a primary-replica setup. Issues encountered:

1. Both pods tried to mount the same PVC with RWO — multi-attach errors.
2. Pod names were random, making replication configuration unreliable.
3. No guaranteed ordering — replica sometimes started before primary.

**Solution:** Migrated to a **StatefulSet** architecture:

- **StatefulSet** with `volumeClaimTemplates` — each replica gets its own PVC (`pgdata-postgres-0`, `pgdata-postgres-1`).
- **Headless Service** — primary is always reachable at `postgres-0.postgres-headless.default.svc.cluster.local`.
- **Ordered startup** — `postgres-0` (primary) always starts first, then `postgres-1` (replica) initializes from primary.
- **Retain reclaim policy** — production data is never auto-deleted.

**Result:** Zero-downtime database operations. Replica lag reduced to under 100ms. Data persistence verified across multiple node failures.

*ShopKart company ne pehle database ko Deployment se chalaya — jab scale kiya toh multi-attach error aaya kyunki do pods ek hi disk use karna chahte the. StatefulSet mein shift karne se har pod ko apna alag disk mila, fixed naam mila (postgres-0, postgres-1), aur ordering guarantee mili. Ab primary pehle start hota hai, phir replica.*

---

## Interview Questions

### Q1: What is the difference between PV, PVC, and StorageClass?
**Answer:** A **PersistentVolume (PV)** is the actual storage resource in the cluster (like an NFS share or cloud disk). A **PersistentVolumeClaim (PVC)** is a user's request for storage — it specifies size, access mode, and optionally a StorageClass. A **StorageClass** defines how storage should be dynamically provisioned — it specifies the provisioner, parameters, and reclaim policy. The admin creates PVs/StorageClasses, and developers create PVCs. Kubernetes binds PVCs to matching PVs.

### Q2: What are the access modes and when would you use each?
**Answer:** **ReadWriteOnce (RWO)** — mounted read-write by a single node; used for databases like PostgreSQL/MySQL. **ReadOnlyMany (ROX)** — mounted read-only by many nodes; used for shared config or static content. **ReadWriteMany (RWX)** — mounted read-write by many nodes; used for shared uploads or CMS media (requires NFS/CephFS/EFS). **ReadWriteOncePod (RWOP)** — single pod exclusive access; used when strict single-writer guarantee is needed.

### Q3: Explain the difference between static and dynamic provisioning.
**Answer:** In **static provisioning**, an admin pre-creates PVs manually, and PVCs bind to them based on matching criteria (size, access mode, labels). In **dynamic provisioning**, the admin creates a StorageClass with a provisioner, and when a PVC references that StorageClass, Kubernetes automatically creates a PV on-demand. Dynamic provisioning is preferred in production for scalability — you don't need to pre-provision storage for every application.

### Q4: Why would you use a StatefulSet instead of a Deployment?
**Answer:** Use a StatefulSet when your application needs: (1) **Stable network identity** — each pod gets a predictable DNS name like `pod-0.service.namespace.svc.cluster.local`. (2) **Stable persistent storage** — each pod gets its own PVC via `volumeClaimTemplates`. (3) **Ordered deployment and scaling** — pods are created in order (0, 1, 2) and terminated in reverse. This is critical for databases (PostgreSQL, MySQL), message queues (Kafka), and consensus systems (ZooKeeper, etcd).

### Q5: What happens to a PV when its PVC is deleted with a Retain reclaim policy?
**Answer:** The PV transitions to a **Released** state. The data is preserved, but the PV cannot be automatically rebound to a new PVC because it still holds a `claimRef` to the deleted PVC. An administrator must manually remove the `claimRef` from the PV spec and optionally clean up the data before making it Available again. This is the safest policy for production data.

### Q6: What is a Headless Service and why does StatefulSet need it?
**Answer:** A Headless Service is a Service with `clusterIP: None`. Instead of providing a single virtual IP with load balancing, it creates individual DNS A records for each pod. StatefulSets need this because they require **stable, predictable network identities**. With a headless service named `db-svc`, pod `db-0` gets DNS `db-0.db-svc.namespace.svc.cluster.local`. This is essential for database replication where the primary node must be individually addressable.

### Q7: How does volumeBindingMode WaitForFirstConsumer help in multi-zone clusters?
**Answer:** With `Immediate` binding, the PV is provisioned as soon as the PVC is created, potentially in a different availability zone than where the pod will be scheduled. This causes scheduling failures because the pod must run on a node in the same zone as the volume. `WaitForFirstConsumer` delays PV provisioning until a pod using the PVC is scheduled, ensuring the PV is created in the same zone as the pod's node. This is critical in AWS/GCP/Azure multi-AZ clusters.

---

## Related Notes

- [[K8S-01 Kubernetes Architecture]] — Understand the control plane components that manage storage operations
- [[K8S-02 Pods and Workloads]] — Pod volume mounts and container storage basics
- [[K8S-03 Services and Service Discovery]] — Headless Services used with StatefulSets
- [[K8S-05 Ingress and Networking]] — Network layer that exposes your stateful applications
- [[K8S-06 RBAC and Security]] — Securing access to PVs and StorageClasses
- [[Docker-02 Volumes and Networking]] — Docker volume concepts that Kubernetes builds upon

---

> [!quote] DevOps Wisdom
> "Treat your servers like cattle, not pets. But treat your data like a treasure — persistent, protected, and always backed up."

