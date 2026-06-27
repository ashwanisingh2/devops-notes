---
tags: [devops, security, devsecops]
aliases: [DevSecOps Basics]
created: 2025-06-27
status: #complete
difficulty: #beginner
cert-relevant: #none
---

# SEC-01 DevSecOps Fundamentals

> [!abstract] Overview
> In traditional IT, the Security team was the "Department of No." They sat at the very end of the software lifecycle, running manual audits right before a release, finding 100 vulnerabilities, and blocking the deployment. This completely broke the speed of DevOps. DevSecOps is the philosophy of integrating security natively into the CI/CD pipeline, catching vulnerabilities automatically within seconds of a developer committing code. Security becomes everyone's responsibility, not just an afterthought.

---

## Concept Overview

- **What it is** — The integration of security testing, policies, and culture directly into the DevOps lifecycle.
- **Why DevOps engineers use it** — To "Shift Left." If you find a security bug in Production, it costs $10,000 to fix. If you find it in the IDE or the first CI pipeline run, it costs $10 to fix. DevSecOps automates this early detection.
- **Where you encounter this in a real job** — Blocking a Pull Request because a developer accidentally committed an AWS Secret Key, or forcing a Docker build to fail because the base image has a critical OpenSSL vulnerability.
- **Responsibility Split:**
  - **Junior DevOps**: Monitors security dashboard alerts and bumps package versions (e.g., `npm audit fix`) to resolve known CVEs.
  - **Mid DevOps**: Integrates automated scanning tools (SAST/DAST/SCA) directly into GitHub Actions or Jenkins pipelines.
  - **Senior/SRE**: Defines company-wide security policies, implements image signing (Cosign/Sigstore) for supply chain security, and architects zero-trust network boundaries.

*Seedha simple mein: Pehle security guard building ke exit gate par khada hota tha (traditional security). DevSecOps ka matlab hai ki security guard ab building banate waqt har eent (brick) ko check kar raha hai, taaki baad mein poori building todni na pade. Isey kehte hain "Shift Left" - left matlab process ke shuru mein.*

---

## Technical Deep Dive

### 1. Shift-Left Security
The software development lifecycle moves left-to-right (Plan -> Code -> Build -> Test -> Deploy -> Operate). "Shifting Left" means moving security checks as far left as possible.
- **Far Left (Code)**: IDE plugins that warn developers about SQL injection as they type.
- **Mid Left (Build/Test)**: CI pipeline failing if a vulnerable library is detected or a secret is committed.
- **Right (Operate)**: Runtimes firewalls (WAF) and Kubernetes admission controllers.

### 2. Supply Chain Attacks and SBOM
A modern application is 90% open-source libraries and 10% custom code. If a hacker breaches a popular open-source library (like `log4j` or `solarwinds`), every company using that library is breached. This is a Supply Chain Attack.
To combat this, the US Government now mandates an **SBOM (Software Bill of Materials)**. It is a formal, machine-readable inventory (JSON/XML) of every single dependency, nested dependency, and version used in your software. If a new zero-day vulnerability drops, you query your SBOMs to instantly know if you are affected.

### 3. CI/CD Security Gates
Security tools are integrated as "Gates" in the pipeline.
- **Pre-commit**: `git-secrets` or `trufflehog` scans for passwords *before* the code even leaves the developer's laptop.
- **CI Build**: SonarQube (SAST) scans the raw source code for bad logic. Trivy (SCA) scans the Docker image for vulnerable OS packages.
- If a critical vulnerability is found, the pipeline exits with `exit 1`, preventing the code from ever reaching the deployment stage.

---

## Step-by-Step Lab (Mental/Config Walkthrough)

> [!warning] Pre-requisites
> - Understanding of GitHub Actions

### Step 1: The Insecure Pipeline
Imagine a standard CI pipeline.
```yaml
# Insecure pipeline
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: docker build -t myapp .
      - run: docker push myregistry/myapp
```
This pipeline builds and pushes the image instantly. If `myapp` uses a Python library with a known Remote Code Execution (RCE) flaw, it gets deployed to production.

### Step 2: Adding a Secret Scanner (TruffleHog)
We must stop AWS keys from being committed.
```yaml
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0 # Fetch all history for all tags and branches
      
      - name: TruffleHog Secret Scan
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          head: HEAD
```
If a dev commits `AKIAIOSFODNN7EXAMPLE`, this step fails and blocks the PR.

### Step 3: Adding an Image Scanner (Trivy)
We must stop vulnerable OS packages from being pushed.
```yaml
      - run: docker build -t myapp .
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp'
          format: 'table'
          # ONLY fail the build if it's a CRITICAL vulnerability
          exit-code: '1'
          severity: 'CRITICAL,HIGH'
          
      - run: docker push myregistry/myapp
```
Now, Trivy scans the compiled image. If it finds a CRITICAL vulnerability (e.g., CVSS score 9.0+), it returns `exit 1`. The `docker push` step will never execute. The company is safe.

> [!tip] Pro Tip
> Do not set your pipeline to fail on "LOW" or "MEDIUM" vulnerabilities on day one. You will likely find hundreds of them in legacy code, and developers will be permanently blocked from deploying. This creates massive friction. Start by failing ONLY on "CRITICAL", and slowly increase strictness over time as the tech debt is paid down.

---

## Common Commands Cheat Sheet
*(Since DevSecOps is a philosophy, these are common tool CLI commands)*

