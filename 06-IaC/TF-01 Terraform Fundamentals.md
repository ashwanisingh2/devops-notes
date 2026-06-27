---
tags: [devops, iac, terraform, aws]
aliases: [Terraform Basics]
created: 2025-06-27
status: #complete
difficulty: #beginner
cert-relevant: #terraform-associate
---

# TF-01 Terraform Fundamentals

> [!abstract] Overview
> Clicking through the AWS Console to create servers and databases is fine for a weekend project, but it is a disaster for an enterprise. You cannot track who changed what, you cannot easily duplicate environments, and manual clicks lead to security misconfigurations. Infrastructure as Code (IaC) solves this. Terraform is the undisputed industry standard for IaC, allowing you to define your entire cloud infrastructure as version-controlled code, making it reproducible, reviewable, and reliable.

---

## Concept Overview

- **What it is** — An open-source Infrastructure as Code tool created by HashiCorp. It uses a declarative configuration language (HCL - HashiCorp Configuration Language) to define and provision data center infrastructure across multiple cloud providers.
- **Why DevOps engineers use it** — To automate cloud provisioning. You write what you want (e.g., "I need 1 VPC and 3 EC2 instances"), and Terraform figures out the API calls required to make it happen. It is cloud-agnostic, meaning you use the same tool/workflow for AWS, Azure, GCP, and even Kubernetes.
- **Where you encounter this in a real job** — Setting up a brand new staging environment that is an exact replica of production, or adding a new S3 bucket with strict encryption policies via a GitHub Pull Request.
- **Responsibility Split:**
  - **Junior DevOps**: Runs `terraform plan` and `terraform apply` to deploy changes written by others, or adds simple resources like a DNS record.
  - **Mid DevOps**: Writes HCL for complex resources (VPCs, EKS clusters), manages input variables, and sets up the provider configurations.
  - **Senior/SRE**: Designs reusable Terraform Modules, sets up remote state locking using S3/DynamoDB, and integrates Terraform into CI/CD pipelines (GitOps for IaC).

*Seedha simple mein: Pehle hum mistri ko bolte the "Yahan eent rakho, wahan cement lagao" (Manual AWS Console clicks). Terraform ek blueprint (naksha) hai. Aap Terraform ko naksha dete ho, aur wo khud jaake poora ghar (infrastructure) khada kar deta hai. Agar naksha change karoge, toh wo ghar bhi update kar dega bina tode.*

---

## Technical Deep Dive

### 1. The Declarative Workflow
Terraform is *declarative*, not imperative. You don't write scripts saying "Create server A, then create server B." You declare "Server A and Server B must exist." Terraform reads your current AWS state, compares it to your code, and generates an execution plan to bridge the gap.
The Core Workflow:
1. `terraform init`: Downloads the required provider plugins (like AWS/Azure).
2. `terraform plan`: Shows you exactly what it *will* do without actually doing it. (Crucial for safety).
3. `terraform apply`: Executes the plan against the cloud APIs.
4. `terraform destroy`: Tears down everything defined in the code.

### 2. Architecture: Core, Providers, and State
- **Core**: The Terraform binary on your laptop. It reads HCL and compares state.
- **Providers**: Plugins that understand specific cloud APIs (AWS Provider, Azure Provider).
- **State File (`terraform.tfstate`)**: The most critical component. It is a JSON file where Terraform maps your HCL code to the real-world Cloud IDs. If you define `aws_instance.web`, the state file remembers that this equals `i-0abcd1234efgh` in AWS. Never lose or manually edit this file.

