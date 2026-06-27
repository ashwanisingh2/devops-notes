---
tags: [devops, orchestration, docker-swarm, kubernetes]
aliases: [Swarm vs K8s]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# Docker Swarm vs Kubernetes

> [!abstract] Overview
> Docker Swarm and Kubernetes are the two major container orchestration platforms. While Kubernetes has won the orchestration war and is the industry standard for complex, large-scale distributed systems, Docker Swarm remains a viable, incredibly simple alternative for smaller teams or straightforward applications. This note breaks down their architectural differences, use cases, and helps you decide when to choose simplicity over complexity.

## Concept Overview (What/Why/Where/Responsibility Split)

**What is it?**
Both are tools to manage clusters of Docker containers. They handle scheduling (deciding where containers run), scaling, networking, and self-healing.
*   **Docker Swarm:** Docker's native clustering tool. It turns a pool of Docker hosts into a single, virtual Docker host.
*   **Kubernetes (K8s):** Originally designed by Google, it's a massive, extensible ecosystem for container management.

*Hindi Explanation:* 
*Socho ki ek chhota restaurant hai aur ek 5-star hotel. Docker Swarm wo chhota restaurant hai – simple menu, manager khud sab manage kar leta hai, setup karna asaan hai. Kubernetes wo 5-star hotel hai – alag alag departments, specialized staff, complex procedures, par kitni bhi bheed aa jaye, sambhal lega. Swarm me simplicity milti hai, K8s me power aur scalability.*

**Why use Swarm instead of K8s?**
*   **Simplicity:** No new CLI to learn if you know Docker (`docker swarm` instead of `kubectl`).
*   **Lower Overhead:** Doesn't require heavy control plane components like etcd, kube-apiserver.
*   **Fast Setup:** A Swarm cluster can be up in minutes.

**Where is it used?**
Swarm is used in startups, edge computing devices (like Raspberry Pi clusters), or internal tooling where the complexity of Kubernetes cannot be justified. K8s is used for enterprise-grade, microservices architectures.

**Responsibility Split**
*   **DevOps Engineer (Swarm):** Initialize swarm, add nodes, deploy stacks via `docker-compose.yml`.
*   **DevOps Engineer (K8s):** Manage Helm charts, YAML manifests, RBAC, Ingress, Persistent Volumes, and cluster upgrades.

## Technical Deep Dive

### 1. Architectural Differences
**Docker Swarm Architecture:**
Swarm uses a decentralized architecture. It consists of Manager Nodes and Worker Nodes. The managers use a Raft consensus algorithm internally (built into Docker daemon) to maintain cluster state. It doesn't need external databases. You interact with it using the standard Docker API.
**Kubernetes Architecture:**
K8s has a distinct Control Plane (Master) and Data Plane (Workers). The Control Plane has separate, heavy components: `kube-apiserver` (frontend), `etcd` (distributed key-value store for state), `kube-scheduler` (assigns pods to nodes), and `kube-controller-manager` (runs control loops). Workers run `kubelet` and `kube-proxy`. This decoupling makes K8s robust but heavy.

### 2. Networking and Service Discovery
In **Docker Swarm**, networking is handled natively via overlay networks. When you create a service, Swarm assigns it a Virtual IP (VIP). The routing mesh automatically routes ingress traffic to any node in the Swarm, which then forwards it to the active container. Service discovery is built-in DNS.
In **Kubernetes**, networking requires a CNI (Container Network Interface) plugin like Calico, Flannel, or Cilium. Service discovery is handled by CoreDNS. K8s exposes applications using Services (ClusterIP, NodePort, LoadBalancer) and Ingress resources, offering far more granular control over traffic routing (e.g., header-based routing) than Swarm's simple routing mesh.

### 3. Application Deployment Models
**Docker Swarm** uses Docker Compose syntax (`docker-compose.yml`) for deploying multi-container apps, called Stacks (`docker stack deploy`). It's declarative but limited in scope.
**Kubernetes** uses native YAML manifests (Deployments, StatefulSets, DaemonSets). K8s primitives are much more powerful. For instance, K8s supports Init Containers, Sidecars, and custom Health Probes (Liveness/Readiness/Startup). Swarm just has basic healthchecks. Furthermore, K8s ecosystem tools like Helm or Kustomize provide advanced templating, which Swarm lacks.

## Step-by-Step Lab

**Scenario:** Initialize a Swarm manager and deploy a basic Nginx service.

**Step 1: Initialize the Swarm Manager**
```bash
# On your main machine (Manager)
docker swarm init --advertise-addr 192.168.1.100
# Output:
# Swarm initialized: current node (dxn1...) is now a manager.
# To add a worker to this swarm, run the following command:
# docker swarm join --token SWMTKN-1-... 192.168.1.100:2377
```