| Command / Tool | What It Does | Real Example |
|----------------|-------------|--------------|
| `npm audit` | Scans Node.js `package.json` for known vulnerabilities | `npm audit fix` |
| `pip-audit` | Scans Python `requirements.txt` for vulnerabilities | `pip-audit -r reqs.txt` |
| `trivy image` | Scans a Docker image for OS and app CVEs | `trivy image nginx:latest` |
| `checkov -d .` | Scans Terraform/IaC code for misconfigurations | `checkov -d ./terraform` |
| `trufflehog` | Scans Git history for hardcoded passwords | `trufflehog git file://.` |
| `syft` | Generates an SBOM from a container image | `syft packages myapp:latest` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| Developers complaining pipeline fails constantly on false positives | Un-tuned security tools | Every SAST/SCA tool has an `.ignore` file (e.g., `.trivyignore`). If the security team reviews a vulnerability and deems it unexploitable in your specific context, add the CVE ID to the ignore list so the pipeline passes. |
| Secrets leaked to GitHub despite CI pipeline secret scanning | Scan runs *after* push | CI pipelines run *after* code hits the GitHub server. By then, hackers monitoring public repos have already stolen it. Implement client-side `pre-commit` hooks so the scan runs on the dev's laptop before `git push`. |
| Pipeline takes 30 minutes to run | Bloated security scans | Running a deep SAST scan on a 5M line monolithic codebase on every PR takes too long. Run fast scanners (SCA/Secrets) on every PR, and run heavy SAST scans nightly asynchronously. |
| 500 High vulnerabilities found in a legacy app | Outdated Base Image | Usually caused by using `FROM ubuntu:18.04` or full OS images. Change the Dockerfile to use `alpine`, `distroless`, or `-slim` variants to instantly drop the CVE count. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A massive zero-day vulnerability called 'Log4Shell' is announced on a Friday night. It affects a Java logging library. The CEO calls the DevOps team in a panic: 'Are we vulnerable? How many of our 200 microservices use Log4j?'"

**What Junior DevOps Does:**
Starts checking out all 200 Git repositories one by one, opening `pom.xml` files, hitting CTRL+F for "log4j", and making a manual Excel spreadsheet. It takes 12 hours.

**Escalation Trigger:**
The manual search is slow, error-prone, and misses nested transitive dependencies (e.g., we don't use log4j directly, but we use a library that uses a library that uses log4j).

**Senior Engineer Resolution:**
1. Because the Senior implemented DevSecOps, the CI pipeline automatically generates an SBOM (Software Bill of Materials) using `Syft` every time an image is built.
2. These SBOMs are pushed to a central metadata server (like Dependency-Track).
3. The Senior logs into Dependency-Track, types `log4j-core` into the search bar.
4. Within 5 seconds, the system lists the exact 14 microservices that contain the vulnerable version of the library, including transitive dependencies.
5. The developers patch exactly those 14 services. The company is secured in 2 hours instead of 2 days.

**Lesson Learned:**
You cannot secure what you cannot see. Automated SBOM generation is critical for rapid incident response during supply chain attacks.

---

## Interview Questions

**Q1 (Conceptual):** What does the term "Shift Left" mean in DevSecOps?
**A:** "Shift Left" refers to moving security testing and validation as early in the software development lifecycle as possible. Instead of waiting for a manual audit right before deployment (on the right side of the timeline), we integrate automated security checks into the IDE, Git hooks, and the CI build phase (on the left side) to catch issues when they are cheapest and fastest to fix.

**Q2 (Practical):** Your developers accidentally pushed an AWS Secret Key to a public GitHub repository. What is the very first thing you do?
**A:** I immediately log into the AWS Console (or use the CLI) and Deactivate/Delete that specific Access Key. I do NOT just delete the commit or make the repository private, because automated bots scrape public GitHub repos in seconds. Once the key is invalidated in AWS, then I can worry about rewriting the Git history to remove the plain-text secret.

**Q3 (Scenario-based):** You integrated a container scanner into your CI pipeline, and it's blocking a deployment because of a "High" severity CVE in a system library inside the Docker image. The application team says they don't even use that library. How do you resolve this?
**A:** I would work with the application team to modify their Dockerfile to use a minimal base image, like `alpine` or Google's `distroless` images. These images strip out all unnecessary OS packages (like bash, wget, curl, and unused system libraries). By removing the library entirely, the CVE disappears, the scanner passes, and the attack surface is permanently reduced.

**Q4 (Deep dive):** Explain the difference between SAST, DAST, and SCA.
**A:** **SAST (Static Application Security Testing)** scans the raw source code for insecure logic (like SQL injection) without running the app. **DAST (Dynamic Application Security Testing)** attacks the running, compiled application from the outside (like a hacker) to find runtime vulnerabilities. **SCA (Software Composition Analysis)** scans the `package.json` or `requirements.txt` to find known CVEs in third-party open-source libraries.

**Q5 (Trick/Gotcha):** If you use Docker, is it safe to run your application as the `root` user inside the container since it's isolated from the host OS?
**A:** No, it is absolutely not safe. While Docker provides namespace isolation, a process running as root inside a container still runs as root on the host kernel. If a hacker finds a container breakout vulnerability, they instantly have root access to the underlying Kubernetes worker node or EC2 instance. Always use the `USER` instruction in Dockerfiles to run apps as a non-privileged user.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[09-Security-DevSecOps/SEC-02 SAST DAST and Container Scanning|Deep Dive: SAST/DAST/SCA]]
[[05-CI-CD/CICD-01 CI-CD Concepts|CI/CD Concepts]]
