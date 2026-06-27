---
tags: [devops, cloud, aws]
aliases: [AWS Core Services]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #aws-devops
---
# AWS Core Services for DevOps

> [!abstract]
> This note covers the foundational Amazon Web Services (AWS) that DevOps engineers interact with daily. We will explore compute (EC2, ASG, ECS, EKS, Lambda, ELB), storage (S3, EBS, EFS, Glacier), networking (VPC, Route 53), security (IAM), and management/monitoring tools (CloudWatch, CloudTrail, Config, X-Ray) to understand how to build resilient, scalable infrastructure.

## Concept Overview

AWS provides the building blocks for modern infrastructure. As a DevOps engineer, you don't just provision a server; you design a highly available ecosystem using managed services.
- **Compute:** EC2 (Virtual Machines), Auto Scaling Groups (ASG) for dynamic scaling, Elastic Load Balancers (ELB) for traffic distribution, ECS/EKS for containers, and Lambda for serverless.
- **Storage:** S3 (Object), EBS (Block/Disk), EFS (File/Shared), Glacier (Archive).
- **Networking:** VPC (Virtual Private Cloud) creates isolated networks, Security Groups (Stateful firewalls) vs NACLs (Stateless subnet firewalls), Route 53 (DNS).
- **Security & Identity:** IAM (Identity and Access Management) for permissions, IRSA (IAM Roles for Service Accounts) for EKS.
- **Monitoring & Auditing:** CloudWatch (Metrics/Logs), CloudTrail (API Audits), Config (Resource history), X-Ray (Tracing).

*Hindi translation & analogy:* *Cloud services bilkul ek rental toolkit ki tarah hain. Compute resources aapke workers hain, storage aapka godown hai, aur networking wo roads hain jo in sabko connect karte hain. Pehle hum apne server khud kharidte the (on-prem), ab AWS se rent par lete hain jab zaroorat ho. Agar website par traffic badhe, toh ASG apne aap aur EC2 instances (workers) le aayega.*

## Technical Deep Dive

### 1. Compute and Scaling (EC2, ASG, ELB, ECS, EKS)
Elastic Compute Cloud (EC2) provides resizable compute capacity. However, manual management is unscalable. We use Auto Scaling Groups (ASG) coupled with Elastic Load Balancers (ALB for HTTP/HTTPS, NLB for TCP/UDP) to ensure high availability. When a threshold (like CPU > 70%) is met, the ASG launches new instances, and the ELB distributes traffic to them.
For containerized workloads, Elastic Container Service (ECS) and Elastic Kubernetes Service (EKS) abstract away the underlying infrastructure management, especially when using AWS Fargate, a serverless compute engine for containers that removes the need to provision or manage servers.

### 2. Storage and Networking (VPC, S3, EBS, EFS)
Amazon VPC enables you to launch AWS resources into a virtual network. It involves subnets (public/private), Route Tables, and Internet Gateways (IGW) or NAT Gateways. Security is handled at the instance level by Security Groups (allow rules only, stateful) and at the subnet level by Network ACLs (allow/deny rules, stateless).
Storage options vary by use case: EBS provides high-performance block storage attached to a single EC2 instance, EFS offers a shared file system across multiple instances, and S3 is highly durable object storage for backups, static assets, or logs.

### 3. Monitoring, Security, and Governance (IAM, CloudWatch, CloudTrail)
Identity and Access Management (IAM) follows the principle of least privilege. In EKS, IRSA allows you to map IAM roles directly to Kubernetes service accounts, avoiding broad node-level permissions.
Monitoring relies on CloudWatch for system metrics (CPU, RAM) and logs. CloudTrail logs all AWS API calls, crucial for auditing "who did what". AWS Config tracks resource configuration changes over time, while AWS X-Ray helps developers analyze and debug distributed microservices.

## Step-by-Step Lab

**Scenario:** Provision a highly available web server setup using EC2, ALB, and ASG within a VPC.

1. **Create a VPC with Public and Private Subnets**
   ```bash
   aws ec2 create-vpc --cidr-block 10.0.0.0/16
   # Note the VpcId. Create subnets.
   aws ec2 create-subnet --vpc-id vpc-xxx --cidr-block 10.0.1.0/24 --availability-zone us-east-1a
   ```
2. **Create a Security Group for ALB and EC2**
   ```bash
   aws ec2 create-security-group --group-name alb-sg --description "ALB SG" --vpc-id vpc-xxx
   aws ec2 authorize-security-group-ingress --group-id sg-xxx --protocol tcp --port 80 --cidr 0.0.0.0/0
   ```
3. **Create an Application Load Balancer (ALB)**
   ```bash
   aws elbv2 create-load-balancer --name my-alb --subnets subnet-xxx subnet-yyy --security-groups sg-xxx
   ```
4. **Create a Launch Template with User Data**
   Create `userdata.txt`:
   ```bash
   #!/bin/bash
   yum update -y
   yum install httpd -y
   systemctl start httpd
   systemctl enable httpd
   echo "Hello from AWS" > /var/www/html/index.html
   ```
   ```bash
   aws ec2 create-launch-template --launch-template-name web-lt --version-description WebVersion1 \
   --launch-template-data '{"ImageId":"ami-0c55b159cbfafe1f0","InstanceType":"t2.micro","UserData":"<base64-encoded-userdata>"}'
   ```
