---
tags: [devops, containerization, docker, networking, storage]
aliases: [Docker Net & Vols]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# DOC-04 Docker Networking and Volumes

> [!abstract] Overview
> Containers are ephemeral and isolated by design. Without networking, they cannot talk to the internet, databases, or each other. Without volumes, all data is permanently destroyed the moment a container stops. Mastering Docker Networking and Volumes is the bridge between running simple stateless scripts and running stateful, production-ready, interconnected microservices.

---

## Concept Overview

- **What it is** — **Networking** connects containers to each other and the outside world using different drivers (bridge, host). **Volumes** bypass the container's temporary filesystem to store data permanently on the host machine.
- **Why DevOps engineers use it** — To persist database records (using volumes) across container upgrades, and to securely route traffic between microservices without exposing private databases to the public internet (using custom networks).
- **Where you encounter this in a real job** — Recovering a Postgres database using a named volume backup, or debugging why a Node.js API container cannot resolve the IP address of a Redis container.
- **Responsibility Split:**
  - **Junior DevOps**: Maps host ports to container ports (`-p 8080:80`) and mounts local directories for dev (`-v $(pwd):/app`).
  - **Mid DevOps**: Creates custom bridge networks for DNS isolation, and manages named volumes for databases.
  - **Senior/SRE**: Uses `macvlan` for legacy network integration, writes backup automation scripts for volumes, and debugs MTU/iptables issues caused by Docker's network driver.

*Seedha simple mein: Networking matlab containers ki aapas ki mobile line. Volumes matlab containers ki permanent hard drive. Agar container (worker) mar bhi gaya, toh volume (hard drive) safe rehti hai, aur naya worker aake wahi se kaam shuru kar sakta hai.*

---

## Technical Deep Dive

### 1. Docker Network Drivers
Docker uses pluggable network drivers. The most critical ones are:
- **Bridge (Default)**: Creates a private internal network on the host. Containers on the *same* custom bridge network can resolve each other by name (DNS). Note: The default `docker0` bridge does *not* support automatic DNS resolution by container name; you must create a custom bridge network for that.
- **Host**: The container shares the host's networking namespace completely. Port 80 in the container is port 80 on the host. It removes network isolation but offers maximum performance (no NAT overhead).
- **None**: completely disables all networking for the container (used for highly secure, isolated processing).
- **Macvlan**: Assigns a real MAC address to the container, making it look like a physical device on your company's actual network.

### 2. DNS and Service Discovery
When you create a custom bridge network (`docker network create my-net`), Docker runs an embedded DNS server at `127.0.0.11` inside every container attached to it. If you have a container named `db-prod`, any other container on `my-net` can simply connect to `http://db-prod`. Docker dynamically resolves this name to the internal IP address. This is the cornerstone of microservice communication.

### 3. State Management: Volumes vs. Bind Mounts
By default, files created inside a container are stored on a writable container layer. This is slow and deleted when the container is removed. To persist data, Docker offers:
- **Named Volumes**: Managed entirely by Docker (stored in `/var/lib/docker/volumes/`). They are the most secure and performant option for production databases. Docker handles permissions and lifecycle.
- **Bind Mounts**: Mounts a specific file or directory from your host machine (e.g., `/home/user/code`) into the container. Excellent for local development (live-reloading code) but terrible for production due to host filesystem dependency and permission nightmares.
- **tmpfs**: Mounts data strictly in RAM. Fast and secure for sensitive data (secrets, keys), but lost on container stop.

---

## Step-by-Step Lab

> [!warning] Pre-requisites
> - Docker Engine installed
> - Terminal access

### Step 1: Network Isolation and DNS
```bash
# Create a custom bridge network
docker network create my-custom-net

# Run a detached container on this network named 'db'
docker run -d --name my-db --network my-custom-net nginx:alpine

# Run a temporary troubleshooting container to ping the 'db' by NAME
docker run --rm -it --network my-custom-net alpine sh -c "ping -c 3 my-db"

# Expected output:
# PING my-db (172.18.0.2): 56 data bytes
# 64 bytes from 172.18.0.2: seq=0 ttl=64 time=0.081 ms
```
*Notice it resolved `my-db` to an IP automatically!*

### Step 2: Bind Mounts (Local Development)
```bash
# Create a local file
echo "Hello from Host" > index.html

# Run Nginx, mounting the current directory to Nginx's html folder
docker run -d --name bind-web -v $(pwd):/usr/share/nginx/html -p 8080:80 nginx:alpine

# Change the file on the host
echo "Updated live!" > index.html

# The container sees the change instantly (test via curl localhost:8080)
docker rm -f bind-web
```

### Step 3: Named Volumes (Production Persistence)
```bash
# Create a named volume for a database
docker volume create pg-data

# Run Postgres, attaching the volume to the data directory
docker run -d --name pg-db \
  -e POSTGRES_PASSWORD=secret \
  -v pg-data:/var/lib/postgresql/data \
  postgres:14-alpine

# Wait a few seconds, then kill and remove the container
docker stop pg-db && docker rm pg-db

# Expected output: Container is gone, but volume 'pg-data' remains safely on disk.
```

### Step 4: Restoring the Volume
```bash
# Run a BRAND NEW postgres container, but attach the OLD volume
docker run -d --name pg-db-new \
  -e POSTGRES_PASSWORD=secret \
  -v pg-data:/var/lib/postgresql/data \
  postgres:14-alpine

# Expected output: The new container boots instantly with all the old data intact.
```

