---
tags: [devops, service-discovery, consul, networking]
aliases: [Consul]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# Consul

> [!abstract] Overview
> Consul, by HashiCorp, is a multi-cloud service networking platform. It provides a distributed, highly available Key-Value store, robust Service Discovery, and Health Checking. In dynamic microservices environments where IP addresses constantly change, Consul acts as the central directory, allowing services to find each other by name rather than hardcoded IPs, forming the backbone of service mesh architectures.

## Concept Overview (What/Why/Where/Responsibility Split)

**What is it?**
Imagine a dynamic environment where an API container gets recreated and its IP changes. How does the frontend know the new IP? Consul solves this. Services register themselves with Consul when they start. Consul constantly health-checks them. Other services query Consul (via API or DNS) to find healthy instances.

*Hindi Explanation:*
*Consul ek 'Telephone Directory' (Phonebook) ki tarah kaam karta hai. Agar Web server ko Database se baat karni hai, toh use IP yaad rakhne ki zaroorat nahi. Wo Consul se puchega, "Bhai DB ka address kya hai?". Consul check karega kaunsa DB server zinda (healthy) hai aur uska address de dega. Jab bhi koi naya server aata hai, wo apna naam Consul me likhwa deta hai (Register).*

**Why use it?**
*   **Service Discovery:** Decouple services from static IP configurations.
*   **Health Checking:** Prevent traffic from being sent to failed instances automatically.
*   **KV Store:** Store dynamic configuration, feature flags, or leader election data safely.
*   **Service Mesh:** Consul Connect secures service-to-service communication with mTLS.

**Where is it used?**
In microservices architectures running on bare metal, VMs, or mixed environments (e.g., hybrid cloud where some apps are in K8s, some in EC2) to provide a unified service registry and routing.

**Responsibility Split**
*   **Platform/DevOps Engineer:** Sets up the Consul cluster (Servers), configures gossip protocols, and ensures high availability.
*   **Application Developer:** Adds Consul agents/SDKs to their code to register the service and read configs from the KV store.

## Technical Deep Dive

### 1. Consul Architecture (Client-Server)
Consul operates a cluster consisting of **Servers** and **Clients**.
*   **Consul Servers:** Maintain the cluster state, store the KV data, handle replication using the Raft consensus algorithm, and respond to queries. You typically need 3 or 5 servers for HA.
*   **Consul Clients (Agents):** Run on every node (VM/container) where applications run. They are lightweight. They register services, perform local health checks, and forward queries to the Servers. They communicate via a LAN Gossip protocol.

### 2. Service Discovery vs DNS
Consul provides two primary ways to discover services:
*   **HTTP API:** Applications can query `http://localhost:8500/v1/catalog/service/web` to get a JSON list of IPs for the 'web' service.
*   **DNS Interface:** Consul runs a DNS server (default port 8600). You can ping `web.service.consul`, and Consul will resolve it to the IP of a healthy web server. This requires zero code changes in legacy apps.

### 3. Consul vs etcd vs ZooKeeper
All three are distributed KV stores, but their focus differs:
*   **etcd:** Primarily the backbone of Kubernetes. Fast, simple KV store. Lacks built-in service discovery DNS or health checks out-of-the-box.
*   **ZooKeeper:** Older, Java-based, used heavily in Hadoop/Kafka ecosystems. Complex to operate.
*   **Consul:** First-class support for Service Discovery, rich health checking, multiple datacenters support, and a built-in UI.

## Step-by-Step Lab

**Scenario:** Spin up a single-node Consul server using Docker, register a dummy web service, and test DNS discovery.

**Step 1: Start Consul in Development Mode**
*Dev mode runs a single server in-memory, do not use in prod.*
```bash
docker run -d --name consul-dev -p 8500:8500 -p 8600:8600/udp hashicorp/consul agent -dev -client=0.0.0.0
# Consul UI is now available at http://localhost:8500
```

**Step 2: Create a Service Definition File**
```json
// Create web-service.json
{
  "ID": "web1",
  "Name": "web",
  "Tags": ["primary", "v1"],
  "Address": "192.168.1.50",
  "Port": 80,
  "Check": {
    "HTTP": "http://example.com/",
    "Interval": "10s"
  }
}
```
*(In reality, the Address would be your actual container/VM IP, and the check would hit an actual /health endpoint).*

**Step 3: Register the Service via HTTP API**
```bash
curl -X PUT --data-binary @web-service.json http://localhost:8500/v1/agent/service/register
```

**Step 4: Verify Service in Consul**
Open your browser to `http://localhost:8500`. Click "Services". You should see `web` passing its health check.

