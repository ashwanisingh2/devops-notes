---
tags: [devops, git, github-advanced]
aliases: [GitHub Advanced]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# GitHub Advanced

> [!abstract] Overview
> GitHub is far more than a Git hosting platform — it is a complete DevOps ecosystem offering CI/CD (GitHub Actions), container registry (GHCR), dependency management (Dependabot), security scanning, project management, and a powerful CLI. For DevOps engineers, mastering GitHub's advanced features means you can build end-to-end pipelines, automate security patching, enforce governance, and manage infrastructure workflows — all within a single platform. This note covers the tools and configurations that separate a basic GitHub user from a DevOps professional.

---

## Concept Overview

- **What it is** — GitHub is a cloud-based Git hosting platform by Microsoft that provides version control, collaboration features, and a complete DevOps toolchain including CI/CD, security scanning, package registry, and project management.
  *GitHub ek online platform hai jahan aapka code rehta hai aur saath mein CI/CD pipeline, security scanning, aur project management bhi milta hai — jaise ek shopping mall mein sab kuch ek jagah mil jaaye.*

- **Why DevOps engineers use it** — GitHub Actions replaces the need for external CI/CD tools (Jenkins, CircleCI) for many teams. GHCR hosts container images. Dependabot auto-updates dependencies. Security alerts catch vulnerabilities. The `gh` CLI automates workflows from the terminal.
  *DevOps engineer ke liye GitHub ek Swiss Army knife hai — pipeline banana ho, container image store karna ho, ya security fix karna ho, sab ek jagah hota hai.*

- **Where it fits** — GitHub spans the Source, Build, Test, and partially the Deploy stages of the DevOps lifecycle.

- **Responsibility Split** —
  | Role | GitHub Responsibility |
  |---|---|
  | Developer | Write code, create PRs, review code, manage issues |
  | DevOps/SRE | Configure Actions workflows, manage GHCR, set up Dependabot, configure branch protection, manage secrets |
  | Security | Review Dependabot alerts, configure security policies, manage code scanning |
  | Team Lead | Manage GitHub Projects, define CODEOWNERS, set repository policies |

---

## Technical Deep Dive

### 1. GitHub Actions — CI/CD Built Into Your Repository

GitHub Actions uses **workflow files** (YAML) stored in `.github/workflows/` to automate build, test, and deploy processes.

**Workflow YAML structure:**

```yaml
# .github/workflows/ci.yml
name: CI Pipeline                    # Workflow name

on:                                  # Triggers
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  workflow_dispatch:                 # Manual trigger button

env:                                 # Global environment variables
  NODE_VERSION: '20'

jobs:                                # Jobs run in parallel by default
  build-and-test:
    runs-on: ubuntu-latest           # Runner (GitHub-hosted VM)
    
    strategy:                        # Matrix strategy for multiple versions
      matrix:
        node-version: [18, 20, 22]
    
    steps:                           # Sequential steps within a job
      - name: Checkout code
        uses: actions/checkout@v4    # Community action
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci                  # Shell command
      
      - name: Run tests
        run: npm test
      
      - name: Upload test results
        uses: actions/upload-artifact@v4
        with:
          name: test-results-${{ matrix.node-version }}
          path: coverage/

  deploy:
    needs: build-and-test            # Job dependency
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'  # Conditional execution
    
    steps:
      - name: Deploy to production
        run: echo "Deploying..."
        env:
          API_KEY: ${{ secrets.DEPLOY_API_KEY }}  # Repository secret
```

*GitHub Actions ko samjho ek factory robot ki tarah — jab bhi naya code aata hai (push/PR), robot automatically build karta hai, test karta hai, aur deploy karta hai. Workflow file robot ko instructions deti hai.*

**Key concepts:**
- **Runners** — VMs that execute your workflow (`ubuntu-latest`, `windows-latest`, `macos-latest`, or self-hosted)
- **Actions** — Reusable steps from the GitHub Marketplace (`actions/checkout@v4`, `docker/build-push-action@v5`)
- **Secrets** — Encrypted variables stored in repo settings, accessed via `${{ secrets.NAME }}`
- **Artifacts** — Files produced during workflow execution that can be downloaded or shared between jobs
- **Contexts** — Built-in variables: `github.ref`, `github.actor`, `github.event_name`, `runner.os`

