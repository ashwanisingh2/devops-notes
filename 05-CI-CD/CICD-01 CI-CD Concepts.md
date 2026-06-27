---
tags: [devops, cicd, concepts, architecture]
aliases: [CI/CD Theory]
created: 2025-06-27
status: #complete
difficulty: #beginner
cert-relevant: #aws-devops
---

# CICD-01 CI/CD Concepts

> [!abstract] Overview
> Writing code is useless if you can't deliver it to customers securely, reliably, and quickly. Continuous Integration (CI) and Continuous Deployment (CD) form the heartbeat of DevOps culture. It is the philosophy and practice of automating the software delivery lifecycle—from the moment a developer commits code to the moment it runs in production. Mastering CI/CD concepts is what separates manual sysadmins from modern DevOps engineers.

---

## Concept Overview

- **What it is** — A set of practices and automated pipelines. **CI** automates building and testing code. **CD (Delivery)** automates preparing it for release. **CD (Deployment)** automates pushing it live.
- **Why DevOps engineers use it** — Human intervention is slow and prone to error. Automated pipelines enforce quality gates (tests, security scans) and allow teams to release software multiple times a day instead of once a month.
- **Where you encounter this in a real job** — Designing the architecture of a new GitHub Actions pipeline, deciding between a Blue-Green or Canary deployment strategy for a risky release, or tracking DORA metrics to measure team velocity.
- **Responsibility Split:**
  - **Junior DevOps**: Monitors pipelines, restarts failed jobs, and fixes simple broken test dependencies.
  - **Mid DevOps**: Writes the pipeline scripts (Jenkinsfile, `.gitlab-ci.yml`), integrates Docker builds, and pushes artifacts to registries.
  - **Senior/SRE**: Architects deployment strategies (Canary/Rollbacks), integrates automated security (DevSecOps), and shifts teams from legacy branching to Trunk-Based Development.

*Seedha simple mein: CI/CD ek car manufacturing assembly line hai. Developer ne engine (code) rakha. CI usko test karega ki engine start hota hai ya nahi. CD usko car mein fit karke showroom (production) tak automatically le jayega. Koi manual driver nahi chahiye.*

---

## Technical Deep Dive

### 1. The CI/CD Pipeline Stages
A robust pipeline flows linearly through specific gates:
1. **Source**: Developer pushes code to Git. A Webhook triggers the pipeline.
2. **Build**: Code is compiled (if Java/Go) or packaged (Node.js). A Docker image is built.
3. **Test**: Unit tests and integration tests are executed. If they fail, the pipeline halts immediately (breaking the build).
4. **Scan (DevSecOps)**: Static analysis (SAST) and container vulnerability scans (Trivy) run.
5. **Push/Store**: The artifact (Docker Image or `.jar` file) is pushed to an immutable registry (like GHCR or AWS ECR).
6. **Deploy**: The artifact is pulled and deployed to Staging or Production infrastructure.

### 2. Continuous Delivery vs. Continuous Deployment
This is the most commonly confused concept in interviews.
- **Continuous Delivery**: The pipeline fully automates building, testing, and staging the code. The code is *ready* to go to production at any moment, but a human must click a manual "Approve" button to trigger the final prod deployment.
- **Continuous Deployment**: True automation. There is no human gate. If the code passes all automated tests, it goes directly to production automatically. (Requires extreme confidence in your automated testing suite).

### 3. Deployment Strategies and Feature Flags
Deploying to production is scary. We mitigate risk using strategies:
- **Recreate**: Shut down old app, start new app. (Causes downtime, rarely used).
- **Rolling Update**: Replace instances one by one. (Default in Kubernetes).
- **Blue-Green**: Run two identical environments. Blue is live (v1). Deploy v2 to Green. Test Green. Flip the load balancer to point to Green. If Green fails, flip back to Blue instantly. Zero downtime, fast rollback, but costs 2x infrastructure.
- **Canary**: Deploy v2 to a small subset of servers (or 5% of users). Monitor for errors. If healthy, slowly ramp up to 100%. (Most advanced, safest).
**Feature Flags**: A code-level strategy. You deploy unfinished code to production, but wrap it in an `if (feature_enabled)` block. The code is live, but hidden from users until you toggle the flag in a dashboard.