**Step 5: Query via Consul DNS**
We mapped Consul's DNS port 8600 to localhost. Let's query it using `dig`.
```bash
dig @127.0.0.1 -p 8600 web.service.consul
# Look at the ANSWER SECTION:
# web.service.consul.     0       IN      A       192.168.1.50
```
*Notice it returned the exact IP we registered.*

**Step 6: Write to the Key-Value Store**
```bash
curl -X PUT -d 'prod-db.example.com' http://localhost:8500/v1/kv/config/myapp/db_host
# Read it back
curl http://localhost:8500/v1/kv/config/myapp/db_host?raw
# Output: prod-db.example.com
```

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
| :--- | :--- | :--- |
| `consul agent -dev` | Starts a single-node in-memory server (for testing) | `consul agent -dev` |
| `consul members` | Lists all nodes in the Consul cluster via Gossip | `consul members` |
| `consul kv put` | Writes data to the Key-Value store | `consul kv put redis/port 6379` |
| `consul kv get` | Reads data from the KV store | `consul kv get redis/port` |
| `consul catalog services` | Lists all registered services | `consul catalog services` |
| `consul reload` | Reloads agent configuration without downtime | `consul reload` |
| `consul join` | Tells an agent to join a cluster | `consul join 10.0.0.5` |
| `dig @localhost -p 8600` | Tests DNS resolution against Consul | `dig @127.0.0.1 -p 8600 db.service.consul` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| DNS query returns NXDOMAIN | Service is failing its health check | 1. Check Consul UI.<br>2. If health check fails, Consul removes it from DNS.<br>3. Fix the underlying app or correct the health check URL in the config. |
| Agent won't join cluster | Gossip protocol (UDP 8301) blocked | 1. Ensure firewalls allow TCP/UDP 8301 between all agents and servers.<br>2. Check `consul members`. |
| Split-brain (Cluster has no leader) | Network partition or lost quorum | 1. Ensure you have 3 or 5 servers.<br>2. If 2 out of 3 fail, quorum is lost. Recover via `peers.json` manual intervention. |
| `rpc error: No cluster leader` | Servers have not elected a leader | 1. Check server logs.<br>2. Ensure `--bootstrap-expect` is set correctly on servers (e.g., 3). |
| Apps not dynamically updating configs | App not watching KV changes | 1. Use a tool like `consul-template` to rewrite config files and reload apps when KV data changes. |

## Real-World Job Scenario

**Scenario:** A company has an application that connects to a Master Database. When the Master fails, the DBA promotes the Replica to Master. However, someone has to manually update the config files on 50 web servers with the new DB IP and restart them.

*   **Junior Engineer's Action:** Writes an Ansible playbook to automate pushing the new IP to all 50 servers. It's faster than manual, but still requires human intervention to trigger the playbook, causing 5 minutes of downtime.
*   **Senior Engineer's Action:** Implements Consul. The DB promotion script simply updates a key in Consul KV: `consul kv put config/db_primary_ip 10.x.x.x`. The web servers run `consul-template` in the background, which watches this key. The moment the key changes, `consul-template` rewrites the web server config locally and reloads the web process. Zero-touch, sub-second failover.

## Interview Questions

1.  **Q: How does Consul handle Service Discovery?**
    *   **A:** Services register themselves with the local Consul agent. Consul aggregates this globally. Other services can then find instances by querying Consul's HTTP API or using Consul's built-in DNS server (e.g., querying `app.service.consul`).
2.  **Q: What is the purpose of Health Checks in Consul?**
    *   **A:** Health checks ensure that Consul only routes traffic to healthy service instances. If an instance's health check fails, Consul immediately removes it from the DNS responses and API results, preventing failed requests.
3.  **Q: Explain the difference between Consul Servers and Consul Clients (Agents).**
    *   **A:** Servers are the brain; they hold the KV data, manage the Raft consensus, and maintain cluster state (require 3-5 nodes). Clients run on every compute node; they are lightweight, handle local health checks, register services, and forward queries to the Servers.
4.  **Q: What is a Gossip protocol, and how does Consul use it?**
    *   **A:** Gossip is a peer-to-peer communication protocol where nodes share information with random neighbors, quickly propagating data across the cluster. Consul uses it (via Serf) to manage cluster membership, detect node failures quickly, and broadcast events without putting load on the central Servers.
5.  **Q: Why use Consul KV over standard environment variables for configuration?**
    *   **A:** Environment variables require a container restart to update. Consul KV allows for dynamic, real-time configuration changes. Combined with tools like `consul-template`, applications can update their configuration on the fly without downtime.

## Related Notes
- [[Master Index]]
- [[KUBERNETES-04 Services and Ingress]]
- [[TERRAFORM-01 Terraform Basics]]