### 2. GitHub Security & Packages

**GitHub Container Registry (GHCR):**

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Tag and push image
docker build -t ghcr.io/myorg/myapp:v1.0.0 .
docker push ghcr.io/myorg/myapp:v1.0.0

# Pull image
docker pull ghcr.io/myorg/myapp:v1.0.0
```

**Dependabot configuration** (`.github/dependabot.yml`):

```yaml
# .github/dependabot.yml
version: 2
updates:
  # npm dependencies
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
      timezone: "Asia/Kolkata"
    open-pull-requests-limit: 10
    reviewers:
      - "devops-team"
    labels:
      - "dependencies"
      - "automated"

  # Docker base images
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: "chore(docker):"

  # GitHub Actions versions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

*Dependabot ek watchman ki tarah hai — wo hamesha check karta rehta hai ki aapke dependencies mein koi security issue toh nahi aaya. Agar aaya toh automatically PR bana deta hai fix ke saath.*

**GitHub Security Alerts:**
- **Dependabot Alerts** — Flags vulnerable dependencies with CVE details
- **Code Scanning** — Uses CodeQL to find security bugs in your code
- **Secret Scanning** — Detects accidentally committed credentials (API keys, tokens)
- **Security Advisories** — Private space to discuss and fix vulnerabilities before disclosure

### 3. GitHub CLI & Automation

**GitHub CLI (`gh`) — essential commands:**

```bash
# Authentication
gh auth login                        # Interactive login
gh auth status                       # Check auth status

# Repository operations
gh repo create myorg/new-app --public --clone
gh repo clone myorg/existing-app
gh repo view --web                   # Open repo in browser

# Pull Request workflow
gh pr create --title "feat: add auth" --body "Adds OAuth2 login" --base main
gh pr list --state open
gh pr view 42                        # View PR #42 details
gh pr review 42 --approve
gh pr merge 42 --squash --delete-branch
gh pr checkout 42                    # Checkout PR branch locally

# Issue management
gh issue create --title "Bug: login fails" --label "bug,high-priority"
gh issue list --assignee @me
gh issue close 15 --comment "Fixed in PR #42"

# Workflow management
gh workflow list
gh workflow run ci.yml               # Manually trigger workflow
gh run list --workflow=ci.yml
gh run view 12345 --log              # View workflow run logs
```

**API basics with curl:**

```bash
# List repos for an org
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/orgs/myorg/repos

# Create an issue via API
curl -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Deploy failed","body":"Production deploy failed at step 3","labels":["bug","urgent"]}' \
  https://api.github.com/repos/myorg/app/issues

# Get PR review status
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/repos/myorg/app/pulls/42/reviews
```

**Webhooks for automation:**
Webhooks send HTTP POST requests to your server when events happen in your repository.

```json
// Webhook payload example (push event)
{
  "ref": "refs/heads/main",
  "repository": {
    "full_name": "myorg/app"
  },
  "pusher": {
    "name": "developer1"
  },
  "head_commit": {
    "message": "feat: add payment gateway"
  }
}
```

*Webhook ek doorbell ki tarah hai — jab bhi koi repo mein kuch karta hai (push, PR, issue), GitHub aapke server ka doorbell bajata hai aur batata hai kya hua. Aapka server phir action le sakta hai — jaise Slack notification bhejna ya deploy trigger karna.*

**GitHub Projects for DevOps teams:**
- Kanban boards for tracking deployments, incidents, and sprints
- Custom fields (Priority, Environment, Sprint) for DevOps-specific workflows
- Automation rules: auto-move cards when PRs are merged or issues are closed
- Views: Board view for daily standups, Table view for reporting, Timeline view for roadmap

---

## Step-by-Step Lab

### Lab: Branch Protection, Dependabot Config & First GitHub Actions Workflow

