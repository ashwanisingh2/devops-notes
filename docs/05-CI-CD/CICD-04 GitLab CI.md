---
tags: [devops, cicd, gitlab, pipeline]
aliases: [GitLab CI]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# CICD-04 GitLab CI

> [!abstract] Overview
> GitLab CI is arguably the most seamless, all-in-one DevOps platform available today. Unlike Jenkins, which requires a separate server, or GitHub Actions, which focuses heavily on marketplace plugins, GitLab natively integrates the Git repository, CI/CD pipelines, container registry, and security scanning into a single application. Its `.gitlab-ci.yml` syntax is elegant, powerful, and built specifically for modern containerized workflows.

---

## Concept Overview

- **What it is** — The continuous integration and delivery engine built directly into GitLab. Pipelines are defined using a `.gitlab-ci.yml` file placed at the root of the repository.
- **Why DevOps engineers use it** — Simplicity and ecosystem integration. Because the Git repo and the CI tool are the same software, merging code, running pipelines, pushing Docker images to the built-in registry, and viewing deployment environments all happen in one unified dashboard.
- **Where you encounter this in a real job** — Writing a `.gitlab-ci.yml` for a microservice, registering a new GitLab Runner on an AWS EC2 instance, or defining manual approval rules for production deployments.
- **Responsibility Split:**
  - **Junior DevOps**: Monitors the pipeline UI, handles basic test failures, and uses the GitLab Container Registry to pull images locally.
  - **Mid DevOps**: Writes `.gitlab-ci.yml` scripts, manages artifacts/caching, and defines dynamic environments.
  - **Senior/SRE**: Manages fleet of auto-scaling GitLab Runners on Kubernetes, writes shared CI templates using `include`, and enforces pipeline security policies at the Group level.

*Seedha simple mein: GitLab CI ek "All-in-One" package hai. Jaise ek smartphone mein camera, phone, aur internet sab hota hai, waise hi GitLab mein code storage (Git), pipeline (CI/CD), aur image storage (Registry) sab ek hi jagah hota hai. Bahar se kuch install nahi karna padta.*

---

## Technical Deep Dive

### 1. The .gitlab-ci.yml Anatomy
A GitLab pipeline is structured using **Stages** and **Jobs**.
- **`stages:`**: Defines the chronological order (e.g., `build`, `test`, `deploy`).
- **Jobs**: Defined individually. Each job specifies which `stage` it belongs to and what `script` (commands) it should execute.
Jobs in the *same* stage run in parallel. Jobs in the *next* stage wait until the previous stage completely succeeds.

### 2. GitLab Runners and Executors
GitLab.com hosts the web interface, but the actual pipeline execution happens on **Runners**. You can use shared runners provided by GitLab, or host your own (Self-Hosted Runners).
When you register a runner, you choose an **Executor**:
- **Shell**: Runs commands directly on the host OS. (Insecure, messy).
- **Docker**: The most common. The runner spins up a specific Docker image (e.g., `image: python:3.9`), runs your scripts inside it, and throws it away. Clean and reproducible.
- **Kubernetes**: The runner talks to K8s to spin up a pod for every job, scaling infinitely.

### 3. Artifacts, Caching, and Needs
- **Artifacts**: Files created by a job (like a compiled `.jar`) that are passed to *subsequent stages* and can be downloaded from the UI.
- **Cache**: Files (like `node_modules/`) kept between pipeline runs to speed up the process. Caching is not for passing built code to the next stage.
- **Needs**: By default, a stage waits for the *entire* previous stage to finish. Using `needs: [job_name]`, you can create a Directed Acyclic Graph (DAG), allowing Job C to start the second Job A finishes, even if Job B is still running.

---

## Step-by-Step Lab

> [!warning] Pre-requisites
> - A GitLab account (free tier)
> - A new repository created on GitLab