---

## Step-by-Step Lab (Mental Architecture)

> [!warning] Pre-requisites
> - A whiteboard or drawing tool (excalidraw.com)

### Step 1: Design the Source and CI Phase
**Action:** Draw a GitHub repository.
1. Developer opens a Pull Request.
2. GitHub Webhook triggers a CI server (e.g., Jenkins).
3. Jenkins runs `npm run test`.
4. Jenkins runs SonarQube for code quality.
*Rule:* The PR cannot be merged into `main` unless these checks pass.

### Step 2: Design the Build and Artifact Phase
**Action:** Draw the `main` branch.
1. PR is merged to `main`.
2. Pipeline triggers again.
3. Jenkins runs `docker build -t myapp:${GIT_COMMIT_HASH} .`
4. Jenkins runs `trivy image myapp:${GIT_COMMIT_HASH}` to scan for CVEs.
5. Jenkins runs `docker push` to AWS ECR.

### Step 3: Design the CD (Delivery) Phase
**Action:** Draw a Staging Kubernetes Cluster.
1. Jenkins authenticates to the Staging K8s cluster.
2. Jenkins updates the Deployment YAML to use the new `${GIT_COMMIT_HASH}` image tag.
3. Jenkins runs `kubectl apply`.
4. Automated UI tests (Selenium/Cypress) run against the staging URL.

### Step 4: Design the CD (Deployment) Phase
**Action:** Draw a Production Kubernetes Cluster and a Slack channel.
1. Pipeline halts. Sends a Slack message with an "Approve Prod Deployment" button (Continuous Delivery).
2. QA Engineer clicks Approve.
3. Jenkins updates the Production Deployment YAML using a Rolling Update strategy.
4. Pipeline completes successfully.

> [!tip] Pro Tip
> Never use mutable tags like `latest` for Docker images in your CI/CD pipelines. Always tag artifacts with the Git Commit Hash (e.g., `v1.0.0-a1b2c3d`). This guarantees absolute traceability: looking at a running container, you know exactly which line of code it came from.

---

## Common Commands Cheat Sheet
*(Note: CI/CD is tool-agnostic; these are conceptual actions implemented differently in Jenkins/GitLab/GitHub)*

| Concept / Action | What It Does | Tool Examples |
|------------------|-------------|---------------|
| `linting` | Checks code for stylistic errors before compilation | `eslint`, `flake8`, `shellcheck` |
| `unit testing` | Tests individual functions in isolation | `jest`, `pytest`, `JUnit` |
| `artifact registry` | Immutable storage for compiled binaries/images | Nexus, Artifactory, Docker Hub, ECR |
| `SAST` | Static Application Security Testing (scans code) | SonarQube, Semgrep, Checkmarx |
| `DAST` | Dynamic Application Security Testing (attacks live app) | OWASP ZAP, Burp Suite |
| `Webhook` | HTTP POST sent by Git to trigger pipelines | GitHub Webhooks |
| `DORA Metrics` | 4 key metrics to measure DevOps team performance | Deployment Frequency, Lead Time, MTTR, Change Failure Rate |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| "It works on my machine but fails in CI" | Environment mismatch | Developer is using Node v18 locally, but CI runner has Node v14. Standardize using Docker for CI build environments. |
| Pipeline is extremely slow (takes 30 mins) | Re-downloading dependencies every run | Implement caching in your pipeline tool (e.g., cache `~/.npm` or `.m2` directories). |
| Flaky Tests (fail randomly 10% of the time) | Timing issues or shared state | Tests are likely depending on external databases or network calls. Mock external services, or ensure the DB is wiped clean before every test. |
| Artifact push fails with `401 Unauthorized` | Expired or incorrect credentials | CI runners should use short-lived, dynamically generated cloud tokens (OIDC) rather than static passwords that expire. |
| Deployment to Prod caused 5 minutes of downtime | Used Recreate strategy | The pipeline tore down the old version before starting the new one. Ensure K8s is using `RollingUpdate` with proper readiness probes. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A startup is releasing features very slowly. They use 'Git Flow'—developers merge to a `develop` branch, test for 2 weeks, cut a `release` branch, fix bugs for 1 week, and finally deploy to `main`."

