---
tags: [devops, iac, terraform, architecture]
aliases: [Terraform Modules]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #terraform-associate
---

# TF-02 Terraform Modules

> [!abstract] Overview
> Writing all your Terraform code in a single `main.tf` file is like writing an entire enterprise application in a single Python script. It quickly becomes unreadable, unmanageable, and impossible to reuse. Terraform Modules allow you to package resources together into reusable building blocks. By abstracting complex infrastructure into simple modules, DevOps teams can enforce best practices, reduce code duplication, and allow developers to deploy infrastructure safely without knowing the underlying AWS complexities.

---

## Concept Overview

- **What it is** — A Terraform Module is simply a folder containing a set of `.tf` files. Every Terraform configuration is technically a module (the "root module"). You can call "child modules" from your root module to reuse code.
- **Why DevOps engineers use it** — To enforce the DRY (Don't Repeat Yourself) principle. Instead of writing 100 lines of complex VPC configuration for Dev, Staging, and Prod, you write a VPC module once. Then you call that module three times, passing different variables (like CIDR blocks) for each environment.
- **Where you encounter this in a real job** — Consuming public modules from the Terraform Registry (like the official `terraform-aws-modules/vpc/aws`), or building a custom private module for your company's standard "Web Server + Load Balancer" pattern.
- **Responsibility Split:**
  - **Junior DevOps**: Uses existing modules by filling in the required `variables` in the root module.
  - **Mid DevOps**: Refactors flat, monolithic Terraform code into local child modules to clean up the repository.
  - **Senior/SRE**: Architects public-facing or company-wide standard modules, enforces semantic versioning (git tags), and writes automated tests for the modules using Terratest.

*Seedha simple mein: Module ek factory template (saancha) hai. Agar aapko 10 car banani hain, toh har car ka design bar-bar zero se mat banao. Ek template bana lo, aur usme bas color (variables) change karke nayi car (infrastructure) banate jao.*

---

## Technical Deep Dive

### 1. Module Structure
A standard, professional module directory looks like this:
- `main.tf`: The actual resources being created.
- `variables.tf`: The input parameters the user must provide to use the module.
- `outputs.tf`: The return values the module gives back to the user (like generated IDs or IPs).
- `README.md`: Documentation on how to use it.

### 2. Calling a Module (Source and Version)
To use a module, you define a `module {}` block in your code.
The `source` argument is mandatory. It tells Terraform where to find the module. It can be:
- A local path: `source = "./modules/vpc"`
- A GitHub repo: `source = "github.com/myorg/tf-vpc-module"`
- The Public Registry: `source = "terraform-aws-modules/vpc/aws"`
When using Git or the Registry, ALWAYS use the `version` or `ref` argument to pin to a specific release. If you don't, an upstream update might break your production infrastructure unexpectedly.

### 3. Inputs and Outputs (The Interface)
A module is a black box. You cannot reference a resource inside a module directly from the outside.
- You pass data IN using variables.
- You get data OUT using outputs.
If your Root Module needs the Subnet ID created by the VPC Module, the VPC Module *must* explicitly export it in `outputs.tf`. The Root Module can then reference it using `module.my_vpc.subnet_id`.

---

## Step-by-Step Lab

> [!warning] Pre-requisites
> - Terraform CLI installed
> - AWS account configured

### Step 1: Create the Module Directory Structure
```bash
# We will create a root directory, and a 'modules/ec2' subdirectory
mkdir -p terraform-lab/modules/ec2
cd terraform-lab
```

### Step 2: Write the Reusable Child Module
We will create a module that spins up an EC2 instance and guarantees it gets a standardized "Company" tag.
```hcl
# In modules/ec2/variables.tf
variable "server_name" {
  type        = string
  description = "The name of the server"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

# In modules/ec2/main.tf
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  
  tags = {
    Name    = var.server_name
    Company = "GlobalTechCorp" # Enforced by the module!
  }
}

# In modules/ec2/outputs.tf
output "instance_id" {
  value = aws_instance.web.id
}
```

### Step 3: Write the Root Module to Call It
```hcl
# Go back to the root directory (terraform-lab)
# In main.tf
provider "aws" {
  region = "us-east-1"
}

# Call the module for the Dev server
module "dev_server" {
  source        = "./modules/ec2"
  server_name   = "dev-app-01"
  # instance_type is omitted, so it uses the default t2.micro
}

# Call the exact same module for the Prod server
module "prod_server" {
  source        = "./modules/ec2"
  server_name   = "prod-app-01"
  instance_type = "t3.medium" # Override the default
}

# Output the IDs passed back from the modules
output "dev_instance" {
  value = module.dev_server.instance_id
}
```

### Step 4: Apply the Code
```bash
# Initialize (this also installs the local modules)
terraform init

# Expected output: Initializing modules... - dev_server in modules/ec2 ...

# Plan and Apply
terraform apply -auto-approve

# Notice how it creates TWO servers using ONE template!
```

> [!tip] Pro Tip
> Never hardcode Provider configurations (like AWS region or credentials) *inside* a child module. Providers should only be defined in the Root module. The child modules will automatically inherit the provider configurations from the parent.

---

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
|---------|-------------|--------------|
| `terraform init` | Downloads/updates modules defined in source | `terraform init -upgrade` |
| `terraform get` | Explicitly downloads and updates modules | `terraform get -update` |
| `module {}` | HCL block used to call a child module | `module "vpc" { source = "./vpc" }` |
| `terraform taint` | (Legacy) Force recreate a module resource | `terraform taint module.dev_server.aws_instance.web` |
| `terraform apply -target`| Apply changes to only one specific module | `terraform apply -target=module.dev_server` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| `Module not installed` error | Added a new module block but didn't initialize | Every time you add a new `module` block or change the `source` URL, you must run `terraform init` again to download it. |
| `Unsupported argument` in module call | Passing a variable the module doesn't accept | Check the module's `variables.tf`. If you pass `env="prod"` in the root, the module MUST have a `variable "env" {}` defined. |
| Cannot access output `module.vpc.subnet_id` | Missing output in child module | The child module must explicitly declare `output "subnet_id" { value = aws_subnet.main.id }` for the root to see it. |
| Error fetching module from Git | SSH key / Access rights | If using a private GitHub repo as a source, your local machine (or CI runner) must have SSH keys configured to read that repo. |
| Provider error from inside module | Module has its own provider block | Remove `provider "aws" {}` from the child module. Let it inherit from the root module. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "We have 5 different development teams. Every time a team needs an S3 bucket, they write their own Terraform code. Half of them forget to enable Encryption at Rest, failing security audits."

**What Junior DevOps Does:**
Manually reviews every single Pull Request from all 5 teams, looking for `server_side_encryption_configuration`. Misses one, and the company fails a compliance audit.

**Escalation Trigger:**
Security mandates that NO unencrypted buckets can ever be provisioned, but reviewing code manually doesn't scale.

**Senior Engineer Resolution:**
1. Creates a private Terraform Module repo called `tf-secure-s3-bucket`.
2. Inside the module, writes the S3 resource code, hardcoding the strict KMS encryption and public-access block configurations.
3. Exposes only safe variables (like `bucket_name` and `cost_center_tag`).
4. Updates the company's CI/CD pipeline (using tools like OPA/Checkov) to enforce a rule: "Developers cannot use the `aws_s3_bucket` resource directly. They MUST use `module "secure_bucket" { source = "git::ssh://repo..." }`".
5. Now, developers get their buckets easily, and security is guaranteed because the complexity is abstracted away into a certified module.

**Lesson Learned:**
Modules are not just for code reuse; they are the primary mechanism for enforcing compliance, security guardrails, and company standards at scale.

---

## Interview Questions

**Q1 (Conceptual):** What is the difference between a Root Module and a Child Module?
**A:** The Root Module is the working directory where you run `terraform apply` (it contains your main `.tf` files). A Child Module is a separate collection of Terraform configurations called by the Root Module (or another module) using the `module {}` block to provision a specific set of reusable resources.

**Q2 (Practical):** You are using a public Terraform module from GitHub. How do you ensure your infrastructure doesn't break if the module author pushes a breaking change to the main branch?
**A:** When defining the module `source`, I must pin it to a specific version or Git tag/commit hash. For example, instead of `source = "github.com/org/repo"`, I would use `source = "github.com/org/repo?ref=v1.2.0"`.

**Q3 (Scenario-based):** You have a VPC module that creates subnets, and an EC2 module that needs to launch servers inside those subnets. Both modules are called from the same root `main.tf`. How do you pass the subnet ID from the VPC module to the EC2 module?
**A:** First, the VPC module must export the ID in its `outputs.tf` (e.g., `output "subnet_id"`). Second, the EC2 module must accept it in its `variables.tf` (e.g., `variable "subnet_id"`). Finally, in the root `main.tf`, when calling the EC2 module, I pass the value like this: `subnet_id = module.vpc.subnet_id`.

**Q4 (Deep dive):** Can you use a `count` or `for_each` loop directly on a `module` block?
**A:** Yes, since Terraform 0.13, you can use `count` and `for_each` on module blocks. For example, if I have a list of three regions, I can use `for_each` on the module to deploy the entire stack of resources defined in that module across all three regions simultaneously.

**Q5 (Trick/Gotcha):** If you delete a `module {}` block from your code and run `terraform apply`, what happens to the resources that were created by that module?
**A:** Terraform will detect that the module is no longer in the configuration and will DESTROY all the AWS resources that were managed by that module. Removing code in a declarative tool means "I no longer want this to exist."

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[06-IaC/TF-01 Terraform Fundamentals|Terraform Fundamentals]]
[[06-IaC/TF-03 Terraform State Management|Terraform State Management]]