**Step 1 — Create a sample repository**

```bash
mkdir github-lab && cd github-lab
git init
echo "# GitHub Advanced Lab" > README.md
echo "node_modules/" > .gitignore
git add .
git commit -m "initial commit"

# Create GitHub repo and push
gh repo create github-lab --public --source=. --push
```

Expected output:
```
✓ Created repository youruser/github-lab on GitHub
✓ Added remote https://github.com/youruser/github-lab.git
✓ Pushed commits to https://github.com/youruser/github-lab.git
```

**Step 2 — Configure branch protection rules**

```bash
# Using gh CLI to set branch protection
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["build-and-test"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1}' \
  --field restrictions=null
```

Or via GitHub UI:
1. Go to **Settings → Branches → Add branch protection rule**
2. Branch name pattern: `main`
3. ✅ Require a pull request before merging (1 approval)
4. ✅ Require status checks to pass before merging
5. ✅ Require branches to be up to date before merging
6. ✅ Do not allow bypassing the above settings

**Step 3 — Set up Dependabot configuration**

```bash
mkdir -p .github
cat > .github/dependabot.yml << 'EOF'
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
      timezone: "Asia/Kolkata"
    open-pull-requests-limit: 5
    labels:
      - "dependencies"
    reviewers:
      - "youruser"

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    labels:
      - "ci-cd"
EOF

git add .github/dependabot.yml
git commit -m "chore: add Dependabot configuration"
```

**Step 4 — Create a sample Node.js app for the pipeline**

```bash
# Initialize package.json
cat > package.json << 'EOF'
{
  "name": "github-lab",
  "version": "1.0.0",
  "scripts": {
    "test": "node test.js",
    "start": "node app.js"
  }
}
EOF

# Create a simple app
cat > app.js << 'EOF'
const http = require('http');
const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ status: 'healthy', version: '1.0.0' }));
});
server.listen(3000, () => console.log('Server running on port 3000'));
module.exports = server;
EOF

# Create a simple test
cat > test.js << 'EOF'
const assert = require('assert');
assert.strictEqual(typeof require('./app.js'), 'object', 'App should export server object');
console.log('✅ All tests passed');
process.exit(0);
EOF

git add package.json app.js test.js
git commit -m "feat: add sample Node.js application with tests"
```

**Step 5 — Create your first GitHub Actions workflow**

```bash
mkdir -p .github/workflows

cat > .github/workflows/ci.yml << 'EOF'
name: CI Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  build-and-test:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        node-version: [18, 20]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}

      - name: Install dependencies
        run: npm install --if-present

      - name: Run tests
        run: npm test

      - name: Display Node version
        run: node --version
EOF

git add .github/workflows/ci.yml
git commit -m "ci: add GitHub Actions CI pipeline"
```

**Step 6 — Push everything and verify workflow runs**

```bash
# Push to trigger the workflow
git push origin main

# Check workflow status
gh run list --workflow=ci.yml
```

Expected output:
```
STATUS  TITLE                          WORKFLOW     BRANCH  EVENT  ID          ELAPSED
✓       ci: add GitHub Actions CI...   CI Pipeline  main    push   1234567890  45s
```

```bash
# View detailed logs
gh run view 1234567890 --log

# Or open in browser
gh run view 1234567890 --web
```