### 3. HCL Syntax Blocks
- `provider`: Configures the cloud you are talking to (AWS region, credentials).
- `resource`: Creates something NEW (e.g., an EC2 instance).
- `data`: Fetches information about something that ALREADY EXISTS (e.g., finding the latest Ubuntu AMI ID).
- `variable`: Input parameters (like passing arguments to a function).
- `output`: Values returned after creation (e.g., printing the new server's IP address).

---

## Step-by-Step Lab

> [!warning] Pre-requisites
> - Terraform CLI installed
> - AWS Account (Free Tier)
> - AWS CLI installed and configured (`aws configure` with Access Keys)

### Step 1: Write the Provider and Resource Config
```hcl
# Create a file named main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Create an EC2 Instance
resource "aws_instance" "my_web_server" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 in us-east-1
  instance_type = "t2.micro"

  tags = {
    Name        = "DevOps-Vault-Server"
    Environment = "Dev"
  }
}

# Output the public IP after creation
output "server_public_ip" {
  value = aws_instance.my_web_server.public_ip
}
```

### Step 2: Initialize and Format
```bash
# Downloads the AWS provider plugin
terraform init

# Expected output: Terraform has been successfully initialized!

# Formats the code neatly (always run this before committing)
terraform fmt

# Validates syntax errors
terraform validate
```

### Step 3: Plan the Changes
```bash
# See what Terraform intends to do
terraform plan

# Expected output:
# Terraform will perform the following actions:
#   # aws_instance.my_web_server will be created
#   + resource "aws_instance" "my_web_server" {
#       + ami = "ami-0c7217cdde317cfec"
#       ...
# Plan: 1 to add, 0 to change, 0 to destroy.
```

### Step 4: Apply and Verify
```bash
# Execute the plan (type 'yes' when prompted)
terraform apply

# Expected output:
# aws_instance.my_web_server: Creating...
# aws_instance.my_web_server: Creation complete after 35s
# Outputs:
# server_public_ip = "3.85.x.x"
```

### Step 5: Destroy the Infrastructure
```bash
# Tear it all down so you don't get billed!
terraform destroy

# Expected output:
# Plan: 0 to add, 0 to change, 1 to destroy.
# Destroy complete! Resources: 1 destroyed.
```

> [!tip] Pro Tip
> Never hardcode AMIs (like `ami-0c72...`) in production. AMIs are updated constantly for security patching and their IDs differ per region. Use a `data "aws_ami"` block to dynamically fetch the latest Ubuntu/Amazon Linux image ID during the `plan` phase.

---

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
|---------|-------------|--------------|
| `terraform init` | Initializes working directory and downloads providers | `terraform init` |
| `terraform fmt` | Rewrites config files to standard format | `terraform fmt --recursive` |
| `terraform validate`| Checks config validity and syntax | `terraform validate` |
| `terraform plan` | Generates and shows an execution plan | `terraform plan -out=tfplan` |
| `terraform apply` | Builds or changes infrastructure | `terraform apply -auto-approve` |
| `terraform destroy` | Destroys Terraform-managed infrastructure | `terraform destroy` |
| `terraform state list`| Lists resources tracked in the state file | `terraform state list` |
| `terraform show` | Prints human-readable output from state or plan | `terraform show` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| `Error: No valid credential sources found` | AWS CLI is not configured | Run `aws configure` to set your Access Key and Secret Key, or export `AWS_ACCESS_KEY_ID` as environment variables. |
| `Error: Reference to undeclared resource` | Typo in resource referencing | If you use `aws_instance.web.id`, ensure you actually named the resource `aws_instance "web"`. Terraform is strictly validated. |
| Apply takes 10 minutes then fails with timeout | Security Group or VPC routing issue | If provisioning a Database or EKS cluster fails on a timeout, it's usually because it cannot reach the internet to signal completion. Check subnet routing. |
| `Provider configuration not present` on destroy | You deleted the provider block from code | To destroy resources, Terraform still needs to know how to authenticate. Put the `provider "aws"` block back in the file, then run destroy. |
| Plan shows a resource being recreated instead of updated | Changing an immutable property | Some properties (like EC2 `ami`) cannot be changed on a running server. Changing it forces Terraform to destroy the old one and build a new one. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A Junior developer manually logged into the AWS Console and changed the Security Group of the production database to allow `0.0.0.0/0` (open to the world) to debug an issue."

**What Junior DevOps Does:**
Logs into the console, searches for the Security Group, and manually deletes the bad rule. Hopes nobody else messes with it.

**Escalation Trigger:**
The security team demands an audit of how the rule was changed and requires a guarantee that unauthorized manual changes are reverted immediately.

**Senior Engineer Resolution:**
1. Since the infrastructure was originally provisioned with Terraform, the state file tracks the correct configuration.
2. The Senior runs `terraform plan`.
3. Terraform detects the "drift". The output shows: `~ ingress { cidr_blocks = ["0.0.0.0/0"] -> ["10.0.0.0/8"] }`. It knows the real AWS state no longer matches the code.
4. The Senior runs `terraform apply`. Terraform automatically reaches into AWS and deletes the dangerous manual rule, enforcing the coded state.
5. Next, the Senior removes console access for developers. All AWS changes must now be done via Pull Requests to the Terraform GitHub repository.

**Lesson Learned:**
Terraform is not just a provisioning script; it is a state enforcer. It catches and corrects manual tampering (configuration drift).

---

## Interview Questions

**Q1 (Conceptual):** What is the difference between a declarative tool like Terraform and an imperative tool like a Bash script?
**A:** In a Bash script (imperative), you write the exact steps to achieve a goal (e.g., 1. Run AWS CLI to check if server exists. 2. If no, create it. 3. If yes, update it). In Terraform (declarative), you simply define the final desired state ("I want one server"). Terraform calculates the necessary steps, handles idempotency, and executes the changes automatically.

**Q2 (Practical):** Your `main.tf` has hardcoded AWS regions and instance types. How do you make this code reusable for different environments?
**A:** I would replace the hardcoded values with variables. I'd define a `variable "region" {}` and `variable "instance_type" {}` in a `variables.tf` file. Then, I can pass different values at runtime using a `.tfvars` file (e.g., `dev.tfvars` vs `prod.tfvars`) or via the command line with `-var="region=us-west-2"`.

**Q3 (Scenario-based):** You ran `terraform apply` and created an S3 bucket. Later, a coworker deleted the bucket directly from the AWS Console. What happens when you run `terraform plan` next?
**A:** During the `plan` phase, Terraform performs a "refresh" by checking the actual AWS cloud against its local `terraform.tfstate` file. It will notice the bucket exists in the state but is missing in AWS. The plan will output that it intends to recreate the missing bucket to match your `.tf` code.

**Q4 (Deep dive):** Explain what the `.terraform.lock.hcl` file does and why it should be committed to version control.
**A:** The lock file ensures dependency consistency for providers. When you run `terraform init`, Terraform downloads provider plugins (like the AWS provider) and records their exact cryptographic hashes in the lock file. Committing this file to Git guarantees that when your CI/CD pipeline or a coworker runs `terraform init`, they get the exact same provider versions, preventing unexpected behavior from upstream provider updates.

**Q5 (Trick/Gotcha):** Can Terraform manage infrastructure that was created manually *before* Terraform was used?
**A:** Yes, but not automatically. You cannot just write the HCL code and run apply, because Terraform will try to create a *new* resource and fail due to naming conflicts. You must use the `terraform import` command to pull the existing AWS resource's ID into the Terraform state file, and then write the matching HCL code.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[06-IaC/TF-02 Terraform Modules|Terraform Modules]]
[[06-IaC/TF-03 Terraform State Management|Terraform State Management]]
