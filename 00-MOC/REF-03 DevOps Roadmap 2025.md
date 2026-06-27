---
tags: [devops, reference, roadmap, career]
aliases: [DevOps Roadmap 2025]
created: 2025-06-27
status: #complete
difficulty: #all-levels
cert-relevant: #all
---

# REF-03 DevOps Roadmap 2025

> [!abstract] Overview
> The DevOps landscape is vast, and junior engineers often suffer from "tutorial hell" trying to learn 50 different tools simultaneously. This roadmap provides a linear, structured progression from L1 Support/Fresher to Senior SRE. It outlines the exact skills to learn, the certifications to aim for, the portfolio projects required to get hired, and realistic salary bands for the Indian tech market.

---

## The 5-Level Progression Path

### Level 0: The Foundation (IT Support / Fresher)
Before you automate servers, you must know how to use them.
- **Skills**: Linux basics (navigation, permissions), Basic Networking (IP, DNS, HTTP/HTTPS), Git (clone, commit, push), Bash Scripting (loops, variables).
- **Study Time**: 1-2 Months.
- **Project**: Write a bash script that takes a database backup, compresses it, and rotates old backups, then schedule it with `cron`.
- **Target Role**: IT Support, L1 Engineer, System Administrator.

### Level 1: The Build & Deploy Engineer (Junior DevOps)
Learning how to package applications and move them through a pipeline.
- **Skills**: Docker (Dockerfiles, Docker Compose), CI/CD Concepts, GitHub Actions or GitLab CI, Basic Python, AWS Foundation (EC2, S3, IAM, VPC).
- **Study Time**: 2-3 Months.
- **Project**: Take a simple Node.js/React app, write a Dockerfile, push it to GitHub, and write a GitHub Actions pipeline that builds the image and deploys it to a Docker container on an AWS EC2 instance.
- **Target Role**: Junior DevOps Engineer, Build Engineer.

### Level 2: The Orchestrator (Mid-Level DevOps)
Scaling applications and managing infrastructure as code.
- **Skills**: Kubernetes (Pods, Deployments, Services, Ingress, ConfigMaps), Helm, Terraform (Modules, Remote State), Ansible (Playbooks, Roles).
- **Study Time**: 3-4 Months.
- **Project**: Use Terraform to provision a 3-node Kubernetes cluster (EKS/AKS). Use Helm to deploy Prometheus and Grafana. Write a Kubernetes deployment YAML to deploy your Node.js app onto the cluster.
- **Target Role**: DevOps Engineer, Cloud Engineer.

### Level 3: The Observer & Protector (Senior DevOps / DevSecOps)
Ensuring the system is secure, monitored, and automated securely.
- **Skills**: Prometheus/Grafana (PromQL, Alertmanager), ELK/EFK Stack (Logstash Grok), ArgoCD (GitOps), DevSecOps (Trivy, SonarQube, HashiCorp Vault).
- **Study Time**: 3-4 Months.
- **Project**: Implement a strict GitOps workflow using ArgoCD. Inject a vulnerable container, have Trivy catch it in CI, and configure HashiCorp Vault to dynamically inject database passwords into the K8s pods using the External Secrets Operator.
- **Target Role**: Senior DevOps Engineer, DevSecOps Engineer.

### Level 4: The Architect (Site Reliability Engineer - SRE)
Treating operations as a software engineering problem.
- **Skills**: SLO/SLA/SLI calculations, Incident Management, Chaos Engineering (Chaos Mesh), Advanced Go/Python coding, Multi-region architectures, Distributed Tracing (Jaeger).
- **Study Time**: Ongoing.
- **Project**: Run a Chaos Engineering GameDay. Kill a core microservice pod randomly, observe the tracing data in Jaeger, calculate the impact on the Error Budget, and write a Blameless Postmortem.
- **Target Role**: SRE, Staff DevOps Engineer, Cloud Architect.

---

## Certification Path

Certifications get you past HR filters. Practical knowledge gets you past the technical interview.

