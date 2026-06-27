---
tags: [devops, containerization, dockerfile, security]
aliases: [Docker Image Building]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# DOC-02 Dockerfile and Image Optimization

> [!abstract] Overview
> Writing a Dockerfile is easy; writing a *good* Dockerfile is hard. A poorly written Dockerfile results in massive 1GB+ images filled with unnecessary build tools, slow CI/CD pipelines due to broken caching, and severe security vulnerabilities because it runs as `root`. DevOps engineers must master Dockerfile instructions, multi-stage builds, layer caching, and image scanning to produce lean, fast, and secure container images.

---

## Concept Overview

- **What it is** — A `Dockerfile` is a text document containing all the commands a user could call on the command line to assemble an image. Optimization refers to techniques that reduce the final image size and build time.
- **Why DevOps engineers use it** — Smaller images mean faster downloads, quicker autoscaling, and lower storage costs. More importantly, smaller images have a drastically reduced attack surface—fewer installed packages mean fewer vulnerabilities for hackers to exploit.
- **Where you encounter this in a real job** — Refactoring a developer's messy Dockerfile, converting a Node.js build to use a multi-stage approach, or implementing Trivy scanning in the CI pipeline to block vulnerable images.
- **Responsibility Split:**
  - **Junior DevOps**: Writes basic Dockerfiles (`FROM`, `COPY`, `RUN`, `CMD`).
  - **Mid DevOps**: Implements multi-stage builds, optimizes layer caching, and configures `.dockerignore`.
  - **Senior/SRE**: Enforces non-root container policies, builds minimal distroless images, and integrates automated SBOM/vulnerability scanning.

*Seedha simple mein: Dockerfile ek recipe hai. Agar aap cake (image) banate waqt pura oven aur mixer bhi dabbe mein pack kar doge, toh dabba bhari ho jayega (bloated image). Multi-stage build ka matlab hai: kitchen mein cake banao, aur sirf final cake ko delivery dabbe mein dalo. Isse dabba halka aur fast ho jata hai.*

---

## Technical Deep Dive

### 1. Dockerfile Anatomy and The Layer Cache
Every instruction in a Dockerfile (like `RUN`, `COPY`, `ADD`) creates a new "layer" in the image. Docker caches these layers. When rebuilding, if an instruction hasn't changed, Docker reuses the cached layer, saving massive amounts of time. 
However, the cache invalidates from the point of change downwards. If you put `COPY . .` (copying all source code) *before* running `npm install` (installing dependencies), then changing one line of code will invalidate the cache for `npm install`, forcing a slow redownload of all packages every build. **Rule:** Always copy dependency manifest files first, install dependencies, and *then* copy the frequently changing source code.

### 2. CMD vs. ENTRYPOINT
These two instructions confuse many. Both dictate what runs when the container starts.
- `ENTRYPOINT` configures the container to run as an executable. It cannot be easily overridden by the user. (e.g., `ENTRYPOINT ["python", "app.py"]`).
- `CMD` provides default arguments for the executing container. It is easily overridden by appending commands to `docker run`. 
- **Combined Pattern**: Use `ENTRYPOINT` for the main binary, and `CMD` for default arguments. 
  `ENTRYPOINT ["ping"]` 
  `CMD ["localhost"]`
  Running `docker run myping` pings localhost. Running `docker run myping google.com` overrides `CMD` and pings google.com.