### Step 5: System Cleanup
```bash
# Volumes take up huge amounts of space. Clean up unused ones:
docker volume prune -f

# Expected output:
# Deleted Volumes: (lists any volumes not attached to a container)
```

> [!tip] Pro Tip
> When troubleshooting networking, use the `docker inspect <container_name>` command and scroll to the `"Networks"` section. It will show you the exact internal IP address, Gateway, and MAC address assigned to the container on that specific network.

---

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
|---------|-------------|--------------|
| `docker network create` | Creates a new custom bridge network | `docker network create backend-net` |
| `docker network ls` | Lists all Docker networks on the host | `docker network ls` |
| `docker network connect` | Attaches a running container to a network | `docker network connect backend-net web1` |
| `docker volume create` | Creates a persistent named volume | `docker volume create db-data` |
| `docker volume ls` | Lists all named volumes | `docker volume ls` |
| `docker volume prune` | Deletes all volumes NOT attached to a container | `docker volume prune -f` |
| `docker run -v` | Mounts a volume or bind mount | `docker run -v my-vol:/app/data nginx` |
| `docker run --network` | Specifies which network to join on startup | `docker run --network host nginx` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| Containers can ping IPs but not names (DNS failing) | Using the default `docker0` bridge network | Docker's default bridge does not support DNS resolution. Create a custom network and attach containers to it. |
| `Permission denied` when accessing files in a Bind Mount | Host user UID doesn't match container user UID | `chown` the host directory to match the UID expected inside the container (often 1000 or 999 for DBs). |
| Port mapping ignores UFW/firewall rules and exposes DB to internet | Docker manipulates `iptables` directly | Never expose DB ports (`-p 3306:3306`) in production. If you must, bind to localhost: `-p 127.0.0.1:3306:3306`. |
| Cannot delete a volume | A stopped/hidden container is still claiming it | Run `docker ps -a` to find the stopped container, `docker rm` it, then try `docker volume rm` again. |
| `docker: Error response from daemon: network not found` | Network was pruned or deleted | Recreate it using `docker network create <name>`. Compose usually handles this automatically. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A developer deployed a MySQL container to a staging server. The server rebooted after a kernel patch. When it came back online, the database was completely empty. A week of staging data is gone."

**What Junior DevOps Does:**
Checks the container logs, sees a fresh MySQL initialization, and panics. Realizes the developer ran `docker run -d --name mysql -e MYSQL_ROOT_PASSWORD=pass mysql` without any `-v` volume flag. The data died with the container.

**Escalation Trigger:**
The data is unrecoverable, but they need to ensure this catastrophic failure never happens in production.

**Senior Engineer Resolution:**
1. Enforces a policy that all stateful containers must use Named Volumes.
2. Updates the run command/compose file: `-v mysql-staging-data:/var/lib/mysql`.
3. Writes a cron job script to safely back up the named volume nightly: 
   `docker run --rm -v mysql-staging-data:/data -v /host/backup:/backup alpine tar -czf /backup/mysql_backup.tar.gz -C /data .`
4. Now, even if the container is deleted, the data lives safely in `/var/lib/docker/volumes/` and is zipped nightly.

**Lesson Learned:**
Containers are disposable; data is not. Never run a stateful application (database, message queue, file storage) without an explicit Volume strategy.

---

## Interview Questions

**Q1 (Conceptual):** What is the difference between a Bind Mount and a Named Volume?
**A:** A Bind Mount maps a specific, absolute path from the host (like `/home/user/app`) directly into the container. It depends heavily on the host's directory structure and OS permissions. A Named Volume is entirely managed by Docker, stored securely in Docker's internal directories (`/var/lib/docker/volumes`), and is independent of the host's specific filesystem structure, making it much safer and more portable for production data.

**Q2 (Practical):** You have a Frontend container and a Backend container. How do you ensure the Frontend can talk to the Backend, but the Backend cannot be accessed directly from the host or internet?
**A:** I would create a custom bridge network (`docker network create my-app-net`). I would attach both containers to it. For the Backend, I would NOT use the `-p` flag to publish any ports to the host. The Frontend can still reach the Backend via its container name over the private network, but the host/internet cannot reach the Backend.

**Q3 (Scenario-based):** You want to run a network packet sniffer container (like Wireshark/tcpdump) to monitor all traffic on the physical host machine. Which network driver should you use?
**A:** I would use the `host` network driver (`--network host`). This removes network isolation, placing the container directly in the host's networking namespace, allowing it to see all traffic entering and leaving the host's physical network interfaces.

**Q4 (Deep dive):** Explain how Docker's iptables manipulation can cause severe security risks on a public-facing server.
**A:** When you use `-p 8080:80`, the Docker daemon automatically modifies the Linux `iptables` rules (specifically the DOCKER chain in the nat table) to route traffic to the container. These rules execute *before* standard UFW (Uncomplicated Firewall) rules. This means even if you block port 8080 in UFW, Docker bypasses it, inadvertently exposing the container to the public internet.

**Q5 (Trick/Gotcha):** Can you mount the exact same Named Volume to three different running containers simultaneously?
**A:** Yes, Docker allows multiple containers to mount the same named volume simultaneously. However, this is extremely dangerous if the application inside the container isn't designed for concurrent writes (like a standard SQLite or MySQL database). It will lead to file corruption. It is usually only safe if mounted as Read-Only (`-v my-vol:/data:ro`).

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[03-Containerization/DOC-03 Docker Compose|Docker Compose]]
[[04-Orchestration/K8S-04 Persistent Volumes and Storage|K8S Persistent Storage]] (How Kubernetes solves the same volume problem)