**Step 2: Add a Worker Node (Optional if you have a 2nd VM)**
```bash
# On the worker node
docker swarm join --token SWMTKN-1-... 192.168.1.100:2377
# Output: This node joined a swarm as a worker.
```

**Step 3: Check Cluster Status**
```bash
docker node ls
# Output:
# ID                            HOSTNAME   STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
# dxn1... *                     manager1   Ready     Active         Leader           24.0.5
# a7x...                        worker1    Ready     Active                          24.0.5
```

**Step 4: Create a docker-compose.yml for the Stack**
```yaml
# Create a file named docker-compose.yml
version: '3.8'
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
```

**Step 5: Deploy the Stack**
```bash
docker stack deploy -c docker-compose.yml myapp
# Output:
# Creating network myapp_default
# Creating service myapp_web
```

**Step 6: Verify the Service and Replicas**
```bash
docker service ls
# Output: ID   NAME   MODE   REPLICAS   IMAGE   PORTS
# xyz... myapp_web   replicated   3/3        nginx:alpine   *:8080->80/tcp

docker service ps myapp_web
# Shows where the 3 replicas are running.
```

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
| :--- | :--- | :--- |
| `docker swarm init` | Initializes a new swarm cluster | `docker swarm init --advertise-addr 10.0.0.1` |
| `docker swarm join-token` | Shows the token to join as worker/manager | `docker swarm join-token worker` |
| `docker node ls` | Lists all nodes in the swarm | `docker node ls` |
| `docker stack deploy` | Deploys a compose file as a stack | `docker stack deploy -c app.yml mystack` |
| `docker stack ls` | Lists deployed stacks | `docker stack ls` |
| `docker service ls` | Lists services running in swarm | `docker service ls` |
| `docker service scale` | Scales a service up or down | `docker service scale mystack_web=5` |
| `docker service logs` | Fetches logs for a service | `docker service logs mystack_web` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| Node cannot join swarm | Firewall blocking port 2377 | 1. `sudo ufw allow 2377/tcp`<br>2. Retry `docker swarm join` |
| Service replicas stuck in `Pending` | Insufficient resources on nodes | 1. `docker service ps <service>` to see errors.<br>2. Check node RAM/CPU.<br>3. Scale down or add nodes. |
| `rpc error: code = Unknown` on deploy | Compose file version too high/low | 1. Check top of `docker-compose.yml`.<br>2. Change `version: '3.8'` to match your Docker engine version. |
| Routing mesh not working (can't hit app on Node B) | Overlay network ports blocked | 1. Allow UDP 4789 and TCP/UDP 7946 on firewalls between nodes. |
| Docker stack deploy says network not found | External network missing | 1. If using `external: true`, create it first: `docker network create -d overlay mynet` |

## Real-World Job Scenario

**Scenario:** The company needs a temporary testing environment for a legacy monolithic application split into 3 containers (web, app, db).

*   **Junior Engineer's Action:** Suggests building a full Kubernetes cluster using EKS or Rancher. Spends 3 days writing YAML manifests and setting up Helm. The environment is too complex for the QA team to troubleshoot.
*   **Senior Engineer's Action:** Evaluates the requirement (temporary, low complexity). Spins up a 3-node Docker Swarm in 15 minutes using Ansible. Converts the existing `docker-compose.yml` by adding a `deploy:` block and runs `docker stack deploy`. Delivers the environment in 2 hours, saving time and cloud costs.

## Interview Questions

1.  **Q: What is the primary difference between how Swarm and K8s handle state?**
    *   **A:** Swarm manages state internally using a built-in Raft consensus among manager nodes. K8s relies on an external, dedicated component called `etcd` to store cluster state and configuration.
2.  **Q: How does Swarm's routing mesh work?**
    *   **A:** Swarm assigns a published port on every node in the cluster. If a request hits Node A for a service running on Node B, Node A's routing mesh transparently forwards the traffic to Node B via the overlay network.
3.  **Q: Why would you choose Swarm over Kubernetes in 2025?**
    *   **A:** When the team lacks K8s expertise, the application is simple (not heavily microservices-based), infrastructure resources are highly constrained (edge computing), and fast time-to-market is prioritized over extreme extensibility.
4.  **Q: Can you use existing docker-compose files with Docker Swarm?**
    *   **A:** Yes, with minor modifications. You use `docker stack deploy` instead of `docker-compose up`. You typically add a `deploy:` section to specify replicas, update strategies, and placement constraints. `build` directives are ignored in swarm mode.
5.  **Q: What happens if a Swarm manager node goes down?**
    *   **A:** If you have multiple managers (e.g., 3), the remaining managers hold an election to choose a new leader. The cluster continues to function normally. If you lose quorum (e.g., 2 out of 3 die), you cannot update the cluster state, but existing containers on worker nodes keep running.

## Related Notes
- [[Master Index]]
- [[KUBERNETES-01 Kubernetes Architecture]]
- [[DOCKER-02 Docker Compose]]