### Step 1: Create a Python Flask App
```bash
# Locally, create the files
echo "from flask import Flask; app = Flask(__name__); @app.route('/')\ndef hello(): return 'Hello from GitLab!'\nif __name__ == '__main__': app.run(host='0.0.0.0')" > app.py
echo "flask==2.2.2" > requirements.txt
```

### Step 2: Write the .gitlab-ci.yml
```yaml
# Create .gitlab-ci.yml
stages:
  - test
  - build
  - deploy

# Define a global image for all jobs unless overridden
image: python:3.9-slim

variables:
  # Built-in variable for the GitLab registry URL
  IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA

test_app:
  stage: test
  script:
    - pip install -r requirements.txt
    - python -m py_compile app.py
    - echo "Tests passed!"

build_image:
  stage: build
  # Override image to use Docker-in-Docker for building images
  image: docker:20.10.16
  services:
    - docker:20.10.16-dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build -t $IMAGE_TAG .
    - docker push $IMAGE_TAG

deploy_staging:
  stage: deploy
  environment:
    name: staging
    url: https://staging.example.com
  script:
    - echo "Deploying $IMAGE_TAG to Staging Server..."
    # Real deploy command would go here (e.g., ssh or kubectl)
    
deploy_prod:
  stage: deploy
  environment:
    name: production
  script:
    - echo "Deploying $IMAGE_TAG to Production!"
  # This makes the job pause and wait for a human to click 'Play' in the UI
  when: manual
  # Only allow this on the main branch
  only:
    - main
```

### Step 3: Add Dockerfile
```dockerfile
FROM python:3.9-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["python", "app.py"]
```

### Step 4: Push and Verify
1. Commit all 4 files (`app.py`, `requirements.txt`, `Dockerfile`, `.gitlab-ci.yml`) and push to GitLab.
2. Go to **CI/CD -> Pipelines** in the GitLab sidebar.
3. You will see the pipeline running. It will test, build, and deploy to staging.
4. The `deploy_prod` job will have a "Pause/Play" icon waiting for manual intervention.
5. Check **Packages & Registries -> Container Registry** to see your pushed Docker image!

> [!tip] Pro Tip
> Notice the `$CI_REGISTRY_USER` and `$CI_REGISTRY_PASSWORD` variables in the build job. You don't have to configure these in the UI! GitLab injects them automatically during the pipeline run to allow you to authenticate to the built-in Container Registry.

---

## Common Commands Cheat Sheet

| GitLab YAML Keyword | What It Does | Real Example |
|---------------------|-------------|--------------|
| `image:` | Defines the Docker container the script runs inside | `image: node:18-alpine` |
| `script:` | The shell commands executed by the runner | `script: - npm install` |
| `variables:` | Defines custom environment variables | `variables: DB_HOST: "localhost"` |
| `artifacts:paths:` | Saves files/folders to pass to the next stage | `artifacts: paths: [ "build/" ]` |
| `cache:key:` | Caches directories (like node_modules) between runs | `cache: key: $CI_COMMIT_REF_SLUG` |
| `only:` / `except:` | Restricts when a job is created (Branch filters) | `only: - master` |
| `when: manual` | Requires a user to click a button to start the job | `when: manual` |
| `include:` | Imports YAML from another file or repository | `include: - project: 'my/ci' file: 'tmpl.yml'` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| "Cannot connect to the Docker daemon" in build job | Missing DinD service | When building Docker images inside GitLab CI using a Docker executor, you must include `services: - docker:dind`. |
| Pipeline stuck on "Pending" | No available runners match tags | Check if you have shared runners enabled, or if your specific job has `tags: [my-runner]` but no runner with that tag is online. |
| Job B cannot find the `.zip` file created in Job A | Missing artifact definition | You must explicitly define `artifacts: paths: - my-file.zip` in Job A for it to be passed to Job B. |
| `bash: command not found` | Wrong base image | If your script uses `curl`, but you are using `image: alpine`, `curl` might not be installed. Change the image or add `apk add curl`. |
| Production job runs automatically on every commit | Missing branch restrictions | By default, jobs run on every branch. Use `rules: - if: $CI_COMMIT_BRANCH == 'main'` to restrict it. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "We have 20 different Node.js microservices. Right now, every repository has a massive 300-line `.gitlab-ci.yml` file. When the security team mandates a new SonarQube scanning step, someone has to manually update 20 repositories."

