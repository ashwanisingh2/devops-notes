---
tags: [devops, image-building, packer, immutable-infrastructure]
aliases: [Packer]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# Packer

> [!abstract] Overview
> Packer is an open-source tool by HashiCorp used to create identical machine images for multiple platforms (AWS, Azure, Docker, VMware) from a single source configuration. It is the cornerstone of the "Immutable Infrastructure" pattern, where servers are never patched or updated in place; instead, a new Golden Image is built via Packer and deployed to replace the old ones.

## Concept Overview (What/Why/Where/Responsibility Split)

**What is it?**
Instead of manually creating an EC2 instance, logging in, installing Nginx, running security patches, and then clicking "Create Image (AMI)", Packer automates this entire process using code (HCL - HashiCorp Configuration Language).

*Hindi Explanation:*
*Jese car factory me ek 'mould' (saancha) hota hai jisse hazaro identical cars banti hain. Packer wo mould banane ka automation tool hai. Aap script me likhte ho ki OS konsa hoga aur usme kya software chahiye. Packer cloud me jayega, VM banayega, sab install karega, uska 'Snapshot' ya 'AMI' (Golden Image) banayega, aur fir VM delete kar dega. Ab aap is image se kitne bhi identical servers launch kar sakte ho.*

**Why use it?**
*   **Speed:** Booting a pre-baked image takes seconds. Running a configuration script on boot (like UserData) takes minutes.
*   **Consistency:** The image tested in Dev is the exact byte-for-byte image deployed in Prod.
*   **Multi-Cloud:** Write one template, build an AMI for AWS and a VHD for Azure simultaneously.

**Where is it used?**
Packer is used in CI/CD pipelines to bake application code, security agents, and OS patches into "Golden AMIs" before Terraform or Auto Scaling Groups deploy them.

**Responsibility Split**
*   **SecOps Team:** Defines the base OS hardening in Packer.
*   **DevOps Engineer:** Writes the Packer templates to bake applications into the hardened base image and triggers this via Jenkins/GitHub Actions.

## Technical Deep Dive

### 1. Packer Architecture and Builders
Packer relies on **Builders** to generate images for specific platforms. An AWS builder creates an EBS-backed AMI; a Docker builder creates a Docker image; a VMware builder creates a VMDK.
The process: Packer creates a temporary instance on the target platform, connects to it, runs provisioners, creates the machine image, and terminates the temporary instance.

### 2. Provisioners
Just like Vagrant, Packer uses **Provisioners** to install software inside the temporary machine before it becomes an image. You can use:
*   `shell`: To run bash scripts.
*   `ansible`: To run Ansible playbooks (very common combo: Packer + Ansible).
*   `file`: To upload config files from your local machine to the image.

### 3. HCL2 Templates
Modern Packer uses HCL2 (HashiCorp Configuration Language), identical to Terraform syntax. A template consists of:
*   `packer {}`: Block defining required plugins.
*   `source "builder_type" "name" {}`: Defines *where* and *how* to build the base instance (e.g., source AMI, instance type).
*   `build {}`: Defines the sequence of provisioning steps to run on the source.

## Step-by-Step Lab

**Scenario:** Automate the creation of a custom Ubuntu AMI that comes with Nginx pre-installed.

**Step 1: Install Packer**
Download from HashiCorp and add to PATH. Verify with `packer version`.

**Step 2: Set AWS Credentials**
Ensure your shell has AWS access:
```bash
export AWS_ACCESS_KEY_ID="your_key"
export AWS_SECRET_ACCESS_KEY="your_secret"
export AWS_DEFAULT_REGION="us-east-1"
```

**Step 3: Create the Packer Template (`nginx-ami.pkr.hcl`)**
```hcl
packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "packer-nginx-ubuntu-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  instance_type = "t2.micro"
  region        = "us-east-1"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical owner ID
  }
  ssh_username = "ubuntu"
}

build {
  name = "learn-packer"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  provisioner "shell" {
    inline = [
      "echo Installing Nginx",
      "sleep 30",
      "sudo apt-get update",
      "sudo apt-get install -y nginx",
      "sudo systemctl enable nginx"
    ]
  }
}
```

**Step 4: Initialize and Format**
```bash
packer init nginx-ami.pkr.hcl
# Installs the amazon plugin
packer fmt nginx-ami.pkr.hcl
# Formats the HCL code nicely
```

