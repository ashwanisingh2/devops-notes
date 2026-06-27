---
tags: [devops, containerization, docker-compose]
aliases: [Docker Compose]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# DOC-03 Docker Compose

> [!abstract] Overview
> Modern applications rarely consist of just one container. A standard web application requires a frontend, a backend API, a database, and perhaps a caching layer like Redis. Managing 4-5 long `docker run` commands with complex network flags is tedious and error-prone. Docker Compose solves this by allowing you to define multi-container applications in a single declarative YAML file, bringing up the entire stack with one command.

---

## Concept Overview

- **What it is** — A tool for defining and running multi-container Docker applications. It uses a `docker-compose.yml` file to configure application services, networks, and volumes.
- **Why DevOps engineers use it** — To standardize local development environments and simple deployments. Instead of writing a bash script full of `docker run` commands, you write a clean YAML file that anyone on the team can run with `docker compose up`.
- **Where you encounter this in a real job** — Setting up a local testing environment that mirrors production (e.g., spinning up Kafka, Zookeeper, and Postgres simultaneously on your laptop).
- **Responsibility Split:**
  - **Junior DevOps**: Runs `docker compose up/down` and views aggregated logs.
  - **Mid DevOps**: Writes the `docker-compose.yml` for multi-tier apps, manages `.env` files, and configures persistent volumes.
  - **Senior/SRE**: Uses `docker-compose.override.yml` for dev vs prod parity, implements strict healthchecks, and manages compose profiles.

*Seedha simple mein: Docker ek akela worker (container) hai. Docker Compose ek manager hai. Agar aapko ek web app chalani hai jisme database aur frontend dono hain, toh Compose ko ek YAML list de do. Wo automatically pehle DB start karega, phir frontend, aur dono ko ek network se connect kar dega.*

---

## Technical Deep Dive

### 1. Anatomy of docker-compose.yml
A compose file is divided into three main root blocks:
- `services`: Defines the actual containers (e.g., `web`, `db`, `redis`). Each service defines the image to use, ports to expose, and environment variables.
- `networks`: Defines custom networks. If omitted, Compose automatically creates a default bridge network, placing all services on it so they can communicate using their service names (DNS).
- `volumes`: Defines persistent named volumes so data isn't lost when containers are destroyed.

### 2. Dependencies and Healthchecks
Just putting `depends_on: db` inside the `web` service tells Compose to start the `db` container first. However, the `web` container might still crash if the database takes 10 seconds to fully boot its internal engine. 
To solve this, we use `healthcheck`. You define a command (like `pg_isready`) inside the `db` service. Then, in the `web` service, you use `depends_on: db: condition: service_healthy`. This guarantees the web app only starts when the database is actually ready to accept connections.

### 3. Environment Variables, Overrides, and Profiles
Managing secrets is crucial. Instead of hardcoding passwords in YAML, use `env_file: .env` to inject variables. 
For different environments (Dev vs Prod), you use overrides. Docker Compose automatically reads `docker-compose.override.yml` if it exists, merging it over the base file. You can use this to expose ports in Dev that you keep hidden in Prod.
**Profiles** allow you to selectively run services. For example, assigning a `profile: ["debug"]` to a heavy monitoring container means it won't start unless you explicitly run `docker compose --profile debug up`.

---

## Step-by-Step Lab

> [!warning] Pre-requisites
> - Docker and Docker Compose installed

### Step 1: Create the Project Directory and Env File
```bash
mkdir 3-tier-app && cd 3-tier-app
echo "POSTGRES_PASSWORD=supersecret" > .env
echo "DB_HOST=db" >> .env
```

### Step 2: Write the docker-compose.yml
```yaml
# Create docker-compose.yml
cat << 'EOF' > docker-compose.yml
version: '3.8'

services:
  # 1. Reverse Proxy
  proxy:
    image: nginx:alpine
    ports:
      - "80:80"
    depends_on:
      - api

  # 2. Node.js API (using a dummy image for lab)
  api:
    image: node:18-alpine
    command: sh -c "sleep 3600" # Dummy command to keep it alive
    environment:
      - DB_HOST=${DB_HOST}
      - DB_PASS=${POSTGRES_PASSWORD}
    depends_on:
      db:
        condition: service_healthy

  # 3. PostgreSQL Database
  db:
    image: postgres:14-alpine
    env_file:
      - .env
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pgdata: # Named volume for persistence
EOF
```

### Step 3: Bring Up the Stack
```bash
# Start all services in the background
docker compose up -d

# Expected output:
# Network 3-tier-app_default  Creating...
# Volume "3-tier-app_pgdata"  Creating...
# Container 3-tier-app-db-1  Starting...
# Container 3-tier-app-db-1  Healthy
# Container 3-tier-app-api-1  Starting...
# Container 3-tier-app-proxy-1  Starting...
```

### Step 4: Verify Processes and Logs
```bash
# Check the status of all services in the compose file
docker compose ps

# View aggregated logs from all 3 containers
docker compose logs -f

# Expected output:
# Logs from db, api, and proxy interleaved, prefixed with the service name.
```