**What Junior DevOps Does:**
Opens 20 Merge Requests, copy-pasting the new SonarQube job into all 20 `.gitlab-ci.yml` files. Next month, the SonarQube server IP changes, and they have to do it all over again.

**Escalation Trigger:**
Maintaining duplicate CI/CD logic across dozens of repos is unsustainable, error-prone, and impossible to audit.

**Senior Engineer Resolution:**
1. Creates a central repository called `gitlab-ci-templates`.
2. Writes a highly parameterized YAML file (`nodejs-standard-pipeline.yml`) containing the Build, Test, SonarQube, and Deploy jobs.
3. In the 20 microservice repositories, deletes the 300 lines of YAML and replaces it with 4 lines:
```yaml
include:
  - project: 'my-company/devops/gitlab-ci-templates'
    file: '/nodejs-standard-pipeline.yml'
```
4. Now, when a pipeline rule changes, the Senior engineer updates the central template *once*, and all 20 microservices instantly inherit the new pipeline architecture on their next run.

**Lesson Learned:**
Treat CI/CD pipelines as code. Follow the DRY (Don't Repeat Yourself) principle. Use GitLab's `include` feature to build modular, centralized pipelines.

---

## Interview Questions

**Q1 (Conceptual):** What is the difference between `cache` and `artifacts` in GitLab CI?
**A:** `cache` is used to store dependencies (like `node_modules` or `.m2`) to speed up future pipeline runs. It is not guaranteed to exist (it can be cleared). `artifacts` are used to pass intermediate build results (like a compiled binary or test coverage report) between stages of the *same* pipeline run, and they are guaranteed to be available for download from the UI.

**Q2 (Practical):** Your deployment job should only execute if the pipeline is running on the `main` branch, AND it requires manual approval. How do you configure this?
**A:** I would configure the job with two rules: `only: - main` (or using the modern `rules` syntax: `if: $CI_COMMIT_BRANCH == 'main'`), and `when: manual`. This ensures the job only appears on the `main` branch, and sits in a paused state until clicked.

**Q3 (Scenario-based):** You register a shell executor runner on your own EC2 instance, but the pipeline fails because it says `permission denied` when trying to run `docker build`. Why?
**A:** The shell executor runs jobs as the `gitlab-runner` user on the host OS. This user does not have permission to communicate with the Docker daemon socket by default. I need to SSH into the EC2 instance and run `sudo usermod -aG docker gitlab-runner` to fix it.

**Q4 (Deep dive):** Explain how GitLab CI utilizes Docker-in-Docker (DinD) and why it's necessary for building container images.
**A:** When using a Docker executor, the runner spins up a container to execute the job script. If that script contains `docker build`, the container needs access to a Docker daemon. DinD solves this by spinning up a *second* container (the `docker:dind` service) running the daemon alongside the job container. They communicate over a virtual network, allowing the job container to build images securely without mounting the host's underlying Docker socket.

**Q5 (Trick/Gotcha):** If Job A in the `build` stage fails, will Job B in the `deploy` stage run? Can you override this behavior?
**A:** By default, no. A stage acts as a strict barrier; if any job in a previous stage fails, subsequent stages are cancelled. However, you can override this by adding `allow_failure: true` to Job A. If Job A fails, the pipeline will show an orange warning icon, but it will proceed to the `deploy` stage anyway.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[05-CI-CD/CICD-01 CI-CD Concepts|CI/CD Concepts]]
[[03-Containerization/DOC-02 Dockerfile and Image Optimization|Building Images]]
