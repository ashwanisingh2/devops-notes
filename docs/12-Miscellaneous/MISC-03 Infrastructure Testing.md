---
tags: [devops, terraform, ansible, testing]
aliases: [Infrastructure Testing]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# MISC-03 Infrastructure Testing

> [!abstract] Overview
> Just like application code, Infrastructure as Code (IaC) needs to be tested before it is deployed to production. A single typo in Terraform or Ansible can bring down an entire data center. Infrastructure testing spans multiple layers: static analysis (linting, security scanning), dry runs (plans), and actual integration testing (spinning up real resources, asserting they work, and tearing them down). This note covers testing strategies for Terraform and Ansible.

## Concept Overview
Testing infrastructure is harder than testing software because "mocking" a cloud provider is difficult. We rely on a pipeline of checks, starting from fast, offline tests (formatting, static analysis) to slower, online tests (creating actual resources).

*Hindi Explanation: Jaise code ko production mein daalne se pehle test karna zaroori hai, waise hi infrastructure code ko bhi check karna padta hai. Ek choti si galti se pura server delete ho sakta hai. Isliye hum pehle code ki spelling check karte hain (linting), phir dekhte hain ki banne ke baad kaisa dikhega (plan), aur last mein asli mein bana kar test karte hain (integration testing).*

**Key Concepts:**
- **Static Analysis (SAST for IaC):** Scanning Terraform/CloudFormation code for security misconfigurations without actually running it. (e.g., Checkov, tfsec).
- **Terratest:** A Go library developed by Gruntwork that makes it easier to write automated tests for your IaC. It creates real resources, runs assertions, and destroys them.
- **Molecule:** A testing framework for Ansible roles. It spins up a container or VM, runs your Ansible role against it, and verifies the end state using a verifier (like Testinfra).

**Desi Analogy:**
Imagine you are building a new house (Infrastructure).
- `terraform validate`: The architect checking if the blueprint grammar makes sense (walls connect to walls).
- `checkov`: The safety inspector looking at the blueprint and saying, "This window is too big, thieves can enter" (Security scan).
- `terraform plan`: Showing the 3D model to the owner before buying bricks.
- `terratest`: Actually building a small sample room, checking if it holds weight, and then destroying it before building the main house.

## Technical Deep Dive

### 1. The Terraform Testing Pyramid
1. **Formatting & Validation (Fastest):** `terraform fmt` ensures consistent styling. `terraform validate` checks syntax and internal consistency (e.g., referencing a variable that exists).
2. **Security & Compliance Scanning:** Tools like **Checkov** or **Trivy** parse the HCL code offline. They look for known bad practices, such as S3 buckets without encryption, or security groups open to `0.0.0.0/0`.
3. **Plan / Dry Run:** `terraform plan` talks to the cloud provider's API, checks the current state, and shows exactly what *will* change. In CI/CD, this plan is often output as a file (`plan.out`) and reviewed.
4. **Integration Testing (Terratest):** The slowest but most reliable. You write Go code that runs `terraform apply` in a sandbox account, makes an HTTP request to the created Load Balancer to check for a 200 OK, and then runs `terraform destroy` (`defer` in Go ensures it cleans up even on failure).

### 2. Ansible Testing with Molecule
Ansible roles can become complex. **Molecule** provides support for testing with multiple instances, operating systems and distributions, virtualization providers, test frameworks, and testing scenarios.
A typical Molecule test flow:
- **Dependency:** Pulls dependencies (like other roles from Ansible Galaxy).
- **Create:** Spins up a test instance (usually a Docker container).
- **Converge:** Runs your Ansible role against the test instance.
- **Idempotence:** Runs the role *again* to ensure no changes are made on the second run (a key principle of Ansible).
- **Verify:** Runs a testing tool (like pytest-testinfra) to assert things (e.g., "Is port 80 open?", "Is nginx installed?").
- **Destroy:** Cleans up the test instance.

## Step-by-Step Lab
**Scenario 1: Add Checkov to a GitHub Actions workflow for Terraform.**
**Scenario 2: Initialize Molecule for an existing Ansible role.**

**Lab 1: Checkov in GitHub Actions**
**Step 1: Create a basic vulnerable Terraform file**
```bash
mkdir tf-test && cd tf-test
cat <<EOF > main.tf
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-insecure-bucket-123"
}
EOF
```

**Step 2: Run Checkov locally**
```bash
pip install checkov
checkov -d .
```
*Expected output: Checkov will flag the bucket for missing encryption, logging, and versioning. (FAILED).*

**Step 3: Create GitHub Actions Workflow**
Create `.github/workflows/checkov.yml`:
```yaml
name: Checkov Scan
on: [push, pull_request]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: .
          framework: terraform
```
*Expected output: When pushed to GitHub, the pipeline will fail, preventing the insecure code from merging.*

---

**Lab 2: Ansible Molecule**
**Step 1: Install Molecule and Docker**
```bash
pip install "molecule[docker]" ansible-lint pytest-testinfra
```
*Expected output: Python packages installed.*

**Step 2: Initialize a new role with Molecule**
```bash
molecule init role my_nginx_role --driver-name docker
cd my_nginx_role
```
*Expected output: Creates a role directory structure including a `molecule/default` folder.*