**What Junior DevOps Does:**
Tries to make the Jenkins pipeline run faster by upgrading the AWS EC2 runner instance to a larger size. It shaves 2 minutes off the build, but releases still take 3 weeks.

**Escalation Trigger:**
The business is losing to competitors because they cannot ship features fast enough. The CEO demands weekly releases.

**Senior Engineer Resolution:**
1. Recognizes this is a process problem, not a tooling problem.
2. Migrates the engineering team to **Trunk-Based Development**.
3. All developers must merge code directly to `main` at least once a day.
4. Enforces strict automated testing on every PR. If tests fail, it cannot merge.
5. Introduces **Feature Flags**. Developers merge half-finished features to `main`, but hide them behind a flag so users don't see them.
6. Automates the pipeline so every merge to `main` deploys to production automatically (Continuous Deployment).
7. Result: The team goes from 1 release every 3 weeks to 10 releases a day safely.

**Lesson Learned:**
CI/CD is heavily dependent on your Git Branching Strategy. Complex branching kills Continuous Delivery. Small, frequent, automated commits lead to high velocity.

---

## Interview Questions

**Q1 (Conceptual):** What are the 4 DORA Metrics, and why do they matter?
**A:** DORA (DevOps Research and Assessment) metrics are the industry standard for measuring DevOps success. 
1. **Deployment Frequency**: How often code is deployed.
2. **Lead Time for Changes**: Time from code commit to production.
3. **Change Failure Rate**: Percentage of deployments causing failures.
4. **Time to Restore Service (MTTR)**: How long it takes to recover from a failure. 
They matter because they prove that deploying *faster* actually makes systems *more stable*.

**Q2 (Practical):** Your team wants to implement a Blue-Green deployment on AWS. How do you conceptually architect this?
**A:** I would maintain two identical environments: Blue (currently active) and Green (idle). The CI/CD pipeline deploys the new version to the Green environment. We run automated integration tests against Green. Once passed, we update the AWS Application Load Balancer (ALB) or Route53 DNS record to swap the traffic from Blue to Green. If anything fails, we simply swap the load balancer back to Blue instantly.

**Q3 (Scenario-based):** A developer pushes a commit containing an AWS secret key to GitHub. The CI pipeline runs successfully and deploys to staging. How should the pipeline have prevented this?
**A:** The CI pipeline should have a "Scan" or "DevSecOps" stage early in the process that includes secret scanning tools like `git-secrets`, `trufflehog`, or GitHub Advanced Security. If a secret is detected, the pipeline must fail immediately *before* the build phase, preventing the artifact from being created or deployed.

**Q4 (Deep dive):** Explain the concept of an Immutable Artifact in CI/CD.
**A:** Immutability means an artifact (like a Docker image) is built exactly *once* and never changed. Instead of pulling code from Git on the Dev server, and then pulling code again from Git on the Prod server, the CI pipeline builds the Docker image once and pushes it to a registry. That exact same binary image is then promoted through Dev, Staging, and Prod. This guarantees that the exact code tested in QA is what runs in Prod.

**Q5 (Trick/Gotcha):** Can you achieve true Continuous Deployment (direct to production) without comprehensive automated testing?
**A:** Absolutely not. Continuous Deployment removes the human approval gate. If you do not have comprehensive, trustworthy automated unit, integration, and UI tests, you are simply automating the deployment of broken code and bugs directly to your customers at high speed. Robust testing is the prerequisite for CD.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[02-Version-Control/GIT-02 Branching Strategies|Branching Strategies]]
[[05-CI-CD/CICD-03 GitHub Actions|GitHub Actions (Implementation)]]