### Step 5: Tear Down Safely
```bash
# Stop and remove containers and networks (keeps volumes!)
docker compose down

# If you want to wipe the database volume too:
# docker compose down -v
```

> [!tip] Pro Tip
> Never use `docker compose up` in production environments for critical workloads. Compose is great for local dev and single-server apps, but it does not auto-heal containers if the node crashes, nor does it scale across multiple servers. That is what Kubernetes is for.

---

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
|---------|-------------|--------------|
| `docker compose up -d` | Builds, (re)creates, and starts containers in background | `docker compose up -d` |
| `docker compose down -v` | Stops containers and removes networks AND volumes | `docker compose down -v` |
| `docker compose ps` | Lists containers belonging to the compose project | `docker compose ps` |
| `docker compose logs -f` | Tails aggregated logs from all services | `docker compose logs -f api db` |
| `docker compose exec` | Executes a command in a running compose service | `docker compose exec db psql -U postgres` |
| `docker compose build` | Builds or rebuilds services defined with `build:` | `docker compose build --no-cache` |
| `docker compose config` | Validates and views the final merged compose file | `docker compose config` |
| `docker compose --profile` | Runs services assigned to a specific profile | `docker compose --profile debug up -d` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| API starts but instantly crashes saying "DB Connection Refused" | Missing healthcheck | `depends_on` only waits for the DB container to *start*. Add a `healthcheck` to the DB and use `condition: service_healthy` in the API. |
| Changes in code aren't reflecting in the container | Image is cached | Run `docker compose up -d --build` to force a rebuild of the image. |
| `variable is not set. Defaulting to a blank string.` | Missing `.env` file | Ensure `.env` is in the same directory as the YAML, or pass variables inline. |
| Cannot talk to another service using `localhost` | Container isolation | Containers must talk to each other using their service name (e.g., `http://db:5432`), not `localhost`. |
| Compose file fails to validate | YAML indentation error | YAML relies strictly on spaces. Run `docker compose config` to pinpoint the syntax error. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "Developers complain that testing locally is too hard. They have to manually run a Redis container, a MySQL container, and the API, and they keep forgetting the correct port mappings."

**What Junior DevOps Does:**
Writes a bash script with `docker run ...` for Redis, MySQL, and the API. It works on Linux but breaks on a developer's Mac because of network binding differences.

**Escalation Trigger:**
Developers are losing hours every week debugging the bash script instead of writing code. The script doesn't handle database persistence, so they lose test data every reboot.

**Senior Engineer Resolution:**
1. Writes a standardized `docker-compose.yml`.
2. Includes a named volume for MySQL so test data persists.
3. Adds a `docker-compose.override.yml` strictly for developers, mapping local port `3306` directly to their machines so they can use GUI tools like DBeaver.
4. Developers now just type `docker compose up -d` and the entire perfectly-configured environment spins up in 5 seconds.

**Lesson Learned:**
Developer Experience (DevEx) is a core DevOps responsibility. Docker Compose is the ultimate tool for frictionless local development.

---

## Interview Questions

**Q1 (Conceptual):** What is the difference between `docker-compose up` and `docker-compose start`?
**A:** `up` is a comprehensive command that builds images (if missing), creates networks/volumes, and creates and starts the containers. `start` only starts containers that have *already* been created but were stopped. If the container doesn't exist yet, `start` will fail.

**Q2 (Practical):** How do you define an environment variable in Compose without hardcoding it in the YAML?
**A:** You can define a `.env` file in the same directory, which Compose reads automatically to substitute `${VAR_NAME}` in the YAML. Alternatively, you can use the `env_file: - .env` directive under a specific service to pass the whole file directly into the container.

**Q3 (Scenario-based):** You have a web service and a db service. The web service keeps failing because the database takes 15 seconds to initialize. How do you fix this natively in Compose?
**A:** I would define a `healthcheck` block inside the `db` service running a command like `pg_isready`. Then, in the `web` service, I would use `depends_on:` pointing to `db` with the `condition: service_healthy` flag. Compose will hold the web container until the DB passes the healthcheck.

**Q4 (Deep dive):** Explain how Docker Compose handles networking by default between services.
**A:** By default, Docker Compose sets up a single custom bridge network for the entire project. All services defined in the YAML are attached to this network. Compose also utilizes Docker's embedded DNS server, which maps the service names (like `db` or `api`) directly to the containers' internal IP addresses. This means `api` can simply ping `db` without knowing its IP.

**Q5 (Trick/Gotcha):** Can you scale a service to 5 instances using Docker Compose?
**A:** Yes, you can use `docker compose up --scale web=5`. However, if your `web` service has a hardcoded host port mapping (like `ports: - "80:80"`), it will fail because 5 containers cannot bind to the host's port 80 simultaneously. You must remove the host port mapping (e.g., just `ports: - "80"`) so Docker assigns random host ports, or place a load balancer service (like Nginx/HAProxy) in front of them.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[03-Containerization/DOC-01 Docker Fundamentals|Docker Fundamentals]]
[[03-Containerization/DOC-04 Docker Networking and Volumes|Docker Networking and Volumes]]