**Step 3: Run the Molecule test suite**
*(Assuming Docker is running on your machine)*
```bash
molecule test
```
*Expected output: Molecule will download a default container image (usually CentOS/Ubuntu), run the empty role, check for idempotence, and destroy the container. The output will show the full lifecycle.*

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
| :--- | :--- | :--- |
| `terraform validate` | Checks syntax and internal logic | `terraform validate` |
| `checkov -d .` | Scans current directory for security issues | `checkov -d ./terraform-code` |
| `trivy config .` | Alternative to checkov for IaC scanning | `trivy config ./infra` |
| `go test -v` | Runs Terratest files | `go test -v -timeout 30m` |
| `molecule init role <name>` | Creates a new role with molecule template | `molecule init role webserver` |
| `molecule converge` | Spins up test instance and runs role | `molecule converge` |
| `molecule verify` | Runs tests against the converged instance | `molecule verify` |
| `molecule test` | Runs the full lifecycle (create->converge->verify->destroy)| `molecule test` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| Checkov fails the CI pipeline intentionally, but I want to accept the risk. | The rule violation is known and accepted (e.g., intentional public bucket). | 1. Add a skip comment in your TF code: `# checkov:skip=CKV_AWS_20: "This bucket must be public for website hosting"`. |
| Molecule test fails during `create` phase. | Docker daemon is not running or molecule cannot connect to it. | 1. Start Docker Desktop / daemon. 2. Verify with `docker ps`. 3. Ensure python docker module is installed (`pip install docker`). |
| Molecule fails on 'idempotence' check. | Your Ansible task makes a change every time it runs (e.g., using `command` instead of a proper module). | 1. Review the output of the idempotence run to see which task reported `changed`. 2. Add `creates:` or `changed_when: false` to the task, or use a declarative module. |
| Terratest leaves orphaned resources behind if a test crashes. | Go test panicked before reaching the `defer terraform.Destroy` call. | 1. Implement robust error handling. 2. Use a dedicated AWS account for testing and run tools like `aws-nuke` nightly to clean up orphaned resources. |
| `terraform validate` passes but `terraform plan` fails. | Validation only checks syntax. Plan checks against the live cloud API (e.g., a requested instance type doesn't exist). | Review the API error from the cloud provider returned during the plan phase and adjust parameters. |

## Real-World Job Scenario
**The Situation:** A developer submits a Pull Request adding a new Terraform module to create an RDS database. The company policy strictly requires all databases to be encrypted at rest and not publicly accessible.

**Junior DevOps Action:**
- Manually reviews the 500 lines of HCL code.
- Misses a nested variable configuration that accidentally sets `publicly_accessible = true`.
- Approves the PR. The database is created publicly. The security team finds it weeks later via an external audit.

**Senior DevOps Action:**
- Has already integrated `checkov` into the GitHub Actions PR workflow.
- The pipeline automatically runs against the developer's PR.
- Checkov immediately flags the `publicly_accessible = true` violation and fails the PR build.
- The developer is forced to fix the code to get a green tick before the Senior DevOps even has to look at it.

## Interview Questions

**Q1: What is the purpose of `terraform plan` in a CI/CD pipeline?**
**A:** `terraform plan` provides a dry run of the changes Terraform intends to make. In a CI/CD pipeline, it is crucial for generating an execution plan (often saved to a file) that can be reviewed by humans or automated tools (like OPA/Conftest) before running `terraform apply`, ensuring no unexpected resources are created, modified, or destroyed.

**Q2: How does Checkov differ from Terratest?**
**A:** Checkov is a static analysis (SAST) tool. It reads the IaC source code without executing it or connecting to a cloud provider, looking for security misconfigurations based on predefined policies. Terratest is an integration testing framework written in Go. It actually deploys the infrastructure to a real cloud environment, runs tests against the live resources (e.g., HTTP requests, SSH connections), and then destroys them.

**Q3: Why is testing for 'idempotence' important in Ansible?**
**A:** Idempotence means that running a playbook multiple times has the same effect as running it once; it only makes changes if the system is not in the desired state. Testing for this (as Molecule does by default) ensures that your automation is reliable and won't unnecessarily restart services or overwrite configurations if the server is already correctly configured.

**Q4: If you want to enforce that all EC2 instances must have a specific tag (e.g., 'CostCenter') before they are deployed, how would you test this?**
**A:** You can use a static analysis tool like Checkov (writing a custom policy) or HashiCorp's Sentinel / Open Policy Agent (OPA) integrated into the CI/CD pipeline. These tools will parse the Terraform code or the generated `plan.json` and fail the build if the required tag is missing.

**Q5: What are the main phases of a standard Ansible Molecule test lifecycle?**
**A:** The standard lifecycle is: Dependency (fetch roles), Lint (check syntax), Cleanup (pre-test), Destroy (ensure clean slate), Syntax, Create (spin up docker/VM), Prepare, Converge (run the role), Idempotence (run role again, expect 0 changes), Side_effect, Verify (run testinfra to check final state), Cleanup, and finally Destroy (teardown test instance).

## Related Notes
- [[Master Index]]
- [[MISC-01 GitOps Flux vs ArgoCD]]
- [[K8S-01 Architecture and Components]]