1. **Linux+ / RHCSA** (Optional but good if you have zero Linux background).
2. **Docker Certified Associate (DCA)** (Optional, knowledge is mandatory but cert is rarely asked for).
3. **AWS Certified Solutions Architect - Associate** (Mandatory baseline cloud knowledge).
4. **HashiCorp Certified: Terraform Associate** (Highly recommended, very respected, easy to pass if you do the labs).
5. **Certified Kubernetes Administrator (CKA)** (The Gold Standard. Fully hands-on terminal exam. If you have a CKA, companies *will* interview you).
6. **Certified Kubernetes Security Specialist (CKS)** (For DevSecOps roles. Very difficult).
7. **AWS Certified DevOps Engineer - Professional** (For Senior/Architect roles).

*Recommended Sequence: AWS SAA -> Terraform Associate -> CKA.*

---

## Salary Bands (Indian Market 2024-2025)

*Note: Salaries vary wildly based on company tier (WITCH vs. Product vs. FAANG).*

| Experience Level | Tier 3 (Service Based) | Tier 2 (Mid-Product / Startup) | Tier 1 (Top Product / FAANG) |
|------------------|------------------------|--------------------------------|------------------------------|
| **Fresher (0-1 yr)** | 3.5 - 5 LPA | 7 - 12 LPA | 15 - 25 LPA |
| **Junior (1-3 yrs)** | 5 - 8 LPA | 12 - 18 LPA | 25 - 40 LPA |
| **Mid (3-5 yrs)** | 8 - 14 LPA | 18 - 30 LPA | 40 - 65 LPA |
| **Senior (5-8 yrs)** | 14 - 22 LPA | 30 - 45 LPA | 65 - 90+ LPA |
| **Architect/SRE (8+ yrs)** | 22 - 35 LPA | 45 - 70 LPA | 90 - 1.5+ Cr |

---

## The 30-Day Quick Start Plan (From Zero)

If you are an L1 Support engineer looking to transition, do exactly this for 30 days:
- **Days 1-5**: Install Ubuntu in a VM or WSL. Learn `cd`, `ls`, `grep`, `chmod`, `systemctl`, `ssh`. Do NOT use a GUI for a month.
- **Days 6-10**: Learn Git. Create a GitHub account. Learn `add`, `commit`, `push`, `branch`, `merge`.
- **Days 11-15**: Learn basic Python. Just enough to write a loop, read a JSON file, and make an API request using `requests`.
- **Days 16-20**: Learn Docker. Write a Dockerfile for a simple web app. Learn how to map ports and volumes.
- **Days 21-25**: Create an AWS Free Tier account. Spin up an EC2 instance. Install Docker on it. Deploy your app.
- **Days 26-30**: Write a GitHub Actions pipeline that automatically pushes your code to the EC2 instance whenever you commit to GitHub.
*Result: You have successfully built a CI/CD pipeline. You are now officially a junior DevOps engineer.*

---

## Common Mistakes Freshers Make

1. **Learning Kubernetes before Docker**: You cannot understand an orchestrator if you don't understand what it is orchestrating. Master Docker and containers first.
2. **Skipping Linux**: Clicking around AWS is easy. Debugging why an Nginx container is throwing a 502 Bad Gateway requires deep Linux networking knowledge. Linux is the bedrock of DevOps.
3. **Watching without doing ("Tutorial Hell")**: Watching a 10-hour Terraform tutorial is useless. You must build it yourself. If you don't get error messages, you aren't learning.
4. **Learning tools instead of concepts**: Don't learn "Jenkins". Learn "CI/CD". If you understand the concept of a pipeline, switching from Jenkins to GitLab CI takes 3 days.
5. **Ignoring Development**: "DevOps" contains "Dev". You don't need to be a full-stack engineer, but you MUST know how to read code, write scripts (Python/Bash/Go), and understand how applications are structured. A DevOps engineer who can't code is just a modern SysAdmin.

---

## Best Free Resources

- **YouTube Channels**: TechWorld with Nana, Mumshad Mannambeth, Abhishek Veeramalla, KodeKloud, NetworkChuck.
- **Hands-on Labs**: Killercoda (Free Kubernetes environments in browser), Play with Docker.
- **Roadmap Visualization**: roadmap.sh/devops

---

## Related Notes
[[00-MOC/Master-Index|Master Index]]
[[00-MOC/REF-01 DevOps Command Cheat Sheet|Cheat Sheet]]
[[00-MOC/REF-02 DevOps Interview Q&A Bank|Interview Prep]]
