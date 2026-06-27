---
tags:
  - devops
  - kubernetes
  - architecture
aliases:
  - K8s Architecture
created: 2025-06-27
status: "#complete"
difficulty: "#beginner"
cert-relevant: "#cka"
---

# Kubernetes Architecture

> [!abstract] Overview
> Kubernetes (K8s) is an open-source container orchestration platform originally designed by Google and now maintained by the CNCF. It automates the deployment, scaling, and management of containerized applications across clusters of machines. Understanding K8s architecture is the single most important prerequisite for every CKA exam topic, every production troubleshooting session, and every design discussion around microservices. This note breaks down the control plane, worker nodes, networking primitives, and local development tools in depth.

*Kubernetes ek orchestration platform hai jo containers ko automatically manage karta hai — socho ek traffic police jo hazaaron gaadiyaan (containers) ko smoothly chalata hai bina kisi accident ke. Docker akela ek gaadi chala sakta hai, lekin jab fleet manage karni ho toh K8s chahiye.*

---

## Concept Overview

### Why Kubernetes Exists — Docker Alone Ki Limitations

Docker revolutionised packaging applications, but running containers at scale with Docker alone creates serious operational gaps:

| Problem with Docker Alone | How Kubernetes Solves It |
|---|---|
| No auto-restart on crash | Self-healing via controllers |
| No built-in load balancing | Service abstraction with kube-proxy |
| No rolling updates natively | Deployment strategy (RollingUpdate) |
| No declarative desired-state | etcd stores desired state, controllers reconcile |
| No cross-host networking | CNI plugins (Calico, Flannel, Cilium) |
| Manual scaling | HPA / VPA autoscalers |
| No secrets management | Secret objects with RBAC |
| No health checks built-in | Liveness, Readiness, Startup probes |

*Docker ek bahut achha carpenter hai — ek chair bana sakta hai. Lekin jab tumhe 500 chairs banani ho, quality check karni ho, tootne pe replace karni ho — tab tumhe factory chahiye. Kubernetes woh factory hai.*

---

## Technical Deep Dive

### Control Plane Components

The control plane (master node) is the brain of the cluster. It makes global decisions about the cluster (scheduling), and detects and responds to cluster events.

#### 1. kube-apiserver

The API Server is the **front door** of Kubernetes. Every interaction — whether from `kubectl`, the dashboard, or internal components — goes through the API Server as a RESTful API call.

- Validates and processes REST requests
- Serves as the single point of communication between all components
- Implements admission controllers (mutating and validating webhooks)
- Authenticates and authorises every request via RBAC
- Horizontally scalable — you can run multiple instances behind a load balancer

*API Server ek reception desk hai — koi bhi office mein aaye, pehle reception pe jaana padega. Bina reception ke koi seedha andar nahi ja sakta.*

#### 2. etcd

etcd is a distributed, consistent key-value store that acts as the **single source of truth** for the entire cluster.

- Stores all cluster state: nodes, pods, configmaps, secrets, RBAC policies
- Uses the Raft consensus algorithm for leader election and replication
- Typically deployed as a 3 or 5 node cluster for high availability (odd numbers to avoid split-brain)
- Direct access is dangerous — always interact through the API Server
- Backup and restore of etcd is a critical CKA exam topic