**Step 5: Build the Image**
```bash
packer build nginx-ami.pkr.hcl
# Output: 
# amazon-ebs.ubuntu: output will be in this color.
# amazon-ebs.ubuntu: Creating temporary keypair...
# ... (Creates instance, runs apt-get, stops instance, creates AMI) ...
# Build 'learn-packer.amazon-ebs.ubuntu' finished after 4 minutes.
# AMIs were created: us-east-1: ami-0123456789abcdef0
```

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
| :--- | :--- | :--- |
| `packer init` | Downloads required plugins defined in config | `packer init app.pkr.hcl` |
| `packer fmt` | Formats the HCL template to standard style | `packer fmt .` |
| `packer validate` | Checks template syntax and configuration | `packer validate app.pkr.hcl` |
| `packer build` | Executes the build process to create image | `packer build app.pkr.hcl` |
| `packer inspect` | Shows components (sources, provisioners) of a template | `packer inspect app.pkr.hcl` |
| `packer console` | Opens interactive console to evaluate HCL variables | `packer console` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| SSH timeout waiting for instance | Security group or network issue | 1. Ensure default VPC allows SSH (port 22).<br>2. Add `associate_public_ip_address = true` in source block if using a public subnet. |
| Provisioner fails with `apt-get: lock error` | Instance boot process (cloud-init) is still running | 1. Add a `sleep 30` at the start of your shell provisioner to let cloud-init finish before running `apt`. |
| AWS authentication error | Missing or invalid AWS credentials | 1. Verify `AWS_ACCESS_KEY_ID` is set in terminal.<br>2. Check if the IAM user has EC2/AMI creation permissions. |
| AMI name already exists | Hardcoded AMI name | 1. Use the `timestamp()` function in `ami_name` to make it unique every run. |
| Build stuck on "Stopping instance" | Provisioner left a lingering background process | 1. Ensure scripts don't start blocking foreground services. Use systemd to enable services instead of running them directly in the script. |

## Real-World Job Scenario

**Scenario:** The company scales instances up and down using an AWS Auto Scaling Group (ASG). Currently, instances take 10 minutes to become healthy because they download code, install dependencies, and compile assets on boot (using EC2 UserData).

*   **Junior Engineer's Action:** Tries to optimize the bash script in UserData, making it multi-threaded, saving maybe 2 minutes. The scaling event still takes too long, causing user requests to drop during traffic spikes.
*   **Senior Engineer's Action:** Implements Packer. Writes a Packer pipeline that runs on every git push. Packer bakes the application code and all dependencies into an AMI. The ASG is updated to use this new AMI. When a scaling event occurs, the instance boots in 45 seconds because everything is pre-installed. This is the **Immutable Infrastructure** approach.

## Interview Questions

1.  **Q: What is Immutable Infrastructure?**
    *   **A:** It's an approach where infrastructure (like servers) is never modified after it is deployed. If an update is needed (e.g., a new code version or OS patch), a new image is built, new servers are provisioned from it, and the old servers are destroyed. Packer enables this by automating image creation.
2.  **Q: How do Packer and Terraform work together?**
    *   **A:** They are complementary. Packer is used to *build* the machine images (AMIs). Terraform is used to *provision* infrastructure (VPCs, Load Balancers, ASGs) using the AMIs created by Packer.
3.  **Q: Why would you use Ansible with Packer?**
    *   **A:** While Packer has a shell provisioner, shell scripts get messy for complex configurations. Ansible provides idempotent, declarative configuration management. You can use the Packer `ansible` provisioner to run an existing Ansible playbook to configure the image perfectly before Packer saves it.
4.  **Q: How does Packer connect to the temporary AWS instance it creates?**
    *   **A:** Packer temporarily creates an SSH keypair (or uses a provided one), injects the public key into the temporary EC2 instance, and connects via SSH using the private key. Once the AMI is built, the temporary keypair is deleted.
5.  **Q: What is a Packer builder?**
    *   **A:** A builder is a component of Packer that translates the template configuration into an actual machine image for a specific platform (e.g., `amazon-ebs` for AWS AMIs, `docker` for Docker images).

## Related Notes
- [[Master Index]]
- [[TERRAFORM-01 Terraform Basics]]
- [[AWS-02 EC2 and Auto Scaling]]
