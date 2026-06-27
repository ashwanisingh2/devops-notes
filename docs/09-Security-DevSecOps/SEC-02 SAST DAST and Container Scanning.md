---
tags: [devops, security, scanning, sast, dast, sca]
aliases: [Security Scanners]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# SEC-02 SAST DAST and Container Scanning

> [!abstract] Overview
> Understanding that you need security is the first step; knowing *how* to implement it mechanically is the second. In modern DevSecOps, we deploy a gauntlet of automated scanners that analyze code from multiple angles. SAST looks at the source code, DAST attacks the running app, SCA checks third-party dependencies, and Container Scanners check the OS layer. Combining these creates a defense-in-depth pipeline that makes it incredibly difficult for vulnerabilities to reach production.

---

## Concept Overview

- **What it is** — A suite of automated security tools categorized by *how* they look for vulnerabilities. 
  - **SAST**: Static Application Security Testing (White-box testing).
  - **DAST**: Dynamic Application Security Testing (Black-box testing).
  - **SCA**: Software Composition Analysis (Dependency checking).
- **Why DevOps engineers use it** — To automate the role of a penetration tester. Instead of paying a security firm $20,000 to find an XSS vulnerability once a year, you run open-source SAST/DAST tools on every single Pull Request, catching the bug the same day the developer writes it.
- **Where you encounter this in a real job** — Configuring a SonarQube quality gate in Jenkins, writing Semgrep rules to ban specific Python functions, or setting up OWASP ZAP to bombard a staging environment with mock attacks.
- **Responsibility Split:**
  - **Junior DevOps**: Reviews scanner reports and routes Jira tickets to the appropriate development teams.
  - **Mid DevOps**: Integrates tools (Trivy, Semgrep, Checkov) into the CI pipeline and parses their JSON/SARIF outputs.
  - **Senior/SRE**: Tunes the scanners to reduce false positives, manages the central vulnerability dashboard (like DefectDojo), and defines the "fail the build" thresholds.

*Seedha simple mein: SAST ek proofreader hai jo code ko padh ke dekhta hai ki grammar (logic) galat toh nahi hai. DAST ek chor hai jo bahar se darwaze ko dhakka maar ke dekhta hai ki lock mazboot hai ya nahi. SCA ek inspector hai jo check karta hai ki aapne jo eent (third-party library) use ki hai, usme pehle se koi crack toh nahi hai.*

---

## Technical Deep Dive