```bash
# Check etcd health
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Backup etcd
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

*etcd ek government record room hai — sabki jaankari yahan likhi hoti hai. Agar record room jal jaaye toh poora office band. Isliye backup zaroori hai.*

#### 3. kube-scheduler

The Scheduler watches for newly created Pods that have no node assigned and selects a node for them to run on.

- Evaluates resource requirements (CPU/memory requests and limits)
- Checks node affinity/anti-affinity rules
- Evaluates taints and tolerations
- Considers pod topology spread constraints
- Uses a scoring algorithm: filtering → scoring → binding

*Scheduler ek hostel warden hai — naye student aaye toh dekhta hai kis room mein jagah hai, kaunsa room suitable hai, aur phir assign karta hai.*

#### 4. kube-controller-manager

Runs a collection of controller loops that watch the cluster state via the API Server and make changes to move the **current state** toward the **desired state**.

Key controllers include:
- **Node Controller** — monitors node health (40s default timeout)
- **ReplicaSet Controller** — ensures correct number of pod replicas
- **Endpoints Controller** — populates endpoint objects for services
- **Service Account Controller** — creates default service accounts for new namespaces
- **Job Controller** — watches for Job objects and creates pods to run them

*Controller Manager ek supervisor hai factory mein — agar koi worker absent ho jaaye toh turant replacement bhejta hai. Desired state aur current state match karana iska kaam hai.*

#### 5. cloud-controller-manager (Optional)

Links the cluster to cloud provider APIs (AWS, GCP, Azure) for managing load balancers, storage volumes, and node lifecycle. Not present in bare-metal or minikube setups.

---

### Worker Node Components

#### 1. kubelet

The kubelet is the **primary agent** running on every worker node. It receives pod specifications (PodSpecs) from the API Server and ensures containers described in those specs are running and healthy.

- Registers the node with the API Server
- Watches for PodSpecs assigned to its node
- Pulls container images via the container runtime
- Executes liveness, readiness, and startup probes
- Reports node and pod status back to the API Server
- Does NOT manage containers not created by Kubernetes

*kubelet ek foreman hai construction site pe — blueprint (PodSpec) milta hai architect (API Server) se, aur woh ensure karta hai ki building (container) theek se ban rahi hai.*

#### 2. kube-proxy

kube-proxy maintains network rules on each node that allow network communication to pods from inside or outside the cluster.

- Implements Services using iptables rules (default mode) or IPVS
- Handles ClusterIP, NodePort, and LoadBalancer traffic routing
- Watches the API Server for Service and Endpoint changes
- In IPVS mode, provides better performance at scale with O(1) connection routing

*kube-proxy ek telephone exchange operator hai — call aaye toh correct extension pe connect karta hai. Service ka traffic correct pod tak pahunchana iska kaam hai.*

#### 3. Container Runtime

The software responsible for actually running containers. Kubernetes supports any CRI (Container Runtime Interface) compliant runtime:

- **containerd** — industry standard, used by Docker Desktop and most managed K8s
- **CRI-O** — lightweight, designed specifically for Kubernetes
- **Docker Engine** (via dockershim, removed in K8s 1.24+)

---

### kubectl and kubeconfig

`kubectl` is the command-line tool for communicating with the Kubernetes API Server.

**kubeconfig** is the configuration file (default `~/.kube/config`) that stores:

```yaml
apiVersion: v1
kind: Config
clusters:
  - cluster:
      server: https://192.168.49.2:8443
      certificate-authority: /home/user/.minikube/ca.crt
    name: minikube
contexts:
  - context:
      cluster: minikube
      user: minikube
      namespace: default
    name: minikube
current-context: minikube
users:
  - name: minikube
    user:
      client-certificate: /home/user/.minikube/profiles/minikube/client.crt
      client-key: /home/user/.minikube/profiles/minikube/client.key
```

**Contexts** allow switching between multiple clusters:
```bash
kubectl config get-contexts
kubectl config use-context minikube
kubectl config set-context --current --namespace=dev
```

**Namespaces** provide logical isolation within a cluster:
```bash
kubectl get namespaces
kubectl create namespace dev
kubectl get pods -n kube-system    # see control plane pods
```

*kubeconfig ek address book hai — ismein likha hai ki kaunsa cluster kahan hai, login kaise karna hai. Context switch karna matlab ek office se doosre office ka address use karna.*

---

### K8s Object Model Overview

Everything in Kubernetes is an **object** — a persistent entity that represents the desired state. Objects have:

- **apiVersion** — which API group the object belongs to
- **kind** — type of object (Pod, Deployment, Service, etc.)
- **metadata** — name, namespace, labels, annotations
- **spec** — desired state declared by the user
- **status** — current state reported by the system (managed by controllers)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    app: web
spec:
  containers:
    - name: nginx
      image: nginx:1.25
      ports:
        - containerPort: 80
```

---

### Minikube vs Kind vs K3s — Local Kubernetes Options

| Feature | Minikube | Kind | K3s |
|---|---|---|---|
| Full Name | Mini Kubernetes | Kubernetes in Docker | Lightweight Kubernetes |
| Best For | Learning, CKA prep | CI/CD pipelines, testing | Edge, IoT, resource-constrained |
| Runs On | VM or Docker | Docker containers | Bare metal, VM |
| Multi-node | Yes (with --nodes) | Yes (native) | Yes |
| Resource Usage | Medium-High | Low | Very Low |
| LoadBalancer Support | `minikube tunnel` | MetalLB needed | Built-in (Traefik) |
| Add-ons | Built-in addon system | Manual | Helm charts |
| CKA Exam Relevance | High | Medium | Low |

---

## Step-by-Step Lab

### Lab: Install Minikube, Explore Components, Break etcd

**Prerequisites:** Docker Desktop installed and running, `kubectl` installed.

#### Step 1 — Install Minikube

```bash
# Windows (PowerShell)
choco install minikube

# macOS
brew install minikube

# Linux
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

#### Step 2 — Start a Cluster

```bash
minikube start --driver=docker --cpus=2 --memory=4096 --kubernetes-version=v1.29.0
```

Expected output:
```
😄  minikube v1.32.0 on Ubuntu 22.04
✨  Using the docker driver based on user configuration
📌  Using Docker Desktop driver with root privileges
🧯  Creating docker container (CPUs=2, Memory=4096MB) ...
🐳  Preparing Kubernetes v1.29.0 on Docker 24.0.7 ...
🔎  Verifying Kubernetes components...
🌟  Enabled addons: default-storageclass, storage-provisioner
🏄  Done! kubectl is now configured to use "minikube" cluster
```

#### Step 3 — Explore Control Plane Components

```bash
# See all system pods
kubectl get pods -n kube-system