---

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
|---|---|---|
| `gh pr create` | Create a pull request | `gh pr create --title "feat: auth" --base main` |
| `gh pr merge --squash` | Squash and merge a PR | `gh pr merge 42 --squash --delete-branch` |
| `gh workflow run` | Manually trigger a workflow | `gh workflow run ci.yml --ref main` |
| `gh run list` | List recent workflow runs | `gh run list --workflow=ci.yml --limit 5` |
| `gh issue create` | Create a new issue | `gh issue create --title "Bug" --label "bug"` |
| `gh repo clone` | Clone a repository | `gh repo clone myorg/app` |
| `gh secret set` | Set a repository secret | `gh secret set DEPLOY_KEY < key.pem` |
| `gh api` | Make raw GitHub API calls | `gh api repos/myorg/app/pulls --jq '.[].title'` |
| `gh release create` | Create a GitHub release | `gh release create v1.0.0 --generate-notes` |
| `gh pr checkout` | Checkout a PR branch locally | `gh pr checkout 42` |
| `docker push ghcr.io/...` | Push image to GHCR | `docker push ghcr.io/myorg/app:v1.0.0` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---|---|---|
| `Error: Process completed with exit code 1` in Actions | A step failed (test failure, build error, command not found) | Click on the failed step in the Actions UI to see the full log. Fix the underlying issue (failing test, syntax error) and push again. Check `run:` commands work locally first. |
| `Error: Resource not accessible by integration` | GitHub Actions token (`GITHUB_TOKEN`) lacks required permissions | Add permissions block to workflow: `permissions: contents: read, packages: write`. Or go to Settings → Actions → General → Workflow permissions → Read and write. |
| `Error: denied: installation not allowed to Create` when pushing to GHCR | Token doesn't have `write:packages` scope | Generate a new PAT with `write:packages` scope. Or in Actions, add `permissions: packages: write` to the job. |
| Dependabot PRs not appearing | `dependabot.yml` has syntax errors or is in wrong location | Ensure file is at `.github/dependabot.yml` (not `.github/workflows/`). Validate YAML syntax. Check Settings → Code security → Dependabot is enabled. |
| `Error: HttpError: Branch protection rule not found` when setting protection via API | Repository is on free plan (limited protection features) or branch doesn't exist | Ensure the branch exists first (`git push origin main`). Some protection features require GitHub Pro/Team/Enterprise. |
| Workflow not triggering on push | `on.push.branches` doesn't match the branch name, or workflow file has YAML syntax errors | Check that branch name in `on:` matches exactly (case-sensitive). Validate YAML at [yamllint.com](https://yamllint.com). Check Actions is enabled in repo Settings. |
| `Error: secret not found: DEPLOY_KEY` | Secret name mismatch or secret not set for the environment | Go to Settings → Secrets and variables → Actions. Verify the secret name matches exactly (case-sensitive). If using environments, ensure secret is set on the correct environment. |

---

## Real-World Job Scenario

> **Scenario:** The company's Node.js application has 47 outdated npm dependencies, 3 critical security vulnerabilities (CVEs), and no CI/CD pipeline. The team deploys manually by SSH-ing into the server and running `git pull`.

### Junior Action ❌
- Runs `npm update` locally, fixing some packages but breaking others
- Manually updates a few critical packages one at a time
- Creates a basic GitHub Actions workflow but doesn't add tests
- Ignores Dependabot alerts because "there are too many"
- **Result:** Dependencies remain outdated, manual deploys continue, vulnerabilities stay unfixed

### Senior Action ✅

1. **Sets up Dependabot first** to get automated PRs for each dependency update:
   ```yaml
   # .github/dependabot.yml
   version: 2
   updates:
     - package-ecosystem: "npm"
       directory: "/"
       schedule:
         interval: "daily"
       open-pull-requests-limit: 10
       labels: ["dependencies"]
   ```

2. **Creates a CI pipeline** that runs tests on every PR:
   ```yaml
   # .github/workflows/ci.yml
   name: CI
   on: [pull_request]
   jobs:
     test:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: actions/setup-node@v4
           with: { node-version: '20' }
         - run: npm ci
         - run: npm test
         - run: npm audit --audit-level=high
   ```

3. **Addresses critical CVEs first** by reviewing Dependabot PRs for security updates, merging them after CI passes

4. **Sets up branch protection** requiring CI to pass before any merge to `main`

5. **Creates a CD pipeline** for automated deployment:
   ```yaml
   deploy:
     needs: test
     if: github.ref == 'refs/heads/main'
     runs-on: ubuntu-latest
     steps:
       - uses: actions/checkout@v4
       - run: npm ci --production
       - name: Deploy to server
         run: |
           echo "${{ secrets.SSH_KEY }}" > key.pem
           chmod 600 key.pem
           rsync -avz -e "ssh -i key.pem" ./ user@server:/app/
           ssh -i key.pem user@server "cd /app && pm2 restart all"
   ```