5. **Create an Auto Scaling Group (ASG)**
   ```bash
   aws autoscaling create-auto-scaling-group --auto-scaling-group-name web-asg \
   --launch-template LaunchTemplateName=web-lt,Version='1' --min-size 2 --max-size 5 \
   --vpc-zone-identifier "subnet-xxx,subnet-yyy" --target-group-arns arn:aws:elasticloadbalancing:...
   ```
6. **Set Scaling Policy**
   ```bash
   aws autoscaling put-scaling-policy --auto-scaling-group-name web-asg \
   --policy-name cpu-tracking --policy-type TargetTrackingScaling \
   --target-tracking-configuration '{"PredefinedMetricSpecification":{"PredefinedMetricType":"ASGAverageCPUUtilization"},"TargetValue":50.0}'
   ```

*Expected Output:* Two EC2 instances will launch automatically, register with the ALB target group, and serve the "Hello from AWS" webpage via the ALB's DNS name.

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
| :--- | :--- | :--- |
| `aws s3 ls` | Lists all S3 buckets | `aws s3 ls s3://my-app-logs-bucket` |
| `aws ec2 describe-instances` | Shows running EC2 details | `aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"` |
| `aws iam get-user` | Gets current IAM user details | `aws iam get-user --user-name devops-admin` |
| `aws sts get-caller-identity` | Shows current authenticated AWS entity | `aws sts get-caller-identity` |
| `aws logs tail` | Live tails CloudWatch logs | `aws logs tail /aws/lambda/my-func --follow` |
| `aws ecs list-clusters` | Lists ECS clusters in region | `aws ecs list-clusters` |
| `aws eks update-kubeconfig` | Generates kubeconfig for EKS | `aws eks update-kubeconfig --region us-east-1 --name my-cluster` |
| `aws cloudformation deploy` | Deploys a CFN stack | `aws cloudformation deploy --template-file template.yaml --stack-name my-stack` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| **Connection timed out to EC2 SSH (Port 22)** | Security Group blocking port 22 or no IGW attached to VPC. | 1. Check EC2 SG inbound rules. Add SSH (22) from your IP. 2. Verify subnet has a route to Internet Gateway. |
| **S3 Access Denied (403)** | IAM Role missing permissions or Bucket Policy blocking access. | 1. Check IAM policy for `s3:GetObject` or `s3:PutObject`. 2. Verify Bucket Policy doesn't have an explicit Deny. |
| **ECS Tasks stuck in PENDING** | No EC2 instances registered to cluster or insufficient CPU/Memory in cluster. | 1. Check ECS Cluster instances tab. 2. Verify Task Definition resource requests fit within available instance capacity. |
| **ASG not scaling out under load** | CloudWatch metric not crossing threshold or ASG max size reached. | 1. Check ASG Activity History for errors. 2. Verify CloudWatch alarm state. 3. Increase MaxCapacity of ASG. |
| **Lambda Timeout Error** | Function execution exceeded configured timeout limit (default 3s). | 1. Open Lambda console. 2. Increase Timeout in General Configuration. 3. Optimize code execution time. |

## Real-World Job Scenario

**Scenario:** The marketing team is launching a new campaign, and traffic is expected to 10x for a few hours. The current static EC2 setup will crash under load.

**Junior DevOps Action:** Might suggest manually changing the EC2 instance type to a larger size (Vertical scaling) which requires downtime, or manually launching more instances and updating DNS.
**Senior DevOps Action:** Implements an Auto Scaling Group behind an Application Load Balancer. Configures a Target Tracking Scaling Policy based on ASGAverageCPUUtilization. Pre-warms the ALB by contacting AWS support if traffic spike is expected to be instantaneous and massive. Uses CloudFront (CDN) to cache static assets, drastically reducing the load on the backend servers.

## Interview Questions

**Q1: What is the difference between a Security Group and a Network ACL in AWS?**
A1: A Security Group operates at the instance/ENI level, is stateful (return traffic is automatically allowed), and only supports allow rules. A Network ACL operates at the subnet level, is stateless (return traffic must be explicitly allowed), and supports both allow and deny rules.

**Q2: How does an Application Load Balancer differ from a Network Load Balancer?**
A2: An ALB operates at Layer 7 (HTTP/HTTPS), supports path-based and host-based routing, and is ideal for microservices. An NLB operates at Layer 4 (TCP/UDP), can handle millions of requests per second with ultra-low latency, and provides a static IP per Availability Zone.

**Q3: Explain the difference between EBS, EFS, and S3.**
A3: EBS (Elastic Block Store) is block storage attached to a single EC2 instance (like a local hard drive). EFS (Elastic File System) is a managed NFS file system that can be mounted to multiple EC2 instances concurrently. S3 (Simple Storage Service) is an object storage service accessed via HTTP API, ideal for backups, static files, and media.

**Q4: How do you securely grant an EC2 instance access to read an S3 bucket?**
A4: Create an IAM Role with a policy granting `s3:GetObject` and `s3:ListBucket` permissions. Attach this IAM Role to the EC2 instance as an Instance Profile. Avoid putting long-term IAM Access Keys directly on the instance.

**Q5: What is IAM Roles for Service Accounts (IRSA) in EKS?**
A5: IRSA allows you to associate an IAM role with a Kubernetes Service Account. This provides fine-grained, pod-level IAM permissions instead of assigning broad permissions to the underlying EC2 worker nodes, adhering to the principle of least privilege.

## Related Notes
- [[Master Index]]
- [[07-Cloud/AWS-02 AWS DevOps Tools]]
- [[04-Orchestration/K8S-01 Kubernetes Architecture]]