# Expected output:
# NAME                               READY   STATUS    RESTARTS   AGE
# coredns-5dd5756b68-xxxxx           1/1     Running   0          2m
# etcd-minikube                      1/1     Running   0          2m
# kube-apiserver-minikube            1/1     Running   0          2m
# kube-controller-manager-minikube   1/1     Running   0          2m
# kube-proxy-xxxxx                   1/1     Running   0          2m
# kube-scheduler-minikube            1/1     Running   0          2m
# storage-provisioner                1/1     Running   0          2m

# Describe the API server
kubectl describe pod kube-apiserver-minikube -n kube-system

# Check cluster info
kubectl cluster-info

# View nodes
kubectl get nodes -o wide

# Check component statuses
kubectl get componentstatuses   # deprecated but still works on some versions
```

#### Step 4 — Explore kubeconfig and Contexts

```bash
# View kubeconfig
kubectl config view

# See current context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# Create a namespace and switch context
kubectl create namespace lab-test
kubectl config set-context --current --namespace=lab-test
kubectl config get-contexts   # notice the NAMESPACE column
```

#### Step 5 — Understand What Breaks If etcd Goes Down

```bash
# SSH into minikube node
minikube ssh

# Find etcd process
ps aux | grep etcd

# Simulate etcd failure by pausing the container (inside minikube)
docker pause $(docker ps -q --filter "name=etcd")

# In another terminal, try creating a pod:
kubectl run test-pod --image=nginx
# ERROR: the connection to the server was refused / context deadline exceeded

# Try listing pods:
kubectl get pods
# ERROR: etcdserver: request timed out

# Resume etcd
minikube ssh
docker unpause $(docker ps -q --filter "name=etcd")

