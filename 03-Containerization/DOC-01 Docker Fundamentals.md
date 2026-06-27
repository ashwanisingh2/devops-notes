---
tags: [devops, containerization, docker]
aliases: [Docker Basics]
created: 2025-06-27
status: #complete
difficulty: #beginner
cert-relevant: #none
---

# DOC-01 Docker Fundamentals

> [!abstract] Overview
> Docker revolutionized software delivery by solving the classic "it works on my machine" problem. By packaging an application alongside all its dependencies (libraries, runtimes, configurations) into a standardized unit called a container, Docker ensures that software runs identically across developer laptops, staging environments, and production servers. For DevOps, Docker is the foundational building block for modern microservices and Kubernetes orchestration.

---

## Concept Overview

- **What it is** — Docker is a platform that uses OS-level virtualization to deliver software in packages called containers. Containers share the host system's kernel but have their own isolated filesystem, processes, and network interfaces.
- **Why DevOps engineers use it** — To standardize environments. Before Docker, deploying a Python app meant manually installing the correct Python version and pip packages on the server. With Docker, you just pull and run the image; the environment comes packaged inside.
- **Where you encounter this in a real job** — Running a local PostgreSQL database for testing without installing it on your Mac, packaging a Java Spring Boot app for CI/CD, or investigating a crashed container on a production server.
- **Responsibility Split:**
  - **Junior DevOps**: Pulls images, runs containers, maps ports, and checks container logs.
  - **Mid DevOps**: Builds custom images, pushes them to private registries, and manages container resources (CPU/RAM).
  - **Senior/SRE**: Debugs underlying container runtimes (containerd/runc), optimizes host kernel parameters for container networking, and sets up high-availability registries.

*Seedha simple mein: Docker ek tiffin box (container) hai. Pehle hum khana (code) aise hi le jate the aur wo dusre ke bartan mein mix ho jata tha (dependency conflicts). Ab hum khana, chammach, aur tissue paper sab ek tight tiffin mein pack karke bhejte hain. Jisko chalana hai, bas tiffin kholo aur use karo.*

---

## Technical Deep Dive

### 1. Containers vs. Virtual Machines (VMs)
This is the most critical distinction to understand.
- **Virtual Machines** (like VMware/VirtualBox) run a full Guest Operating System on top of a Hypervisor. They are heavy, take minutes to boot, and consume gigabytes of RAM just for the OS.
- **Containers** run directly on the host's OS kernel using Linux namespaces (for isolation) and cgroups (for resource limiting). They do not boot an OS; they just start a process. They start in milliseconds, are extremely lightweight, and you can run hundreds of them on a single machine.

### 2. Docker Architecture
Docker operates on a Client-Server architecture:
1. **Docker Client**: The CLI (`docker run`, `docker build`). It sends commands to the daemon.
2. **Docker Daemon (`dockerd`)**: The background service running on the host that actually builds, runs, and manages containers.
3. **Docker Registry**: The storage location for Docker Images (e.g., Docker Hub, AWS ECR).
When you type `docker run nginx`, the Client tells the Daemon to run it. The Daemon checks locally. If not found, it pulls the image from the Registry, creates a container, and starts it.

### 3. Images, Containers, and Lifecycle
An **Image** is a read-only template containing the application. A **Container** is a running instance of an image. If an Image is the class definition, the Container is the instantiated object.
A container's lifecycle states are: `Created` (files prepared but not started) → `Running` (process active) → `Paused` (process frozen in RAM) → `Exited` (process stopped) → `Deleted` (container removed). By default, when a container exits, any data written inside it is lost unless persistent volumes are used.

---

## Step-by-Step Lab

> [!warning] Pre-requisites
> - Docker Desktop (Windows/Mac) or Docker Engine (Linux) installed
> - Terminal with Docker running (`docker info` should succeed)

### Step 1: Pull and Run a Web Server
```bash
# Run an Nginx web server, mapping host port 8080 to container port 80
# -d runs it in the background (detached mode)
docker run -d --name my-web -p 8080:80 nginx:latest

# Expected output:
# Unable to find image 'nginx:latest' locally
# latest: Pulling from library/nginx... (downloads layers)
# e4b8... (long container ID)
```
*Go to `http://localhost:8080` in your browser. You will see the Nginx welcome page.*

### Step 2: Inspecting and Viewing Logs
```bash
# See running containers
docker ps

# Check the logs of the container
docker logs my-web

# Expected output:
# CONTAINER ID   IMAGE          COMMAND                  CREATED         STATUS         PORTS                  NAMES
# e4b8...        nginx:latest   "/docker-entrypoint.…"   2 minutes ago   Up 2 minutes   0.0.0.0:8080->80/tcp   my-web
# (Logs will show the HTTP GET requests from when you visited the browser)
```

### Step 3: Executing Commands Inside the Container
```bash
# Open an interactive bash shell INSIDE the running container
docker exec -it my-web /bin/bash

# You are now inside the container! Let's change the homepage.
echo "<h1>Hello from Docker Vault!</h1>" > /usr/share/nginx/html/index.html
exit

# Refresh your browser at localhost:8080. The page has changed!
```

### Step 4: Monitoring Stats and Copying Files
```bash
# View live CPU and memory usage of the container
docker stats my-web --no-stream

# Copy a file from the host into the container (without exec)
echo "new config" > config.txt
docker cp config.txt my-web:/tmp/config.txt

# Expected output:
# CONTAINER ID   NAME      CPU %     MEM USAGE / LIMIT     MEM %     NET I/O       BLOCK I/O
# e4b8...        my-web    0.00%     2.348MiB / 7.635GiB   0.03%     1.5kB / 0B    0B / 0B
```

