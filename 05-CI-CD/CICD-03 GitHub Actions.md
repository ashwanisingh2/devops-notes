---
tags: [devops, cicd, github, pipeline]
aliases: [GitHub Actions]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# CICD-03 GitHub Actions

> [!abstract] Overview
> GitHub Actions brings CI/CD directly to where your code lives. Instead of hosting and maintaining a bulky Jenkins server, GitHub provides the compute runners and the automation engine natively within the repository. For modern, cloud-native DevOps teams, GitHub Actions has become the go-to tool due to its YAML simplicity, massive open-source Actions Marketplace, and seamless integration with pull requests.

---

## Concept Overview

- **What it is** — A CI/CD and automation platform native to GitHub. Workflows are defined in YAML files stored in the `.github/workflows/` directory of a repository.
- **Why DevOps engineers use it** — Zero infrastructure management. You don't need to patch servers or manage plugins. You just write YAML, and GitHub spins up an Ubuntu VM, runs your code, and destroys the VM.
- **Where you encounter this in a real job** — Automating NPM package publishing, linting Python code on every PR, building Docker images and pushing them to GHCR (GitHub Container Registry), or automating stale issue closures.
- **Responsibility Split:**
  - **Junior DevOps**: Uses marketplace actions to setup Node/Python environments and runs test scripts.
  - **Mid DevOps**: Configures secrets, handles matrix builds across multiple OS versions, and implements caching to speed up workflows.
  - **Senior/SRE**: Manages self-hosted runners for enterprise security, writes custom Reusable Workflows to standardize company CI, and integrates OIDC (OpenID Connect) for secretless cloud authentication.

*Seedha simple mein: Pehle hum code GitHub mein rakhte the aur Jenkins ko bolte the "jaake le aa". Ab GitHub ke paas apna hi internal Jenkins hai (Actions). Aap bas ek YAML file mein bata do kya karna hai, aur GitHub PR aate hi sab apne aap test aur deploy kar dega.*

---

## Technical Deep Dive

### 1. Workflow YAML Anatomy
A workflow is defined by triggers, jobs, and steps:
- **`on` (Triggers)**: Defines *when* the workflow runs. (e.g., `push` to main, `pull_request`, or a cron `schedule`).
- **`jobs`**: A workflow contains one or more jobs. By default, multiple jobs run *in parallel*. You can force sequential execution using `needs: [job_name]`.
- **`runs-on`**: Defines the runner environment (e.g., `ubuntu-latest`, `windows-latest`, or custom self-hosted labels).
- **`steps`**: The sequential tasks within a job. A step can either run a shell command (`run: echo hello`) or use a pre-built Action from the marketplace (`uses: actions/checkout@v3`).

### 2. The Marketplace and `uses`
The biggest advantage of GHA is the open-source community. Instead of writing bash scripts to install Node.js, authenticate to AWS, or setup Docker Buildx, you just use pre-built Actions. 
For example, `uses: aws-actions/configure-aws-credentials@v2` handles all AWS auth securely in two lines of YAML.

### 3. Caching and Artifacts
Runners are ephemeral (deleted after every run). If your app needs 500MB of `node_modules`, downloading them every time wastes minutes.
- **Caching**: Use `actions/cache` to save `node_modules` across pipeline runs. If the `package-lock.json` hasn't changed, GHA pulls the cache instantly.
- **Artifacts**: If Job A builds a `.jar` file and Job B deploys it, you must use `actions/upload-artifact` in Job A and `actions/download-artifact` in Job B to pass the file between the two isolated runner VMs.

### 4. Secrets and OIDC
Never hardcode tokens. Add them to GitHub Repository Secrets (Settings -> Secrets) and reference them via `${{ secrets.MY_TOKEN }}`.
For cloud providers (AWS/GCP/Azure), the modern standard is **OIDC (OpenID Connect)**. Instead of storing long-lived AWS IAM Access Keys in GitHub, GitHub exchanges a temporary, cryptographically signed token with AWS for a short-lived session, eliminating the risk of stolen static keys.

---

## Step-by-Step Lab

> [!warning] Pre-requisites
> - A GitHub account and a repository

### Step 1: Create the Workflow File
In your repository, create the directory structure `.github/workflows/` and add a file named `ci.yml`.

```yaml
name: Node.js CI/CD Pipeline

# Trigger on push to main, or on pull requests to main
on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    
    steps:
    # 1. Pull the code from the repo
    - name: Checkout repository
      uses: actions/checkout@v4
      
    # 2. Setup Node.js environment
    - name: Use Node.js 18
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm' # Automatically handles caching!
        
    # 3. Run shell commands
    - name: Install dependencies
      run: npm ci
      
    - name: Run tests
      run: npm run test

  docker-build-push:
    # This job waits for the test job to succeed before starting
    needs: build-and-test
    # Only run this job if code was pushed to main (skip on PRs)
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    
    # Required permission to push to GHCR
    permissions:
      contents: read
      packages: write
      
    steps:
    - uses: actions/checkout@v4
    
    - name: Log in to GitHub Container Registry
      uses: docker/login-action@v3
      with:
        registry: ghcr.io
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }} # Auto-provided by GitHub!
        
    - name: Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: ghcr.io/${{ github.repository }}/my-app:latest
```

### Step 2: Push and Observe
1. Commit and push this file to your repository.
2. Go to the **Actions** tab in your GitHub repository.
3. Watch the pipeline run live. It will checkout code, install node, run tests, and (if on main branch) build and push a Docker image to your GitHub Packages tab!