# Now try again — everything works
kubectl get pods
kubectl run test-pod --image=nginx
```

*Jab etcd band hua, kuch bhi kaam nahi kiya — na pod bana, na list aaya. Kyunki etcd hi woh jagah hai jahan saara data stored hai. Bina record room ke office chalta nahi.*

#### Step 6 — Cleanup

```bash
kubectl delete pod test-pod
kubectl config set-context --current --namespace=default
kubectl delete namespace lab-test
minikube stop
```

---

## Commands Cheat Sheet

| Command | Description |
|---|---|
| `minikube start --driver=docker` | Start minikube cluster using Docker driver |
| `minikube status` | Check status of minikube cluster and components |
| `minikube dashboard` | Open Kubernetes dashboard in browser |
| `minikube ssh` | SSH into the minikube VM/container |
| `minikube addons list` | List all available minikube addons |
| `minikube delete` | Delete the minikube cluster entirely |
| `kubectl cluster-info` | Display cluster endpoint information |
| `kubectl get nodes -o wide` | List all nodes with extra details (IPs, OS, runtime) |
| `kubectl get pods -n kube-system` | List all control plane pods |
| `kubectl describe node minikube` | Detailed info about a node (capacity, allocatable, conditions) |
| `kubectl config view` | Display merged kubeconfig settings |
| `kubectl config get-contexts` | List all configured contexts |
| `kubectl config use-context <name>` | Switch to a different cluster context |
| `kubectl config set-context --current --namespace=<ns>` | Set default namespace for current context |
| `kubectl api-resources` | List all available API resources and their short names |
| `kubectl explain pod.spec` | Show documentation for a resource field |

---

## Troubleshooting Guide

| Issue | Possible Cause | Resolution |
|---|---|---|
| `minikube start` fails with "driver not found" | Docker not installed or not running | Start Docker Desktop, verify with `docker ps` |
| `The connection to the server was refused` | API Server is down or kubeconfig incorrect | Run `minikube status`, restart with `minikube start` |
| `Unable to connect to the server: dial tcp: lookup host: no such host` | DNS resolution failure or wrong cluster address in kubeconfig | Verify `~/.kube/config` has correct server address |
| `etcdserver: request timed out` | etcd is overloaded or down | Check etcd pod logs: `kubectl logs etcd-minikube -n kube-system` |
| `error: no configuration has been provided` | kubeconfig file missing or not set | Export KUBECONFIG or run `minikube update-context` |
| `kubectl get nodes` shows `NotReady` | kubelet not running or CNI plugin not installed | SSH into node, check `systemctl status kubelet`, check `/var/log/kubelet.log` |
| `scheduler error: 0/1 nodes are available` | Node has taints, insufficient resources, or pod affinity mismatch | Check taints: `kubectl describe node`, check resource requests vs allocatable |
| `ImagePullBackOff` on kube-system pods | No internet or image registry unreachable | Check internet connectivity inside minikube: `minikube ssh -- curl google.com` |

---

## Real-World Scenario

### Scenario: Production etcd Cluster Failure at a Fintech Startup

**Context:** A fintech company ran a 3-node Kubernetes cluster on bare metal. Their etcd cluster was co-located on the same machines as the control plane (stacked topology).

**Incident:** During a routine OS upgrade, two etcd nodes rebooted simultaneously. With only 1 of 3 etcd members available, the cluster lost quorum (needs majority = 2 of 3).

**Symptoms:**
- `kubectl` commands timed out
- New pods could not be scheduled
- Existing running pods continued to run (kubelet works independently once pod is scheduled)
- CI/CD pipelines failed because they could not deploy new versions

**Resolution:**
1. Restored one etcd node quickly to regain quorum (2 of 3)
2. Verified cluster health: `etcdctl endpoint health`
3. Performed etcd defragmentation after recovery
4. Implemented staggered OS upgrade policy — never upgrade more than one etcd member at a time

**Lessons:**
- Always run etcd with odd number of members (3 or 5)
- Keep etcd backups on external storage (S3, NFS)
- Use external etcd topology for critical production clusters
- Monitor etcd latency and disk IOPS — etcd is very sensitive to disk performance

*Jaise bank ke teen lockers mein copies hoti hain — agar ek kho jaaye toh baaki se recover ho jaata hai. Lekin agar do ek saath kho jaayein toh mushkil ho jaati hai. Yahi quorum ka concept hai.*

---

## Interview Questions

### Q1: What happens when you run `kubectl apply -f pod.yaml`?
**Answer:** The request flows through: kubectl → API Server (authentication → authorization → admission controllers → validation) → writes to etcd → Scheduler watches for unscheduled pods → assigns a node → kubelet on that node picks up the PodSpec → pulls image via container runtime → starts container → reports status back to API Server → status updated in etcd.

### Q2: What is the difference between the control plane and the data plane in Kubernetes?
**Answer:** The control plane (API Server, etcd, Scheduler, Controller Manager) makes decisions about the cluster — scheduling, scaling, state management. The data plane (worker nodes with kubelet, kube-proxy, container runtime) executes those decisions — actually running containers and routing traffic.

### Q3: Why does etcd use an odd number of nodes?
**Answer:** etcd uses the Raft consensus protocol which requires a majority (quorum) to agree on any state change. With 3 nodes, quorum is 2 — so 1 failure is tolerated. With 4 nodes, quorum is 3 — still only 1 failure tolerated, but more overhead. With 5 nodes, quorum is 3 — tolerates 2 failures. Odd numbers give the optimal fault-tolerance-to-resource ratio.

### Q4: Can a Kubernetes cluster function if the API Server goes down?
**Answer:** Existing workloads continue running because kubelet operates independently once pods are scheduled. However, no new operations can be performed — no new deployments, no scaling, no `kubectl` commands. This is why production clusters run multiple API Server replicas behind a load balancer.

### Q5: What is the difference between a taint and a toleration?
**Answer:** Taints are applied to nodes to repel pods (e.g., `kubectl taint nodes node1 key=value:NoSchedule`). Tolerations are applied to pods to allow them to be scheduled on tainted nodes. This mechanism ensures only specific workloads run on designated nodes (e.g., GPU nodes, dedicated infra nodes).

### Q6: Explain the kubelet's role in pod lifecycle management.
**Answer:** The kubelet watches the API Server for PodSpecs assigned to its node. It instructs the container runtime (containerd/CRI-O) to pull images and start containers. It continuously runs health probes (liveness, readiness, startup). If a liveness probe fails, kubelet restarts the container. It reports pod and node status back to the API Server at regular intervals.

### Q7: What is the difference between minikube, kind, and k3s?
**Answer:** Minikube creates a single/multi-node cluster in a VM or Docker container — best for learning and CKA prep. Kind (Kubernetes in Docker) runs cluster nodes as Docker containers — ideal for CI/CD testing and fast iteration. K3s is a lightweight certified K8s distribution by Rancher — designed for edge computing, IoT, and resource-constrained environments. Each targets a different use case.

---

## Related Notes

- [[K8S-02 Pods Deployments Services]] — Core workload objects that run on this architecture
- [[K8S-03 ConfigMaps and Secrets]] — Configuration management within the cluster
- [[Docker Fundamentals]] — Container basics that K8s orchestrates
- [[Linux Networking]] — Understanding networking foundations for kube-proxy and CNI
- [[CI-CD Pipelines]] — How deployments are triggered in production K8s clusters