6. **Enables secret scanning** and **code scanning** in Security settings to prevent future credential leaks

*Senior engineer pehle foundation set karta hai (CI/CD + Dependabot) taaki aage ka kaam automated ho jaaye. Junior ek ek cheez manually fix karta rehta hai — yeh scalable nahi hai. DevOps ka mantra hai: pehle automation banao, phir automation kaam kare.*

---

## Interview Questions

### Q1: Explain the structure of a GitHub Actions workflow YAML file.
**Answer:** A GitHub Actions workflow has four main sections: (1) **`name`** — human-readable workflow name, (2) **`on`** — triggers that start the workflow (push, pull_request, schedule, workflow_dispatch), (3) **`env`** — global environment variables, and (4) **`jobs`** — the actual work to perform. Each job has a `runs-on` (runner), optional `strategy` (matrix builds), and `steps` (sequential tasks). Steps can be `uses:` (prebuilt actions from Marketplace) or `run:` (shell commands). Jobs run in parallel by default; use `needs:` for dependencies. Secrets are accessed via `${{ secrets.NAME }}` and must be configured in repository settings.

### Q2: What is the difference between GitHub Packages and GHCR (GitHub Container Registry)?
**Answer:** **GitHub Packages** is a generic package hosting service that supports multiple package types — npm, Maven, NuGet, RubyGems, and Docker/OCI images. **GHCR** is specifically the container registry component of GitHub Packages, accessible at `ghcr.io`. GHCR offers per-image access controls (independent of repository visibility), supports multi-architecture images, and integrates tightly with GitHub Actions via the `GITHUB_TOKEN`. You'd use GHCR for Docker images and GitHub Packages for language-specific packages.

### Q3: How does Dependabot work and why is it important for DevOps?
**Answer:** Dependabot monitors your project's dependency files (package.json, requirements.txt, Dockerfile, etc.) and checks for newer versions and known vulnerabilities. When it finds an update or security fix, it automatically creates a pull request with the version bump. For DevOps, this is critical because: (1) it automates the tedious process of keeping dependencies current, (2) it catches security vulnerabilities early through CVE database checks, (3) combined with CI, it ensures updates don't break anything before merging, and (4) it reduces the attack surface of your applications. Configuration lives in `.github/dependabot.yml` where you define ecosystems, schedules, and reviewers.

### Q4: How would you securely manage secrets in GitHub Actions?
**Answer:** Never hardcode secrets in workflow files or code. Use **GitHub Secrets** (Settings → Secrets and variables → Actions) which are encrypted at rest and masked in logs. For different environments (staging, production), use **Environment Secrets** with deployment protection rules (required reviewers, wait timers). Access secrets in workflows via `${{ secrets.NAME }}`. For advanced setups, integrate with **HashiCorp Vault** or **AWS Secrets Manager** using dedicated Actions. Additional best practices: rotate secrets regularly, use `GITHUB_TOKEN` (auto-generated, scoped per workflow) instead of PATs where possible, and never echo or log secret values.

### Q5: What are GitHub Webhooks and how would you use them in a DevOps pipeline?
**Answer:** Webhooks are HTTP callbacks — when an event occurs in your GitHub repository (push, PR opened, issue created, release published), GitHub sends an HTTP POST request with event details (JSON payload) to a URL you configure. DevOps use cases: (1) trigger Jenkins/external CI builds on push, (2) send Slack/Teams notifications when PRs are merged, (3) auto-deploy to staging when code is pushed to `develop`, (4) update a deployment dashboard, (5) trigger infrastructure provisioning when a release is created. You configure webhooks in Settings → Webhooks, specifying the payload URL, content type, secret (for HMAC signature verification), and which events to listen for.

---

## Related Notes

- [[00 DevOps Master Index]]
- [[GIT-01 Git Fundamentals]]
- [[GIT-02 Branching Strategies]]