> [!tip] Pro Tip
> Treat `${{ secrets.GITHUB_TOKEN }}` like magic. GitHub automatically generates this token at the start of every workflow and destroys it at the end. You can use it to authenticate to the GitHub API, checkout private submodules, or push to GHCR without ever configuring a manual secret.

---

## Common Commands Cheat Sheet

| GitHub Actions Syntax | What It Does | Example |
|-----------------------|-------------|---------|
| `on: workflow_dispatch` | Adds a button to trigger the workflow manually | `on: workflow_dispatch` |
| `on: schedule` | Runs workflow on a cron schedule | `cron: '0 0 * * *'` (Nightly) |
| `${{ github.sha }}` | Retrieves the Git commit hash of the run | `tags: myapp:${{ github.sha }}` |
| `needs: jobA` | Makes the current job dependent on jobA | `needs: lint-code` |
| `if: always()` | Runs the step even if previous steps failed | `if: always()` (Great for cleanup) |
| `matrix:` | Runs a job multiple times with different variables | `node-version: [14, 16, 18]` |
| `env:` | Sets environment variables for a job or step | `env: PORT: 8080` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| "Resource not accessible by integration" during `git push` | Token lacks permissions | By default, GITHUB_TOKEN has read-only access. Add `permissions: contents: write` at the top of the workflow or job. |
| Workflow is not triggering | Branch mismatch or wrong path | Ensure the YAML file is exactly in `.github/workflows/`. Check the `on: push: branches` block matches your branch name (`main` vs `master`). |
| "Secret not found" or variable is empty | Secret is tied to a different environment | Ensure you created a *Repository* Secret, not an *Environment* Secret (unless your job specifies `environment: prod`). |
| Job B cannot find files created in Job A | Jobs run on different runner VMs | Use `actions/upload-artifact` in Job A to save the files, and `actions/download-artifact` in Job B to retrieve them. |
| Docker build fails with "context not found" | Missing checkout | The runner starts completely empty. You MUST run `uses: actions/checkout@v4` as the very first step in *every* job that needs your code. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "We have a Python library that needs to be tested on Windows, Mac, and Linux, across Python versions 3.8, 3.9, 3.10, and 3.11."

**What Junior DevOps Does:**
Copies and pastes the job 12 times in the YAML file. Hardcodes the OS and Python version in each one. The file becomes 500 lines long and impossible to maintain.

**Escalation Trigger:**
A new Python version (3.12) is released, and the team dreads adding 3 more copy-pasted blocks to the massive file.

**Senior Engineer Resolution:**
1. Deletes the 500 lines of YAML.
2. Uses a **Build Matrix** in GitHub Actions.
3. Writes a single 20-line job:
```yaml
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        python-version: ['3.8', '3.9', '3.10', '3.11']
    steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-python@v4
      with:
        python-version: ${{ matrix.python-version }}
    - run: pytest
```
4. GitHub automatically expands this matrix and dynamically spins up 12 different runners in parallel, testing every possible combination.
5. When Python 3.12 comes out, the update requires typing 8 characters: ` , '3.12' `.

**Lesson Learned:**
Leverage platform-native features like Matrix strategies to keep CI configurations DRY (Don't Repeat Yourself).

---

## Interview Questions

**Q1 (Conceptual):** What is the difference between a GitHub Actions *Job* and a *Step*?
**A:** A *Job* is a collection of steps that run on the same runner VM. Multiple jobs run in parallel by default on entirely separate runner VMs. A *Step* is a single sequential action (like a bash command or a marketplace action) executed inside the Job's runner. Steps share the same filesystem, Jobs do not.

**Q2 (Practical):** How do you pass data (like a compiled binary) from a Build job to a Deploy job?
**A:** Since jobs run on isolated virtual machines, I must use the `actions/upload-artifact` action in the Build job to push the binary to GitHub's storage. Then, in the Deploy job, I use `actions/download-artifact` to pull the binary into the new runner's filesystem before deploying.

**Q3 (Scenario-based):** You want to reuse the exact same deployment logic across 10 different microservice repositories without copy-pasting YAML. How do you achieve this in GitHub Actions?
**A:** I would create a **Reusable Workflow**. I define a workflow in a central repository using the `on: workflow_call` trigger. The 10 microservice repositories can then invoke this central workflow in their own YAML files using `uses: my-org/central-repo/.github/workflows/deploy.yml@main`, passing in specific inputs and secrets.

**Q4 (Deep dive):** Why is configuring OIDC (OpenID Connect) with AWS considered superior to storing AWS Access Keys in GitHub Secrets?
**A:** Storing static IAM Access Keys is a severe security risk. If a key is leaked or an ex-employee retains it, it is valid forever until manually revoked. OIDC establishes a trust relationship between GitHub and AWS. When a workflow runs, it requests a temporary, short-lived STS token from AWS valid only for that specific run. There are no static credentials to store, rotate, or leak.

**Q5 (Trick/Gotcha):** If a step in your job fails (e.g., tests fail), what happens to the subsequent steps in that job?
**A:** By default, if a step fails, the entire job immediately aborts and subsequent steps are skipped. However, you can force a step to run regardless by adding `if: always()` or `if: failure()` to the step definition. This is highly useful for uploading error logs or sending failure notifications to Slack.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[05-CI-CD/CICD-01 CI-CD Concepts|CI/CD Concepts]]
[[05-CI-CD/CICD-02 Jenkins|Jenkins (Alternative Tool)]]