### Step 5: Stop and Cleanup
```bash
# Stop the container politely
docker stop my-web

# Remove the container entirely
docker rm my-web

# Verify it's gone
docker ps -a

# Expected output: Container my-web is no longer listed.
```

> [!tip] Pro Tip
> Never treat containers like VMs. Do not SSH into them to install patches or edit configurations manually in production. Containers are **ephemeral** (temporary). If you need a change, update the Dockerfile, build a new image, and replace the old container.

---

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
|---------|-------------|--------------|
| `docker run -d -p` | Starts a container in background with port mapping | `docker run -d -p 80:80 nginx` |
| `docker ps -a` | Lists all containers (running and stopped) | `docker ps -a` |
| `docker exec -it` | Runs an interactive command inside a container | `docker exec -it my-db sh` |
| `docker logs -f` | Follows the output of a container's logs live | `docker logs -f my-app` |
| `docker inspect` | Returns low-level JSON details about a container/image | `docker inspect my-web` |
| `docker stop` | Sends SIGTERM to gracefully stop a container | `docker stop my-web` |
| `docker rm` | Deletes a stopped container | `docker rm my-web` |
| `docker rmi` | Deletes a Docker image from local storage | `docker rmi nginx:latest` |
| `docker system prune`| Cleans up unused containers, networks, and images | `docker system prune -a` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| `docker: Error response from daemon: port is already allocated.` | Another app on the host is using the requested port | Run `sudo netstat -tulpn | grep <port>` to find what's using it, or change the left-side mapping: `-p 8081:80` |
| Container starts then exits immediately (`Exited (0)`) | No foreground process to keep it alive | A container dies when its main command finishes. If running a script, use a blocking command or `-itd` |
| `Cannot connect to the Docker daemon. Is the docker daemon running?` | Docker service is down or you lack permissions | Run `sudo systemctl start docker` and ensure your user is in the `docker` group (`sudo usermod -aG docker $USER`) |
| `docker logs` shows nothing, but app is failing | App logs to a file instead of stdout/stderr | Docker only captures stdout/stderr. Modify the app to log to console, or symlink the log file to `/dev/stdout` |
| `No space left on device` when building/pulling | Docker has filled up `/var/lib/docker/` | Run `docker system prune -a --volumes` to aggressively clean up dangling images and stopped containers |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A developer built a Python tool locally, but when they send it to QA, it fails with a 'missing library: pandas' error."

**What Junior DevOps Does:**
Logs into the QA server manually, runs `pip install pandas`, and tells QA to try again. Tomorrow, another library is missing, and the cycle repeats.

**Escalation Trigger:**
The QA team wants to test the app on 5 different servers, and manually installing pip packages on all of them is impossible and error-prone.

**Senior Engineer Resolution:**
1. Stops treating servers like pets.
2. Writes a `Dockerfile` for the Python app that clearly defines `pip install -r requirements.txt`.
3. Builds the image: `docker build -t my-python-app:v1 .`
4. Pushes it to the registry: `docker push my-registry/my-python-app:v1`
5. Tells the QA team to simply run: `docker run my-registry/my-python-app:v1`.
6. The app runs perfectly on all 5 servers instantly, because the environment (pandas) is packaged inside the container.

**Lesson Learned:**
Immutability. Never fix dependencies on the host machine. Package everything into a Docker image so the execution environment is identical everywhere.

---

## Interview Questions

**Q1 (Conceptual):** What is the exact difference between a Docker Image and a Docker Container?
**A:** An image is a read-only, immutable file containing the application code, runtime, and libraries. A container is a running, stateful instance of that image with a read-write layer on top. You can run hundreds of containers from a single image.

**Q2 (Practical):** How do you pass environment variables into a Docker container at runtime?
**A:** You can use the `-e` flag multiple times (e.g., `docker run -e DB_USER=admin -e DB_PASS=secret myapp`), or you can pass a file containing all variables using the `--env-file` flag (e.g., `docker run --env-file ./config.env myapp`).

**Q3 (Scenario-based):** You have a container that keeps crashing immediately upon startup, so you can't `exec` into it to see what's wrong. How do you debug it?
**A:** I would first use `docker logs <container_name>` to see any error output before it crashed. If there are no logs, I can override the default command to start a shell instead, allowing me to poke around: `docker run -it --entrypoint /bin/sh myimage:latest`.

**Q4 (Deep dive):** Explain what a "dangling" image is and how it gets created.
**A:** A dangling image is an image layer that has no tag and is not referenced by any container. They appear as `<none>:<none>` in `docker images`. They are typically created when you rebuild an image with the same name and tag (like `myapp:latest`); the new build gets the tag, and the old image loses its name, becoming dangling. They waste disk space and should be removed with `docker image prune`.

**Q5 (Trick/Gotcha):** Can a Docker container run a different OS kernel than the host? (e.g., Running a Windows container on a Linux host natively).
**A:** No, not natively. Containers share the host OS's kernel. A Linux host can only run Linux containers. To run a Windows container on Linux (or vice versa), you must use a Hypervisor (VM) in between to provide the correct kernel, which is what Docker Desktop does on Mac/Windows under the hood.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[03-Containerization/DOC-02 Dockerfile and Image Optimization|Dockerfile and Image Optimization]]
[[01-Linux-Foundation/LX-03 Process and System Management|Linux Process Management]] (Underlying cgroups/namespaces)