### 1. SAST (Static Analysis)
- **How it works**: Analyzes the raw source code or bytecode *without executing it*. It traces data flows (e.g., checking if a user's input from an HTTP request goes directly into a SQL query without sanitization).
- **Pros**: Finds exact line numbers. Very fast. Can be run entirely offline.
- **Cons**: High false-positive rate. Cannot find runtime or configuration issues.
- **Tools**: SonarQube, Semgrep, Checkmarx, Bandit (Python).

### 2. DAST (Dynamic Analysis)
- **How it works**: Interacts with the *running application* over the network (usually HTTP). It acts like a malicious user, sending malformed payloads, SQL injection strings, and massive payloads to see if the app crashes or leaks data.
- **Pros**: Low false positives (if it breaks the app, it's a real bug). Tests the app exactly as it runs in the real world.
- **Cons**: Very slow (a full scan can take hours). Cannot point to the exact line of code, only the vulnerable URL.
- **Tools**: OWASP ZAP, Burp Suite, Acunetix.

### 3. SCA and Container Scanning
- **SCA**: Parses package managers (`pom.xml`, `package.json`) and compares the library versions against public CVE databases (NVD). (Tools: Snyk, Dependabot).
- **Container Scanning**: Extends SCA to the OS layer. It unpacks the Docker image tarball, looks at `/var/lib/dpkg/status` or `/etc/apk`, and identifies vulnerable `glibc` or `curl` packages installed via `apt-get` or `apk`. (Tools: Trivy, Clair).

---

## Step-by-Step Lab (Trivy & Semgrep Integration)

> [!warning] Pre-requisites
> - Trivy CLI installed (`brew install trivy` or `apt-get install trivy`)
> - Docker installed

### Step 1: Scan a deliberately vulnerable Docker Image
We will use Trivy to scan an older version of Nginx that has known vulnerabilities.
```bash
# Run Trivy against the image
trivy image nginx:1.18.0

# Expected output:
# nginx:1.18.0 (debian 10.4)
# Total: 153 (UNKNOWN: 2, LOW: 94, MEDIUM: 22, HIGH: 28, CRITICAL: 7)
# 
# +---------+------------------+----------+-------------------+---------------+---------------------------------------+
# | LIBRARY | VULNERABILITY ID | SEVERITY | INSTALLED VERSION | FIXED VERSION | TITLE                                 |
# +---------+------------------+----------+-------------------+---------------+---------------------------------------+
# | apt     | CVE-2020-27350   | MEDIUM   | 1.8.2.1           | 1.8.2.2       | apt: integer overflows...             |
# | openssl | CVE-2021-3711    | CRITICAL | 1.1.1d-0+deb10u3  | 1.1.1d-0+de...| openssl: SM2 Decryption Buffer Over...|
```

### Step 2: Implement a "Fail the Build" Threshold
In a CI pipeline, you don't want a human to read the table. You want it to fail automatically if it's Critical.
```bash
# Scan again, but tell Trivy to return exit code 1 ONLY for CRITICAL CVEs
trivy image --exit-code 1 --severity CRITICAL nginx:1.18.0

# Check the exit code of the last command
echo $?
# Output: 1 (The CI pipeline will now stop!)
```

### Step 3: SAST Scanning with Semgrep
Assume you have a Python file `app.py` with bad code:
```python
import os
def execute_cmd(user_input):
    # DANGEROUS: Command Injection!
    os.system(user_input) 
```

```bash
# Run Semgrep locally
semgrep --config "p/default" app.py

# Expected output:
# 1 error found!
# 1: os.system(user_input)
#  Security Warning: Detected the use of os.system(). This is dangerous if user input is passed...
```

### Step 4: IaC Scanning (Terraform)
Trivy can also scan your Terraform code for misconfigurations (like open Security Groups).
```bash
# Create a bad Terraform file
echo 'resource "aws_s3_bucket" "b" { bucket = "my-bucket" }' > main.tf

# Scan the directory
trivy config ./

# Expected output will warn you that logging and encryption are not enabled on the S3 bucket.
```

> [!tip] Pro Tip
> Security scanners output wildly different JSON formats. Standardize them by forcing all tools to output in **SARIF (Static Analysis Results Interchange Format)**. GitHub natively understands SARIF. If you upload a SARIF file to GitHub Actions, it will automatically parse it and annotate the exact vulnerable lines of code directly in the Pull Request review UI!

---

## Common Commands Cheat Sheet

| Command / Tool | What It Does | Real Example |
|----------------|-------------|--------------|
| `trivy image` | Scans container for OS/App CVEs | `trivy image python:3.9-alpine` |
| `trivy config` | Scans IaC (Terraform, K8s YAML) | `trivy config ./k8s-manifests/` |
| `semgrep` | Fast, open-source SAST scanner | `semgrep --config "p/security-audit" .` |
| `npm audit` | Native SCA tool for Node.js | `npm audit --production` |
| `checkov` | IaC scanner specifically for cloud | `checkov -d ./terraform-code` |
| `kube-bench` | Checks K8s cluster against CIS standards | `kube-bench run --targets master,node` |
| `--format sarif`| Common flag to output standard JSON | `trivy image --format sarif -o out.sarif nginx` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| SAST scanner flags 10,000 issues on first run | Scanning test files / vendor folders | SAST scanners will scan `node_modules` or `tests/` if you don't exclude them. Configure the scanner's ignore file (e.g., `.semgrepignore`) to exclude everything except `src/`. |
| CI Pipeline fails due to "Fix not available" CVEs | Too strict gating rules | Sometimes an OS package has a CVE, but the maintainers haven't released a patch yet. Configure Trivy with `--ignore-unfixed` so it only fails the build if a fix actually exists. |
| DAST scan takes 4 hours in the CI pipeline | Full scan mode enabled | A full DAST spider crawl is too slow for a CI pipeline. In CI, configure ZAP to run an "API Baseline Scan" or target specific endpoints, taking 2 minutes. Run the full crawl asynchronously on weekends. |
| Trivy fails to scan an image | Authentication required | If pulling from a private registry (like AWS ECR), Trivy needs credentials. Export `TRIVY_USERNAME` and `TRIVY_PASSWORD` or ensure your AWS CLI is authenticated before running the scan. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A developer includes an open-source image processing library in their Docker image. They push the code, the CI pipeline builds it, and it gets deployed. Two days later, a hacker exploits a known buffer overflow in that exact library and crashes the server."

**What Junior DevOps Does:**
Waits for the security team to email them a PDF report 3 months later, then manually creates a Jira ticket for the developer to update the library.

**Escalation Trigger:**
The vulnerability was a known CVE. It was entirely preventable. The delay between the developer introducing the bad code and the security team finding it allowed the breach to happen.

**Senior Engineer Resolution:**
1. Implements automated SCA and Container Scanning as blocking gates in the CI pipeline.
2. Next time the developer tries to introduce a vulnerable library, the pipeline runs `trivy image --exit-code 1`.
3. The scanner detects `CVE-2023-XXXXX` in the image processing library.
4. The pipeline fails immediately with a red `X` in GitHub. The code is blocked from merging.
5. The developer sees the log, bumps the library version in their `package.json`, and pushes a new commit.
6. The scan passes, the pipeline goes green, and the secure code is deployed. The hacker never gets a chance.

**Lesson Learned:**
Security must be a blocking function in the CI pipeline, not an out-of-band auditing process.

---

## Interview Questions

**Q1 (Conceptual):** Why is running a SAST scan usually faster and easier to integrate into a CI pipeline than a DAST scan?
**A:** SAST (Static Analysis) analyzes the source code directly. It runs quickly, requires no infrastructure, and can pinpoint the exact line of code. DAST (Dynamic Analysis) requires the application to be fully built, deployed, connected to a database, and running. The DAST scanner must then send thousands of HTTP requests over the network and wait for responses, making it much slower and more complex to automate in a fast CI pipeline.

**Q2 (Practical):** Your Trivy container scan found 50 CRITICAL vulnerabilities, but they are all located in standard Linux utilities like `wget`, `curl`, and `bash`. Your Node.js app doesn't use any of these. How do you resolve this permanently?
**A:** I would change the base image in the `Dockerfile`. Instead of `FROM ubuntu` or `FROM node:18` (which include a full Debian OS), I would use a minimal base image like `FROM node:18-alpine` or `FROM gcr.io/distroless/nodejs`. By stripping out the OS utilities entirely, those vulnerabilities disappear, permanently reducing the attack surface.

**Q3 (Scenario-based):** A developer argues that because their code runs in a private subnet with no public internet access, they don't need to fix a critical SQL injection vulnerability found by the SAST scanner. How do you respond?
**A:** I would explain the concept of "Defense in Depth" and insider threats. If a hacker manages to compromise the frontend server (or if an employee's laptop is compromised via phishing), they are now inside the network. Once inside, that SQL injection vulnerability becomes easily exploitable. Perimeter security (firewalls/subnets) is not an excuse for insecure application code.

**Q4 (Deep dive):** What is SARIF, and why is it important in DevSecOps?
**A:** SARIF (Static Analysis Results Interchange Format) is an industry-standard JSON format for the output of static analysis tools. In DevSecOps, you use dozens of different tools (Trivy, Checkov, Semgrep). If they all output different custom text formats, automation is impossible. By forcing all tools to output SARIF, you can ingest their results into a single central dashboard (like DefectDojo or GitHub Advanced Security) for unified reporting and tracking.

**Q5 (Trick/Gotcha):** Can an SCA tool (like Snyk or Dependabot) find a zero-day vulnerability in your code?
**A:** No. SCA tools only check your dependencies against public CVE databases (like NVD). A zero-day vulnerability, by definition, is unknown to the public and not in any database. SCA protects you from *known* vulnerabilities; you need secure coding practices, SAST, and DAST to mitigate *unknown* zero-days.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[09-Security-DevSecOps/SEC-01 DevSecOps Fundamentals|DevSecOps Fundamentals]]
[[03-Containerization/DOC-02 Dockerfile and Image Optimization|Secure Base Images]]