### 3. Multi-Stage Builds and Security (Non-Root, Distroless)
Compiling code (Java, Go, C++) requires heavy SDKs, compilers, and source files. But running the compiled binary only requires a tiny runtime environment. **Multi-stage builds** use multiple `FROM` statements. You build the app in a fat "builder" stage, and only `COPY` the final compiled binary into a tiny, fresh "runner" stage. 
For security, containers run as `root` by default. This is dangerous; a breakout vulnerability could give the attacker root access to the host. Always create a dedicated user and switch to it using the `USER` instruction. Additionally, using "distroless" base images (like Alpine or Google's distroless) removes the shell entirely, making it incredibly hard for hackers to execute malicious commands.

---

## Step-by-Step Lab

> [!warning] Pre-requisites
> - Docker installed locally
> - Basic understanding of Node.js or simply the ability to copy-paste code

### Step 1: Write a "Bad" (Bloated) Dockerfile
```bash
# Create a simple dummy Node.js app
mkdir app && cd app
echo 'console.log("App is running");' > index.js
echo '{"name": "myapp", "dependencies": {"express": "^4.18"}}' > package.json

# Create a poorly optimized Dockerfile
cat << 'EOF' > Dockerfile.bad
FROM node:18
COPY . .
RUN npm install
CMD ["node", "index.js"]
EOF

# Build it
docker build -t app-bad -f Dockerfile.bad .

# Expected output: (Build succeeds, but image is huge)
```

### Step 2: Write a "Good" (Optimized) Multi-Stage Dockerfile
```bash
# Create a multi-stage, cached, non-root Dockerfile
cat << 'EOF' > Dockerfile.good
# Stage 1: Build environment
FROM node:18-alpine AS builder
WORKDIR /app
COPY package.json ./
RUN npm install
COPY . .

# Stage 2: Production environment
FROM node:18-alpine
WORKDIR /app
# Run as non-root user (node is created by the base image)
USER node
# Only copy the node_modules and code from the builder stage
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/index.js ./
CMD ["node", "index.js"]
EOF

# Build it
docker build -t app-good -f Dockerfile.good .
```

### Step 3: Compare the Sizes
```bash
docker images | grep app-

# Expected output:
# app-bad      latest    1.1 GB
# app-good     latest    185 MB
# Notice the massive size reduction!
```

### Step 4: The .dockerignore File
```bash
# Prevent local node_modules, secrets, or git history from entering the build context
cat << 'EOF' > .dockerignore
node_modules/
.git/
.env
Dockerfile*
EOF

# If you rebuild, Docker transfers fewer files to the daemon, speeding up the build.
```

### Step 5: Scan the Image for Vulnerabilities with Trivy
```bash
# Install Trivy (Linux/Mac script, skip if you don't want to install)
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Scan the good image for CRITICAL vulnerabilities
trivy image --severity CRITICAL app-good

# Expected output:
# Total: 0 (UNKNOWN: 0, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
```

> [!tip] Pro Tip
> Never use `apt-get upgrade` in a Dockerfile. It bloats the image, breaks determinism (your image will be different tomorrow than it is today), and makes debugging impossible. Instead, pin your base image to a specific secure version (e.g., `ubuntu:22.04`) and let the base image maintainers handle the upgrades.

---

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
|---------|-------------|--------------|
| `FROM` | Defines the base image for subsequent instructions | `FROM python:3.9-alpine` |
| `WORKDIR` | Sets the working directory for RUN/CMD/COPY | `WORKDIR /app` |
| `COPY` | Copies files from host to the container | `COPY requirements.txt ./` |
| `ADD` | Like COPY, but can extract tarballs and fetch URLs | `ADD https://example.com/file .` |
| `RUN` | Executes shell commands during the BUILD process | `RUN apt-get install curl` |
| `ENV` | Sets environment variables | `ENV PORT=8080` |
| `USER` | Switches the user context for subsequent commands | `USER appuser` |
| `CMD` | The default command executed when container STARTS | `CMD ["npm", "start"]` |
| `docker build`| Builds an image from a Dockerfile | `docker build -t myapp:v1 .` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| Build takes forever, downloading packages every time | Bad layer caching order | Move `COPY package.json` and `RUN npm install` *above* `COPY . .` |
| File not found error during `COPY` | Context issue or `.dockerignore` | Ensure you run `docker build` from the correct directory. Check if the file is in `.dockerignore` |
| Container crashes immediately, logs say "Permission denied" | `USER` directive lacks rights to read/write files | Use `COPY --chown=appuser:appuser` to grant the non-root user ownership of the files |
| Large image size despite using Alpine | Multiple `RUN` commands creating phantom layers | Chain commands: `RUN apt-get update && apt-get install -y pkg && rm -rf /var/lib/apt/lists/*` |
| `CMD` command not found (e.g., `executable file not found in $PATH`) | JSON array syntax issue or missing binary | Use `CMD ["python", "app.py"]` (exec form) instead of `CMD python app.py` (shell form). Ensure python is installed |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A developer submits a Dockerfile for a Go API. The image size is 1.2GB. The security team rejects it because Trivy found 40 Critical vulnerabilities."

**What Junior DevOps Does:**
Tries to fix it by adding `RUN apt-get update && apt-get upgrade` to the Dockerfile. The image size grows to 1.5GB, and it still fails the security scan because the Go compiler itself has vulnerabilities.

**Escalation Trigger:**
The image is too large to deploy quickly, and the security team refuses to allow compilation tools inside a production environment.

**Senior Engineer Resolution:**
1. Rewrites the Dockerfile to use a Multi-Stage Build.
2. Stage 1: Uses `golang:1.20` (1GB) to compile the code (`go build -o api`).
3. Stage 2: Uses Google's `distroless/static` base image (only 2MB!).
4. Copies the compiled binary from Stage 1 to Stage 2.
5. The final image size drops from 1.2GB to 15MB.
6. The security scan returns 0 vulnerabilities because the distroless image doesn't even contain a shell, `apt`, or `bash` for hackers to exploit.

**Lesson Learned:**
Never ship your build tools to production. Compile in one stage, run in a minimal, secure stage.

---

## Interview Questions

**Q1 (Conceptual):** What is the difference between `COPY` and `ADD` in a Dockerfile?
**A:** `COPY` simply copies files from the host into the image. `ADD` does the same thing, but it has two extra features: it can automatically extract `.tar` files during the copy, and it can fetch files from remote URLs. Best practice dictates using `COPY` unless you specifically need the extraction feature of `ADD`, as `COPY` is more transparent.

**Q2 (Practical):** Your Dockerfile has `COPY . .` followed by `RUN npm install`. Why is this a bad practice for performance?
**A:** Because Docker caches layers sequentially. If you copy all source code first, ANY change to your application code (even a README update) will invalidate that layer and all subsequent layers. This forces `npm install` to run on every single build. You should copy `package.json` first, run `npm install`, and then `COPY . .`.

**Q3 (Scenario-based):** You need to install `curl` in a Debian-based Docker image. Write the optimal `RUN` command to do this without bloating the image.
**A:** The optimal command is: `RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*`. This installs curl without unnecessary side packages, and immediately deletes the apt cache in the same layer, preventing the cache from permanently increasing the image size.

**Q4 (Deep dive):** Explain the difference between `CMD` and `ENTRYPOINT` using a real-world example.
**A:** `ENTRYPOINT` defines the unchangeable main executable, while `CMD` defines the default arguments. For example, if I build an image with `ENTRYPOINT ["aws"]` and `CMD ["s3", "ls"]`, running `docker run myimage` executes `aws s3 ls`. If a user wants to check ec2 instances instead, they can run `docker run myimage ec2 describe-instances`, which overrides the `CMD` but keeps the `aws` ENTRYPOINT intact.

**Q5 (Trick/Gotcha):** Can you use `ARG` and `ENV` interchangeably?
**A:** No. `ARG` is only available during the `docker build` phase and is not present when the container actually runs. `ENV` is available during the build phase AND persists as an environment variable when the container is running. If you need a value at runtime (like a database URL), you must use `ENV`.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[03-Containerization/DOC-01 Docker Fundamentals|Docker Fundamentals]]
[[09-Security-DevSecOps/SEC-02 SAST DAST and Container Scanning|Container Scanning (Trivy)]]
